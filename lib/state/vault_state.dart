import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cryptography/cryptography.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/vault_models.dart';
import '../services/encryption_service.dart';
import '../services/storage_service.dart';
import '../services/biometric_service.dart';
import '../services/supabase_service.dart';
import '../models/role_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path_provider/path_provider.dart';

enum VaultStatus { unauthenticated, uninitialized, locked, unlocked, corrupted }

class VaultState extends ChangeNotifier {
  final StorageService _storageService;
  final EncryptionService _encryptionService;
  final BiometricService _biometricService;
  final SupabaseService supabaseService;

  VaultStatus _status = VaultStatus.unauthenticated;
  VaultStatus get status => _status;

  String? _masterPassword;
  SecretKey? _secretKey;

  SecretKey? get secretKey => _secretKey;
  String? get masterPassword => _masterPassword;

  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;

  String? _lastSyncTime;
  String? get lastSyncTime => _lastSyncTime;

  List<String> _deletedItems = [];
  List<String> get deletedItems => _deletedItems;

  List<VaultItem> _items = [];
  List<VaultItem> get items => _items;

  Role? _currentRole;
  Role? get currentRole => _currentRole;
  bool get isTeamMember => _currentRole != null;

  String _vaultPath = '';
  String get vaultPath => _vaultPath;

  // Settings
  ThemeMode _themeMode = ThemeMode.system;
  ThemeMode get themeMode => _themeMode;

  int _autoLockTimeout =
      60; // In seconds (default: 1 min). 0 = Immediate, -1 = Never
  int get autoLockTimeout => _autoLockTimeout;

  bool _biometricEnabled = false;
  bool get biometricEnabled => _biometricEnabled;

  // Track background state for auto-lock
  DateTime? _backgroundTime;

  bool _authListenerSubscribed = false;

  /// Set to true to temporarily suppress auth state changes
  /// (e.g., during team member account creation).
  bool suppressAuthChanges = false;

  VaultState(
    this._storageService,
    this._encryptionService,
    this._biometricService,
    this.supabaseService,
  ) {
    _init();
  }

  /// Initialize state: load settings, check if vault exists, etc.
  Future<void> _init() async {
    await loadSettings();

    if (supabaseService.isInitialized) {
      _listenToAuthChanges();
    }

    await checkVaultStatus();

    // Load last sync time
    final prefs = await SharedPreferences.getInstance();
    _lastSyncTime = prefs.getString('last_sync_time');
  }

  void _listenToAuthChanges() {
    if (_authListenerSubscribed) return;
    try {
      supabaseService.client.auth.onAuthStateChange.listen((data) {
        _handleAuthStateChange(data.event, data.session);
      });
      _authListenerSubscribed = true;
    } catch (_) {}
  }

  Future<void> _handleAuthStateChange(
    AuthChangeEvent event,
    Session? session,
  ) async {
    // Skip processing if suppressed (e.g., during team member creation)
    if (suppressAuthChanges) return;

    if (session == null || event == AuthChangeEvent.signedOut) {
      _masterPassword = null;
      _secretKey = null;
      _items.clear();
      _status = VaultStatus.unauthenticated;
      notifyListeners();
    } else {
      if (_status == VaultStatus.unauthenticated) {
        await checkVaultStatus();
      }
    }
  }

  /// Checks online metadata status to determine if vault is set up.
  Future<void> checkVaultStatus() async {
    // Setup listener if Supabase gets initialized later
    if (supabaseService.isInitialized) {
      _listenToAuthChanges();
    }

    if (!supabaseService.isInitialized || !supabaseService.isLoggedIn) {
      _status = VaultStatus.unauthenticated;
      notifyListeners();
      return;
    }

    if (_secretKey == null) {
      _status = VaultStatus.locked;
    } else {
      _status = VaultStatus.unlocked;
    }
    notifyListeners();
  }

  /// Load theme, lock timeout, and biometric preferences from SharedPreferences.
  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    // 1. Theme
    final themeName = prefs.getString('theme_mode') ?? 'system';
    _themeMode = ThemeMode.values.firstWhere(
      (e) => e.name == themeName,
      orElse: () => ThemeMode.system,
    );

    // 2. Auto-lock timeout
    _autoLockTimeout = prefs.getInt('auto_lock_timeout') ?? 60;

    // 3. Biometrics
    _biometricEnabled = await _biometricService.isBiometricUnlockEnabled();

    notifyListeners();
  }

  /// Update theme mode setting
  Future<void> updateThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme_mode', mode.name);
    notifyListeners();
  }

  /// Update auto-lock timeout duration
  Future<void> updateAutoLockTimeout(int timeoutSeconds) async {
    _autoLockTimeout = timeoutSeconds;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('auto_lock_timeout', timeoutSeconds);
    notifyListeners();
  }

  /// Toggle biometric unlock capability
  Future<bool> toggleBiometricUnlock(bool enable, String passwordVerify) async {
    if (enable) {
      try {
        // Verify password first
        await _storageService.readVaultIndex(passwordVerify);

        // Save Master Password securely in hardware Keystore
        await _biometricService.saveMasterPassword(passwordVerify);
        await _biometricService.setBiometricUnlockEnabled(true);
        _biometricEnabled = true;
        notifyListeners();
        return true;
      } catch (_) {
        return false; // Wrong password
      }
    } else {
      await _biometricService.setBiometricUnlockEnabled(false);
      _biometricEnabled = false;
      notifyListeners();
      return true;
    }
  }

  /// Unlocks the vault online using the entered master password and salt.
  Future<void> unlockVault(String password) async {
    try {
      if (!supabaseService.isLoggedIn) {
        throw StateError('User must be logged in to unlock vault.');
      }

      final metadata = supabaseService.currentUser?.userMetadata;
      final cloudSaltBase64 = metadata?['vault_salt'] as String?;
      final cloudVerificationJson = metadata?['vault_verification'] as String?;

      if (cloudSaltBase64 == null || cloudSaltBase64.isEmpty) {
        throw StateError('Vault is not set up on this cloud account.');
      }

      final salt = base64.decode(cloudSaltBase64);
      final derivedKey = await _encryptionService.deriveKey(password, salt);

      // Verify the password using the verification token (if it exists)
      if (cloudVerificationJson != null && cloudVerificationJson.isNotEmpty) {
        try {
          final decodedVer =
              jsonDecode(cloudVerificationJson) as Map<String, dynamic>;
          final decrypted = await _encryptionService.decryptText(
            decodedVer['ciphertext'] as String,
            decodedVer['nonce'] as String,
            decodedVer['mac'] as String,
            derivedKey,
          );
          if (decrypted != 'vault_verified') {
            throw const FormatException('Invalid master password.');
          }
        } catch (_) {
          throw const FormatException('Invalid master password.');
        }
      } else {
        // Fallback for legacy setups: verify using items, then generate the verification token
        final remoteRecords = await supabaseService.fetchItems();
        if (remoteRecords.isNotEmpty) {
          bool verified = false;
          for (final record in remoteRecords) {
            try {
              final remoteEncryptedData = record['encrypted_data'] as String;
              final decodedEnc =
                  jsonDecode(remoteEncryptedData) as Map<String, dynamic>;
              await _encryptionService.decryptText(
                decodedEnc['ciphertext'] as String,
                decodedEnc['nonce'] as String,
                decodedEnc['mac'] as String,
                derivedKey,
              );
              verified = true;
              break;
            } catch (_) {}
          }
          if (!verified) {
            throw const FormatException('Invalid master password.');
          }
        }

        // Auto-generate the verification token so it is saved for next time
        try {
          final verificationMap = await _encryptionService.encryptText(
            'vault_verified',
            derivedKey,
          );
          await supabaseService.client.auth.updateUser(
            UserAttributes(
              data: {'vault_verification': jsonEncode(verificationMap)},
            ),
          );
        } catch (_) {}
      }

      // Check if the user is a team member
      final teamMembership = await supabaseService.getMyTeamMembership();
      List<Map<String, dynamic>> remoteRecords = [];
      SecretKey keyToUse = derivedKey;

      if (teamMembership != null) {
        // User is a team member!
        final roleData = teamMembership['roles'] as Map<String, dynamic>?;
        if (roleData != null) {
          _currentRole = Role.fromJson(roleData);
        }

        final ownerId = teamMembership['owner_id'] as String;
        print('Is team member! ownerId: $ownerId');

        final encryptedOwnerKeyStr =
            teamMembership['encrypted_owner_key'] as String?;

        if (encryptedOwnerKeyStr != null) {
          try {
            // Decrypt the owner's key using the member's derived key
            final encryptedMap =
                jsonDecode(encryptedOwnerKeyStr) as Map<String, dynamic>;
            final decryptedOwnerKeyBase64 = await _encryptionService
                .decryptText(
                  encryptedMap['ciphertext'] as String,
                  encryptedMap['nonce'] as String,
                  encryptedMap['mac'] as String,
                  derivedKey,
                );

            final ownerKeyBytes = base64.decode(decryptedOwnerKeyBase64);
            keyToUse = SecretKey(ownerKeyBytes);
          } catch (_) {
            throw const FormatException('Failed to decrypt owner vault key.');
          }
        } else {
          print('WARNING: encryptedOwnerKeyStr is NULL!');
        }

        remoteRecords = await supabaseService.fetchOwnerItems(ownerId);
        print('Fetched ${remoteRecords.length} items for owner $ownerId');
      } else {
        print('User is owner, fetching their own items');
        _currentRole = null;
        remoteRecords = await supabaseService.fetchItems();
        print('Fetched ${remoteRecords.length} items');
      }

      List<VaultItem> remoteItems = [];
      for (final record in remoteRecords) {
        try {
          final remoteEncryptedData = record['encrypted_data'] as String;
          final decodedEnc =
              jsonDecode(remoteEncryptedData) as Map<String, dynamic>;
          final decryptedJson = await _encryptionService.decryptText(
            decodedEnc['ciphertext'] as String,
            decodedEnc['nonce'] as String,
            decodedEnc['mac'] as String,
            keyToUse,
          );
          remoteItems.add(
            VaultItem.fromJson(
              jsonDecode(decryptedJson) as Map<String, dynamic>,
            ),
          );
        } catch (e, stackTrace) {
          print('Failed to decrypt item ${record['id']}: $e');
          print('Stack trace: $stackTrace');
          print('Using keyToUse = $keyToUse');
          // Skip corrupted items
        }
      }

      print(
        'Successfully decrypted ${remoteItems.length} items from ${remoteRecords.length} remote records.',
      );

      // Filter items based on role permissions
      if (_currentRole != null) {
        remoteItems = remoteItems.where((item) {
          switch (item.type) {
            case VaultType.password:
              return _currentRole!.canViewPasswords;
            case VaultType.apiKey:
              return _currentRole!.canViewApiKeys;
            case VaultType.email:
              return _currentRole!.canViewEmails;
            case VaultType.note:
              return _currentRole!.canViewNotes;
            case VaultType.image:
              return _currentRole!.canViewImages;
            case VaultType.card:
              return _currentRole!.canViewCards;
            case VaultType.document:
              return _currentRole!.canViewDocuments;
            default:
              return false;
          }
        }).toList();
      }

      _secretKey = derivedKey;
      _masterPassword = password;
      _items = remoteItems;
      _deletedItems = [];
      _status = VaultStatus.unlocked;
      notifyListeners();
    } catch (e) {
      if (e is FormatException) {
        throw const FormatException('Invalid master password.');
      } else {
        rethrow;
      }
    }
  }

  /// Attempts to unlock the vault using biometric credentials.
  Future<bool> unlockWithBiometrics() async {
    if (!_biometricEnabled) return false;

    final available = await _biometricService.isBiometricsAvailable();
    if (!available) return false;

    final authenticated = await _biometricService.authenticate();
    if (!authenticated) return false;

    final savedPassword = await _biometricService.getMasterPassword();
    if (savedPassword == null) return false;

    try {
      await unlockVault(savedPassword);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Creates a new vault database online.
  Future<void> createNewVault(String password) async {
    _masterPassword = password;

    // Generate new salt and derive key
    final salt = _encryptionService.generateRandomSalt(16);
    _secretKey = await _encryptionService.deriveKey(password, salt);

    // Encrypt verification token
    final verificationMap = await _encryptionService.encryptText(
      'vault_verified',
      _secretKey!,
    );
    final verificationJson = jsonEncode(verificationMap);

    // Save salt and verification to Supabase metadata if logged in
    if (supabaseService.isLoggedIn) {
      try {
        await supabaseService.client.auth.updateUser(
          UserAttributes(
            data: {
              'vault_salt': base64.encode(salt),
              'vault_verification': verificationJson,
            },
          ),
        );
      } catch (_) {}
    }

    _items = [];
    _status = VaultStatus.unlocked;
    notifyListeners();
  }

  /// Changes the vault master password online. Re-encrypts user items.
  Future<void> changeMasterPassword(String newPassword) async {
    if (_status != VaultStatus.unlocked ||
        _masterPassword == null ||
        _secretKey == null) {
      throw const OSError('Vault must be unlocked to change password');
    }

    final metadata = supabaseService.currentUser?.userMetadata;
    final saltBase64 = metadata?['vault_salt'] as String?;
    if (saltBase64 == null) {
      throw StateError('Cannot find salt metadata to change password.');
    }

    final salt = base64.decode(saltBase64);
    final newKey = await _encryptionService.deriveKey(newPassword, salt);

    // Generate new verification token
    final verificationMap = await _encryptionService.encryptText(
      'vault_verified',
      newKey,
    );
    final verificationJson = jsonEncode(verificationMap);

    // Save verification to Supabase metadata
    if (supabaseService.isLoggedIn) {
      await supabaseService.client.auth.updateUser(
        UserAttributes(data: {'vault_verification': verificationJson}),
      );

      // Re-encrypt existing items with the new key and upload
      for (final item in _items) {
        final itemJson = jsonEncode(item.toJson());
        final encryptedMap = await _encryptionService.encryptText(
          itemJson,
          newKey,
        );
        final encryptedData = jsonEncode(encryptedMap);
        await supabaseService.upsertItem(
          item.id,
          encryptedData,
          item.updatedAt.toIso8601String(),
        );
      }
    }

    // Update in-memory keys
    _masterPassword = newPassword;
    _secretKey = newKey;

    // Update biometric storage if enabled
    if (_biometricEnabled) {
      await _biometricService.saveMasterPassword(newPassword);
    }

    notifyListeners();
  }

  /// Locks the vault and wipes sensitive credentials from memory.
  void lockVault() {
    _masterPassword = null;
    _secretKey = null;
    _items.clear();
    _status = VaultStatus.locked;
    _backgroundTime = null;
    notifyListeners();
  }

  /// Handles App Lifecycle changes to implement the auto-lock feature.
  void handleLifecycleStateChanged(AppLifecycleState state) {
    if (_status != VaultStatus.unlocked) return;

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      // Record time when app goes to background
      _backgroundTime = DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      if (_backgroundTime != null && _autoLockTimeout != -1) {
        final elapsedSeconds = DateTime.now()
            .difference(_backgroundTime!)
            .inSeconds;
        if (_autoLockTimeout == 0 || elapsedSeconds >= _autoLockTimeout) {
          // Time expired, auto-lock!
          lockVault();
        }
      }
      _backgroundTime = null;

      // Auto-sync on app resume if we are unlocked and logged in
      if (_status == VaultStatus.unlocked && supabaseService.isLoggedIn) {
        syncWithCloud().catchError((_) {});
      }
    }
  }

  /// Writes current list of items. (No-op in online-only architecture)
  Future<void> _saveIndex() async {}

  /// Add a new item directly to Supabase and update local state.
  Future<void> addItem(VaultItem item) async {
    _items.add(item);
    notifyListeners();

    if (supabaseService.isLoggedIn) {
      try {
        await _uploadItemToSupabase(item);
      } catch (e) {
        debugPrint('Error uploading item to Supabase: $e');
      }
    }
  }

  /// Update an existing item directly on Supabase and local state.
  Future<void> updateItem(VaultItem updatedItem) async {
    final index = _items.indexWhere((e) => e.id == updatedItem.id);
    if (index != -1) {
      _items[index] = updatedItem;
      notifyListeners();

      if (supabaseService.isLoggedIn) {
        try {
          await _uploadItemToSupabase(updatedItem);
        } catch (e) {
          debugPrint('Error updating item on Supabase: $e');
        }
      }
    }
  }

  /// Deletes an item directly from Supabase and local state.
  Future<void> deleteItem(VaultItem item) async {
    _items.removeWhere((e) => e.id == item.id);
    notifyListeners();

    if (supabaseService.isLoggedIn) {
      try {
        await supabaseService.deleteItem(item.id);
        if (item.fileVaultPath != null) {
          await supabaseService.deleteFile(item.fileVaultPath!);
        }
      } catch (e) {
        debugPrint('Error deleting item from Supabase: $e');
      }
    }
  }

  /// Change the vault path (e.g. custom directory selected by user).
  Future<void> changeVaultLocation(String path) async {
    await _storageService.setVaultDirectory(path);
    await checkVaultStatus();
  }

  /// Reset vault directory to default location.
  Future<void> resetVaultLocationToDefault() async {
    final defaultPath = await _storageService.getDefaultVaultPath();
    await changeVaultLocation(defaultPath);
  }

  /// Encrypt and save a selected file directly to Supabase storage in memory.
  Future<String> addFileToVault(
    File file,
    VaultType type,
    String originalName,
  ) async {
    if (_secretKey == null) {
      throw const OSError('Vault is locked. Cannot add files.');
    }

    final uuid = UniqueKey()
        .toString()
        .replaceAll('#', '')
        .replaceAll('[', '')
        .replaceAll(']', '')
        .trim();
    final fileExt = originalName.contains('.')
        ? originalName.split('.').last
        : '';
    final targetName =
        'file_${uuid}_${DateTime.now().millisecondsSinceEpoch}.$fileExt.enc';

    final bytes = await file.readAsBytes();
    final box = await _encryptionService.encryptBytes(bytes, _secretKey!);

    // Package: [12 bytes Nonce] [16 bytes MAC] [Ciphertext]
    final builder = BytesBuilder();
    builder.add(box.nonce);
    builder.add(box.mac.bytes);
    builder.add(box.cipherText);
    final encryptedBytes = builder.toBytes();

    if (supabaseService.isLoggedIn) {
      await supabaseService.uploadFile(targetName, encryptedBytes);
    }

    return targetName;
  }

  /// Decrypt a vault file from Supabase directly to memory.
  Future<Uint8List> decryptFile(String relativePath) async {
    if (_secretKey == null) {
      throw const OSError('Vault is locked. Cannot decrypt files.');
    }
    final encryptedBytes = await supabaseService.downloadFile(relativePath);
    if (encryptedBytes.length < 28) {
      throw const FormatException('Encrypted file package is too short');
    }
    final nonce = encryptedBytes.sublist(0, 12);
    final mac = encryptedBytes.sublist(12, 28);
    final ciphertext = encryptedBytes.sublist(28);

    final box = SecretBox(ciphertext, nonce: nonce, mac: Mac(mac));
    final decryptedBytes = await _encryptionService.decryptBytes(
      box,
      _secretKey!,
    );
    return Uint8List.fromList(decryptedBytes);
  }

  /// Temporarily decrypt a document to native cache for viewing.
  Future<File> decryptFileToCache(
    String relativePath,
    String originalName,
  ) async {
    if (_secretKey == null) {
      throw const OSError('Vault is locked.');
    }
    final cacheDir = await getTemporaryDirectory();
    final tempFile = File('${cacheDir.path}/$originalName');

    final decryptedBytes = await decryptFile(relativePath);
    await tempFile.writeAsBytes(decryptedBytes, flush: true);
    return tempFile;
  }

  /// Securely delete a cached file.
  Future<void> clearCachedFile(File file) async {
    await _storageService.securelyDeleteFile(file);
  }

  /// Exports the entire vault as an encrypted zip.
  Future<void> exportBackup(String path) async {
    await _storageService.exportBackup(path);
  }

  /// Imports from backup zip and refreshes status.
  Future<void> importBackup(String path) async {
    await _storageService.importBackup(path);
    await checkVaultStatus();
  }

  /// Returns storage usage statistics.
  Future<Map<String, dynamic>> getStorageUsage() async {
    return _storageService.getStorageUsage();
  }

  /// Completely wipes the vault folder and resets state.
  Future<void> wipeVault() async {
    await _storageService.deleteEntireVault();
    _masterPassword = null;
    _secretKey = null;
    _items.clear();
    _status = VaultStatus.uninitialized;

    // Clear biometric settings
    await _biometricService.setBiometricUnlockEnabled(false);
    _biometricEnabled = false;

    notifyListeners();
  }

  /// Sync local vault items and files.
  Future<void> syncWithCloud() async {
    if (_masterPassword == null ||
        _secretKey == null ||
        !supabaseService.isLoggedIn)
      return;

    try {
      _isSyncing = true;
      notifyListeners();

      // Re-fetch membership & items
      final teamMembership = await supabaseService.getMyTeamMembership();
      List<Map<String, dynamic>> remoteRecords = [];
      SecretKey keyToUse = _secretKey!;

      if (teamMembership != null) {
        final roleData = teamMembership['roles'] as Map<String, dynamic>?;
        if (roleData != null) {
          _currentRole = Role.fromJson(roleData);
        }
        final ownerId = teamMembership['owner_id'] as String;
        final encryptedOwnerKeyStr =
            teamMembership['encrypted_owner_key'] as String?;
        if (encryptedOwnerKeyStr != null) {
          final encryptedMap =
              jsonDecode(encryptedOwnerKeyStr) as Map<String, dynamic>;
          final decryptedOwnerKeyBase64 = await _encryptionService.decryptText(
            encryptedMap['ciphertext'] as String,
            encryptedMap['nonce'] as String,
            encryptedMap['mac'] as String,
            _secretKey!,
          );
          final ownerKeyBytes = base64.decode(decryptedOwnerKeyBase64);
          keyToUse = SecretKey(ownerKeyBytes);
        }
        remoteRecords = await supabaseService.fetchOwnerItems(ownerId);
      } else {
        _currentRole = null;
        remoteRecords = await supabaseService.fetchItems();
      }

      List<VaultItem> remoteItems = [];
      for (final record in remoteRecords) {
        try {
          final remoteEncryptedData = record['encrypted_data'] as String;
          final decodedEnc =
              jsonDecode(remoteEncryptedData) as Map<String, dynamic>;
          final decryptedJson = await _encryptionService.decryptText(
            decodedEnc['ciphertext'] as String,
            decodedEnc['nonce'] as String,
            decodedEnc['mac'] as String,
            keyToUse,
          );
          remoteItems.add(
            VaultItem.fromJson(
              jsonDecode(decryptedJson) as Map<String, dynamic>,
            ),
          );
        } catch (_) {
          // Skip corrupted items
        }
      }

      // Filter items based on role permissions
      if (_currentRole != null) {
        remoteItems = remoteItems.where((item) {
          switch (item.type) {
            case VaultType.password:
              return _currentRole!.canViewPasswords;
            case VaultType.apiKey:
              return _currentRole!.canViewApiKeys;
            case VaultType.email:
              return _currentRole!.canViewEmails;
            case VaultType.note:
              return _currentRole!.canViewNotes;
            case VaultType.image:
              return _currentRole!.canViewImages;
            case VaultType.card:
              return _currentRole!.canViewCards;
            case VaultType.document:
              return _currentRole!.canViewDocuments;
            default:
              return false;
          }
        }).toList();
      }

      _items = remoteItems;
      _lastSyncTime = DateTime.now().toIso8601String();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_sync_time', _lastSyncTime!);
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  /// Helper to encrypt and upload a local item to Supabase
  Future<void> _uploadItemToSupabase(VaultItem item) async {
    final itemJson = jsonEncode(item.toJson());
    final encryptedMap = await _encryptionService.encryptText(
      itemJson,
      _secretKey!,
    );
    final encryptedData = jsonEncode(encryptedMap);
    await supabaseService.upsertItem(
      item.id,
      encryptedData,
      item.updatedAt.toIso8601String(),
    );
  }
}
