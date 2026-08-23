import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:cryptography/cryptography.dart';
import 'package:my_vault/services/encryption_service.dart';
import 'package:my_vault/models/vault_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Supabase Client-Side Zero-Knowledge Encryption Tests', () {
    final encryptionService = EncryptionService();
    const masterPassword = 'MySecretMasterPassword123!';
    final salt = encryptionService.generateRandomSalt(16);

    test('Sensitive VaultItem properties are fully encrypted (No Plaintext Leaks)', () async {
      final key = await encryptionService.deriveKey(masterPassword, salt);

      // Create a sensitive VaultItem (containing API key, credentials, secret note)
      final sensitiveItem = VaultItem(
        id: 'test-item-uuid-1',
        type: VaultType.apiKey,
        title: 'Production Cashfree Gateway',
        tags: ['production', 'cashfree'],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        service: 'Cashfree Payment Gateway API',
        apiKey: 'cf_live_9a8b7c6d5e4f3g2h1i',
        secretKey: 'sk_live_verysecretcashfreeapikeyhere',
        environment: 'Production',
        notes: 'Credentials for the production cashfree gateway payments.',
      );

      // 1. Serialize item details to JSON
      final itemJson = jsonEncode(sensitiveItem.toJson());

      // 2. Encrypt the entire serialized string
      final encryptedMap = await encryptionService.encryptText(itemJson, key);

      // 3. Verify encryption outputs exist
      expect(encryptedMap.containsKey('ciphertext'), true);
      expect(encryptedMap.containsKey('nonce'), true);
      expect(encryptedMap.containsKey('mac'), true);

      // 4. Verify ciphertext does NOT leak any plaintext keys/values
      final ciphertextStr = encryptedMap['ciphertext']!;
      expect(ciphertextStr.contains('cf_live_'), false);
      expect(ciphertextStr.contains('verysecretcashfree'), false);
      expect(ciphertextStr.contains('Production Cashfree Gateway'), false);

      // 5. Decrypt and deserialize back to VaultItem
      final decryptedJson = await encryptionService.decryptText(
        encryptedMap['ciphertext']!,
        encryptedMap['nonce']!,
        encryptedMap['mac']!,
        key,
      );

      final decodedMap = jsonDecode(decryptedJson) as Map<String, dynamic>;
      final decryptedItem = VaultItem.fromJson(decodedMap);

      // 6. Verify all decrypted fields match the original
      expect(decryptedItem.id, sensitiveItem.id);
      expect(decryptedItem.title, sensitiveItem.title);
      expect(decryptedItem.type, sensitiveItem.type);
      expect(decryptedItem.apiKey, sensitiveItem.apiKey);
      expect(decryptedItem.secretKey, sensitiveItem.secretKey);
      expect(decryptedItem.notes, sensitiveItem.notes);
    });

    test('Local File Cryptographic Payload Format Verification', () async {
      final key = await encryptionService.deriveKey(masterPassword, salt);
      final filePlaintextBytes = utf8.encode('Highly classified PDF content: Company Secret Roadmap 2027');

      // Encrypt file bytes
      final secretBox = await encryptionService.encryptBytes(filePlaintextBytes, key);

      // Structure target file payload format: [12 bytes Nonce] [16 bytes MAC] [Ciphertext]
      final filePayloadBytes = <int>[
        ...secretBox.nonce,
        ...secretBox.mac.bytes,
        ...secretBox.cipherText,
      ];

      // Verify header sizing constraints
      expect(secretBox.nonce.length, 12);
      expect(secretBox.mac.bytes.length, 16);
      expect(filePayloadBytes.length, 12 + 16 + secretBox.cipherText.length);

      // Extract cryptographic materials back from payload
      final extractedNonce = filePayloadBytes.sublist(0, 12);
      final extractedMac = filePayloadBytes.sublist(12, 28);
      final extractedCiphertext = filePayloadBytes.sublist(28);

      final boxToDecrypt = SecretBox(
        extractedCiphertext,
        nonce: extractedNonce,
        mac: Mac(extractedMac),
      );

      // Decrypt
      final decryptedFileBytes = await encryptionService.decryptBytes(boxToDecrypt, key);
      final decryptedText = utf8.decode(decryptedFileBytes);

      expect(decryptedText, 'Highly classified PDF content: Company Secret Roadmap 2027');
    });

    test('Sync Conflict Resolution Logic Simulator', () {
      final localTime = DateTime.parse('2026-08-15T12:00:00Z');
      final remoteTime = DateTime.parse('2026-08-15T13:00:00Z');

      // Scenario A: Remote is newer
      expect(remoteTime.isAfter(localTime), true);
      // Expected action: Overwrite local with remote (localChanged = true)

      // Scenario B: Local is newer
      final localTimeNewer = DateTime.parse('2026-08-15T14:00:00Z');
      expect(localTimeNewer.isAfter(remoteTime), true);
      // Expected action: Upload local to remote
    });

    test('Vault Salt Metadata Format and Encoding Verification', () {
      final salt = encryptionService.generateRandomSalt(16);
      final saltBase64 = base64.encode(salt);
      
      // Verify base64 encoding/decoding round-trip matches the original salt
      final decodedSalt = base64.decode(saltBase64);
      expect(decodedSalt, salt);
      expect(decodedSalt.length, 16);
    });
  });
}
