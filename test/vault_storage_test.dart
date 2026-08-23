import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:cryptography/cryptography.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:my_vault/services/encryption_service.dart';
import 'package:my_vault/services/storage_service.dart';
import 'package:my_vault/models/vault_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Storage and Vault Database Tests', () {
    late Directory tempDir;
    late EncryptionService encryptionService;
    late StorageService storageService;
    const password = 'TestVaultPassword123!';

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      // Create a temporary sandbox directory for vault tests
      tempDir = await Directory.systemTemp.createTemp('myvault_test_');
      encryptionService = EncryptionService();
      storageService = StorageService(encryptionService);
      
      // Override default directory to the test sandbox
      await storageService.setVaultDirectory(tempDir.path);
    });

    tearDown(() async {
      // Cleanup the temporary sandbox directory
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('Vault initialization creates folders and initial index structure', () async {
      final existsBefore = await storageService.vaultExists();
      expect(existsBefore, false);

      // Initialize
      await storageService.createNewVault(password);
      
      final existsAfter = await storageService.vaultExists();
      expect(existsAfter, true);

      // Verify directory structure
      expect(Directory('${tempDir.path}/media').existsSync(), true);
      expect(Directory('${tempDir.path}/documents').existsSync(), true);

      // Read initial index
      final indexJson = await storageService.readVaultIndex(password);
      final indexData = jsonDecode(indexJson) as Map<String, dynamic>;

      expect(indexData['version'], 1);
      expect(indexData['items'], isEmpty);
    });

    test('Read/Write item serialization round-trip in vault.enc', () async {
      await storageService.createNewVault(password);

      // Create dummy item
      final mockItem = VaultItem(
        id: 'uuid-12345',
        type: VaultType.password,
        title: 'Work Email Login',
        tags: ['work', 'email'],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        username: 'dev_user',
        email: 'dev@company.com',
        password: 'SuperSecretPassword1',
        website: 'https://mail.company.com',
        notes: 'Secret note about mail server',
      );

      final indexData = {
        'version': 1,
        'createdAt': DateTime.now().toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
        'items': [mockItem.toJson()],
      };

      // Write index
      await storageService.writeVaultIndex(jsonEncode(indexData), password);

      // Read back and deserialize
      final indexJson = await storageService.readVaultIndex(password);
      final decodedData = jsonDecode(indexJson) as Map<String, dynamic>;
      final itemsList = decodedData['items'] as List<dynamic>;

      expect(itemsList.length, 1);
      final parsedItem = VaultItem.fromJson(itemsList.first as Map<String, dynamic>);

      expect(parsedItem.id, mockItem.id);
      expect(parsedItem.title, mockItem.title);
      expect(parsedItem.username, mockItem.username);
      expect(parsedItem.password, mockItem.password);
      expect(parsedItem.tags, mockItem.tags);
    });

    test('Vault File Encryption (Media/Documents) Layout Verification', () async {
      await storageService.createNewVault(password);

      // Derive key for testing file encryption
      final vaultFile = File('${tempDir.path}/vault.enc');
      final bytes = await vaultFile.readAsBytes();
      final salt = bytes.sublist(8, 24);
      final key = await encryptionService.deriveKey(password, salt);

      // Create a dummy source file
      final sourceFile = File('${tempDir.path}/test_source.png');
      const testContent = 'Simulated PNG image bytes here';
      await sourceFile.writeAsString(testContent);

      // Encrypt and save to vault
      const targetName = 'secure_image.png.enc';
      final relativePath = await storageService.encryptAndSaveFile(
        sourceFile,
        'media',
        targetName,
        key,
      );

      expect(relativePath, 'media/$targetName');
      
      final encryptedFile = File('${tempDir.path}/$relativePath');
      expect(encryptedFile.existsSync(), true);

      // Read raw bytes on disk and verify header size (Nonce = 12, MAC = 16)
      final diskBytes = await encryptedFile.readAsBytes();
      expect(diskBytes.length >= 12 + 16, true);

      // Decrypt to memory
      final decryptedBytes = await storageService.decryptFileToMemory(relativePath, key);
      final decryptedContent = utf8.decode(decryptedBytes);

      expect(decryptedContent, testContent);
    });
  });
}
