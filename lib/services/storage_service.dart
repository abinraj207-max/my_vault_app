import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:cryptography/cryptography.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'encryption_service.dart';

class StorageService {
  final EncryptionService _encryptionService;
  static const String _vaultPathKey = 'my_vault_path';
  static const String _magicBytes = 'MYVAULT1';

  StorageService(this._encryptionService);

  /// Get the current configured vault directory.
  /// If none is saved, attempts to use the default shared path.
  Future<String> getVaultDirectory() async {
    final prefs = await SharedPreferences.getInstance();
    final savedPath = prefs.getString(_vaultPathKey);
    if (savedPath != null && savedPath.isNotEmpty) {
      return savedPath;
    }
    
    // Default shared path
    final defaultPath = await getDefaultVaultPath();
    return defaultPath;
  }

  /// Saves a custom vault path.
  Future<void> setVaultDirectory(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_vaultPathKey, path);
  }

  /// Standard default path: /storage/emulated/0/MyVault on Android, app docs on iOS.
  Future<String> getDefaultVaultPath() async {
    if (Platform.isAndroid) {
      return '/storage/emulated/0/MyVault';
    } else {
      final docDir = await getApplicationDocumentsDirectory();
      return '${docDir.path}/MyVault';
    }
  }

  /// Request permissions needed to write to the default shared directory.
  Future<bool> requestStoragePermissions() async {
    if (Platform.isAndroid) {
      // 1. Try to request manageExternalStorage (Android 11+)
      if (await Permission.manageExternalStorage.request().isGranted) {
        return true;
      }
      // 2. Fallback to standard storage permission (Android 10 and below)
      if (await Permission.storage.request().isGranted) {
        return true;
      }
      return false;
    }
    return true; // iOS does not require permissions for its app documents
  }

  /// Checks if storage permissions are currently granted.
  Future<bool> hasStoragePermissions() async {
    if (Platform.isAndroid) {
      return (await Permission.manageExternalStorage.isGranted) ||
             (await Permission.storage.isGranted);
    }
    return true;
  }

  /// Checks if the vault.enc file exists in the current vault directory.
  Future<bool> vaultExists() async {
    final vaultDir = await getVaultDirectory();
    final vaultFile = File('$vaultDir/vault.enc');
    return vaultFile.existsSync();
  }

  /// Initializes a new vault in the current directory with the master password.
  /// Creates the 'media' and 'documents' subfolders.
  Future<void> createNewVault(String password) async {
    final vaultDir = await getVaultDirectory();
    
    // Create folders
    await Directory('$vaultDir/media').create(recursive: true);
    await Directory('$vaultDir/documents').create(recursive: true);

    // Initial empty index structure
    final initialIndex = {
      'version': 1,
      'createdAt': DateTime.now().toIso8601String(),
      'updatedAt': DateTime.now().toIso8601String(),
      'items': [],
    };

    final indexJson = jsonEncode(initialIndex);

    // Generate random salt and derive key
    final salt = _encryptionService.generateRandomSalt(16);
    final key = await _encryptionService.deriveKey(password, salt);

    // Encrypt initial index
    final secretBox = await _encryptionService.encryptBytes(utf8.encode(indexJson), key);

    // Construct self-contained vault file layout:
    // [Magic Bytes (8 bytes)] [Salt (16 bytes)] [Nonce (12 bytes)] [MAC Tag (16 bytes)] [Ciphertext (N bytes)]
    final builder = BytesBuilder();
    builder.add(utf8.encode(_magicBytes));
    builder.add(salt); // 16 bytes
    builder.add(secretBox.nonce); // 12 bytes
    builder.add(secretBox.mac.bytes); // 16 bytes
    builder.add(secretBox.cipherText);

    final vaultFile = File('$vaultDir/vault.enc');
    await vaultFile.writeAsBytes(builder.toBytes(), flush: true);
  }

  /// Reads and decrypts the index database from vault.enc using the derived key.
  /// First extracts salt to derive key, then decrypts the ciphertext.
  Future<String> readVaultIndex(String password) async {
    final vaultDir = await getVaultDirectory();
    final vaultFile = File('$vaultDir/vault.enc');
    if (!vaultFile.existsSync()) {
      throw FileSystemException('Vault file does not exist');
    }

    final bytes = await vaultFile.readAsBytes();
    if (bytes.length < 8 + 16 + 12 + 16) {
      throw const FormatException('Vault file is corrupted or incomplete');
    }

    // 1. Verify Magic Bytes
    final magic = utf8.decode(bytes.sublist(0, 8));
    if (magic != _magicBytes) {
      throw const FormatException('Invalid vault file header: Magic bytes mismatch');
    }

    // 2. Extract Cryptographic Material
    final salt = bytes.sublist(8, 24);
    final nonce = bytes.sublist(24, 36);
    final mac = bytes.sublist(36, 52);
    final ciphertext = bytes.sublist(52);

    // 3. Derive Key from Password using extracted Salt
    final key = await _encryptionService.deriveKey(password, salt);

    // 4. Decrypt
    final box = SecretBox(ciphertext, nonce: nonce, mac: Mac(mac));
    final decryptedBytes = await _encryptionService.decryptBytes(box, key);

    return utf8.decode(decryptedBytes);
  }

  /// Encrypts and writes the updated index JSON back to vault.enc.
  Future<void> writeVaultIndex(String indexJson, String password) async {
    final vaultDir = await getVaultDirectory();
    final vaultFile = File('$vaultDir/vault.enc');

    // To preserve the same salt (so we don't have to re-derive key for media files),
    // we read the existing salt from the file. If file doesn't exist, we generate a new salt.
    List<int> salt;
    if (vaultFile.existsSync()) {
      final existingBytes = await vaultFile.readAsBytes();
      if (existingBytes.length >= 24) {
        salt = existingBytes.sublist(8, 24);
      } else {
        salt = _encryptionService.generateRandomSalt(16);
      }
    } else {
      salt = _encryptionService.generateRandomSalt(16);
    }

    final key = await _encryptionService.deriveKey(password, salt);
    final secretBox = await _encryptionService.encryptBytes(utf8.encode(indexJson), key);

    final builder = BytesBuilder();
    builder.add(utf8.encode(_magicBytes));
    builder.add(salt);
    builder.add(secretBox.nonce);
    builder.add(secretBox.mac.bytes);
    builder.add(secretBox.cipherText);

    await vaultFile.writeAsBytes(builder.toBytes(), flush: true);
  }

  /// Encrypts and saves an external file into MyVault directory (media/ or documents/).
  /// Prepend [12 bytes Nonce] [16 bytes MAC] to [Ciphertext] in the output file.
  Future<String> encryptAndSaveFile(
    File sourceFile,
    String subfolder, // 'media' or 'documents'
    String targetFileName, // e.g. "uuid.enc"
    SecretKey key,
  ) async {
    final vaultDir = await getVaultDirectory();
    final targetDir = Directory('$vaultDir/$subfolder');
    if (!targetDir.existsSync()) {
      await targetDir.create(recursive: true);
    }

    final targetFile = File('${targetDir.path}/$targetFileName');
    final fileBytes = await sourceFile.readAsBytes();

    final box = await _encryptionService.encryptBytes(fileBytes, key);

    final builder = BytesBuilder();
    builder.add(box.nonce); // 12 bytes
    builder.add(box.mac.bytes); // 16 bytes
    builder.add(box.cipherText);

    await targetFile.writeAsBytes(builder.toBytes(), flush: true);
    return '$subfolder/$targetFileName';
  }

  /// Decrypts a vault file directly into memory (bytes).
  Future<Uint8List> decryptFileToMemory(String vaultRelativePath, SecretKey key) async {
    final vaultDir = await getVaultDirectory();
    final file = File('$vaultDir/$vaultRelativePath');
    if (!file.existsSync()) {
      throw FileSystemException('Encrypted file not found: $vaultRelativePath');
    }

    final bytes = await file.readAsBytes();
    if (bytes.length < 12 + 16) {
      throw const FormatException('Encrypted file is corrupted');
    }

    final nonce = bytes.sublist(0, 12);
    final mac = bytes.sublist(12, 28);
    final ciphertext = bytes.sublist(28);

    final box = SecretBox(ciphertext, nonce: nonce, mac: Mac(mac));
    final decryptedBytes = await _encryptionService.decryptBytes(box, key);

    return Uint8List.fromList(decryptedBytes);
  }

  /// Temporarily decrypts a file to the secure cache directory so it can be opened in external apps.
  /// Callers must call securelyDeleteFile when closed.
  Future<File> decryptFileToCache(String vaultRelativePath, String originalName, SecretKey key) async {
    final cacheDir = await getTemporaryDirectory();
    final tempFile = File('${cacheDir.path}/$originalName');
    
    final decryptedBytes = await decryptFileToMemory(vaultRelativePath, key);
    await tempFile.writeAsBytes(decryptedBytes, flush: true);

    return tempFile;
  }

  /// Securely shreds and deletes a temporary decrypted file.
  Future<void> securelyDeleteFile(File file) async {
    if (await file.exists()) {
      try {
        final length = await file.length();
        if (length > 0) {
          // Overwrite file contents with zeros to scrub plain text from flash memory
          await file.writeAsBytes(Uint8List(length), flush: true);
        }
      } catch (_) {
        // Fallback to direct deletion if writing fails
      }
      await file.delete();
    }
  }

  /// Deletes an encrypted file from the vault.
  Future<void> deleteVaultFile(String vaultRelativePath) async {
    final vaultDir = await getVaultDirectory();
    final file = File('$vaultDir/$vaultRelativePath');
    if (file.existsSync()) {
      await file.delete();
    }
  }

  /// Exports the entire vault directory into a single encrypted ZIP archive backup file.
  Future<void> exportBackup(String exportPath) async {
    final vaultDir = await getVaultDirectory();
    
    // We create the archive in memory, then write it to the file.
    final archive = Archive();

    final dir = Directory(vaultDir);
    if (!dir.existsSync()) {
      throw FileSystemException('Vault directory not found: $vaultDir');
    }

    final files = dir.listSync(recursive: true);
    for (final entity in files) {
      if (entity is File) {
        final relativePath = entity.path.substring(dir.path.length + 1).replaceAll('\\', '/');
        final bytes = await entity.readAsBytes();
        archive.addFile(ArchiveFile(relativePath, bytes.length, bytes));
      }
    }

    final zipData = ZipEncoder().encode(archive);
    if (zipData == null) {
      throw const FormatException('Failed to create zip archive');
    }

    final backupFile = File(exportPath);
    await backupFile.writeAsBytes(zipData, flush: true);
  }

  /// Restores the vault from an exported backup ZIP archive.
  /// Overwrites current directory structure but checks if backup contains vault.enc first.
  Future<void> importBackup(String backupPath) async {
    final vaultDir = await getVaultDirectory();
    final bytes = await File(backupPath).readAsBytes();

    final archive = ZipDecoder().decodeBytes(bytes);
    
    // 1. Validation: Verify backup ZIP contains vault.enc
    final hasVaultFile = archive.any((file) => file.name == 'vault.enc');
    if (!hasVaultFile) {
      throw const FormatException('Invalid backup file: vault.enc is missing');
    }

    // 2. Extract all files to vault directory
    for (final file in archive) {
      if (file.isFile) {
        final relativePath = file.name;
        final data = file.content as List<int>;
        
        final targetFile = File('$vaultDir/$relativePath');
        await targetFile.parent.create(recursive: true);
        await targetFile.writeAsBytes(data, flush: true);
      }
    }
  }

  /// Calculates storage usage of MyVault folder in bytes.
  Future<Map<String, dynamic>> getStorageUsage() async {
    final vaultDir = await getVaultDirectory();
    final dir = Directory(vaultDir);
    if (!dir.existsSync()) {
      return {'total': 0, 'media': 0, 'documents': 0, 'database': 0};
    }

    int total = 0;
    int media = 0;
    int documents = 0;
    int database = 0;

    final files = dir.listSync(recursive: true);
    for (final entity in files) {
      if (entity is File) {
        final length = entity.lengthSync();
        total += length;
        final relativePath = entity.path.substring(dir.path.length + 1).replaceAll('\\', '/');
        if (relativePath == 'vault.enc') {
          database += length;
        } else if (relativePath.startsWith('media/')) {
          media += length;
        } else if (relativePath.startsWith('documents/')) {
          documents += length;
        }
      }
    }

    return {
      'total': total,
      'media': media,
      'documents': documents,
      'database': database,
    };
  }

  /// Completely deletes the entire vault from device disk.
  Future<void> deleteEntireVault() async {
    final vaultDir = await getVaultDirectory();
    final dir = Directory(vaultDir);
    if (dir.existsSync()) {
      await dir.delete(recursive: true);
    }
  }
}
