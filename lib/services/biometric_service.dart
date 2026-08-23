import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BiometricService {
  final LocalAuthentication _auth = LocalAuthentication();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  static const String _biometricEnabledKey = 'biometric_enabled';
  static const String _masterPasswordKey = 'secure_master_password';

  /// Checks if the device is capable of biometric authentication (hardware support & enrolled fingerprints/face).
  Future<bool> isBiometricsAvailable() async {
    final bool canAuthenticateWithBiometrics = await _auth.canCheckBiometrics;
    final bool canAuthenticate = canAuthenticateWithBiometrics || await _auth.isDeviceSupported();
    return canAuthenticate;
  }

  /// Checks if biometric unlock is enabled by the user in settings.
  Future<bool> isBiometricUnlockEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_biometricEnabledKey) ?? false;
  }

  /// Sets whether biometric unlock is enabled.
  Future<void> setBiometricUnlockEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_biometricEnabledKey, enabled);
    if (!enabled) {
      // Clear password if disabled
      await _secureStorage.delete(key: _masterPasswordKey);
    }
  }

  /// Securely stores the master password in Keystore/Keychain.
  Future<void> saveMasterPassword(String password) async {
    await _secureStorage.write(key: _masterPasswordKey, value: password);
  }

  /// Securely retrieves the master password from Keystore/Keychain.
  Future<String?> getMasterPassword() async {
    return _secureStorage.read(key: _masterPasswordKey);
  }

  /// Triggers the device biometric prompt.
  /// Returns true if authentication succeeds.
  Future<bool> authenticate() async {
    try {
      final bool didAuthenticate = await _auth.authenticate(
        localizedReason: 'Please authenticate to unlock MyVault',
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );
      return didAuthenticate;
    } catch (_) {
      return false;
    }
  }
}
