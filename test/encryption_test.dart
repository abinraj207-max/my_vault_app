import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:cryptography/cryptography.dart';
import 'package:my_vault/services/encryption_service.dart';

void main() {
  // Required for Flutter environment tests
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Cryptography Service Tests', () {
    final encryptionService = EncryptionService();

    test('Argon2id Key Derivation produces consistent key bytes', () async {
      const password = 'TestSecretMasterPassword123!';
      final salt = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16];

      // Derive key 1
      final key1 = await encryptionService.deriveKey(password, salt);
      final bytes1 = await key1.extractBytes();

      // Derive key 2 with same params
      final key2 = await encryptionService.deriveKey(password, salt);
      final bytes2 = await key2.extractBytes();

      // Derive key 3 with different password
      final key3 = await encryptionService.deriveKey('DifferentPassword', salt);
      final bytes3 = await key3.extractBytes();

      expect(bytes1.length, 32, reason: 'AES-256 key must be 32 bytes long');
      expect(bytes1, bytes2, reason: 'Identical password and salt must yield identical keys');
      expect(bytes1, isNot(equals(bytes3)), reason: 'Different passwords must yield different keys');
    });

    test('AES-256-GCM String Encryption and Decryption Round-Trip', () async {
      const password = 'AnotherSecretPassword!@#';
      final salt = encryptionService.generateRandomSalt(16);
      final key = await encryptionService.deriveKey(password, salt);

      const originalText = 'Highly sensitive API key: sk-live-123456789abcdef';

      // Encrypt
      final encryptedMap = await encryptionService.encryptText(originalText, key);
      expect(encryptedMap.containsKey('ciphertext'), true);
      expect(encryptedMap.containsKey('nonce'), true);
      expect(encryptedMap.containsKey('mac'), true);

      // Decrypt
      final decryptedText = await encryptionService.decryptText(
        encryptedMap['ciphertext']!,
        encryptedMap['nonce']!,
        encryptedMap['mac']!,
        key,
      );

      expect(decryptedText, originalText, reason: 'Decrypted string must match original string');
    });

    test('AES-256-GCM Raw Bytes Encryption and Decryption Round-Trip', () async {
      const password = 'KeyBytesPassword';
      final salt = encryptionService.generateRandomSalt(16);
      final key = await encryptionService.deriveKey(password, salt);

      final originalBytes = List<int>.generate(256, (i) => i); // 0 to 255

      // Encrypt
      final secretBox = await encryptionService.encryptBytes(originalBytes, key);
      expect(secretBox.nonce.length, 12, reason: 'AES-GCM standard nonce is 12 bytes');
      expect(secretBox.mac.bytes.length, 16, reason: 'AES-GCM standard MAC tag is 16 bytes');

      // Decrypt
      final decryptedBytes = await encryptionService.decryptBytes(secretBox, key);
      expect(decryptedBytes, originalBytes, reason: 'Decrypted bytes must match original input');
    });
  });
}
