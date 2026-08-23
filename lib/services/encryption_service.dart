import 'dart:convert';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';

class EncryptionService {
  // Argon2id parameters for key derivation
  static const int _argonParallelism = 2;
  static const int _argonMemory = 15000; // 15 MB
  static const int _argonIterations = 2;
  static const int _argonHashLength = 32; // 256 bits for AES-256

  final _aesGcm = AesGcm.with256bits();

  /// Derives a 32-byte cryptographic key from the user's master password and salt.
  /// Runs inside a background Isolate to prevent freezing the Flutter UI thread.
  Future<SecretKey> deriveKey(String password, List<int> salt) async {
    final keyBytes = await Isolate.run(() => _deriveKeyIsolate({
          'password': password,
          'salt': salt,
        }));
    return SecretKey(keyBytes);
  }

  /// Top-level or static function for isolate execution
  static Future<List<int>> _deriveKeyIsolate(Map<String, dynamic> params) async {
    final password = params['password'] as String;
    final salt = params['salt'] as List<int>;

    final argon2id = Argon2id(
      parallelism: _argonParallelism,
      memory: _argonMemory,
      iterations: _argonIterations,
      hashLength: _argonHashLength,
    );

    final secretKey = await argon2id.deriveKey(
      secretKey: SecretKey(utf8.encode(password)),
      nonce: salt,
    );

    return secretKey.extractBytes();
  }

  /// Encrypts raw bytes using AES-256-GCM with the derived secret key.
  Future<SecretBox> encryptBytes(List<int> plaintext, SecretKey secretKey) async {
    return _aesGcm.encrypt(
      plaintext,
      secretKey: secretKey,
    );
  }

  /// Decrypts a SecretBox using AES-256-GCM with the derived secret key.
  Future<List<int>> decryptBytes(SecretBox secretBox, SecretKey secretKey) async {
    return _aesGcm.decrypt(
      secretBox,
      secretKey: secretKey,
    );
  }

  /// Helper to encrypt a plain string (e.g. JSON database index).
  /// Returns a JSON-compatible Map containing base64 encoded ciphertext, nonce, and MAC tag.
  Future<Map<String, String>> encryptText(String text, SecretKey secretKey) async {
    final bytes = utf8.encode(text);
    final box = await encryptBytes(bytes, secretKey);
    return {
      'ciphertext': base64.encode(box.cipherText),
      'nonce': base64.encode(box.nonce),
      'mac': base64.encode(box.mac.bytes),
    };
  }

  /// Helper to decrypt a ciphertext Map back to a plain string.
  Future<String> decryptText(
    String ciphertextBase64,
    String nonceBase64,
    String macBase64,
    SecretKey secretKey,
  ) async {
    final box = SecretBox(
      base64.decode(ciphertextBase64),
      nonce: base64.decode(nonceBase64),
      mac: Mac(base64.decode(macBase64)),
    );
    final decryptedBytes = await decryptBytes(box, secretKey);
    return utf8.decode(decryptedBytes);
  }

  /// Generates a cryptographically secure random salt of the specified length.
  List<int> generateRandomSalt([int length = 16]) {
    final random = Random.secure();
    return List<int>.generate(length, (_) => random.nextInt(256));
  }
}
