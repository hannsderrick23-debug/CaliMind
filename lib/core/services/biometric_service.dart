import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

class BiometricService {
  static const _enabledKey = 'biometric_login_enabled';
  static const _promptedKey = 'biometric_setup_prompted';
  static const _emailKey = 'biometric_login_email';
  static const _passwordKey = 'biometric_login_password';
  static const _displayNameKey = 'last_signed_in_display_name';
  final LocalAuthentication _auth = LocalAuthentication();
  final FlutterSecureStorage _legacyStorage = const FlutterSecureStorage();
  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  Future<bool> isEnabled() async {
    final isEnabled = await _storage.read(key: _enabledKey) == 'true';
    final wasEnabled = await _legacyStorage.read(key: _enabledKey) == 'true';
    if (!isEnabled && !wasEnabled) return false;
    return await loginCredentials() != null;
  }

  Future<(String email, String password)?> loginCredentials() async {
    final email = await _storage.read(key: _emailKey);
    final password = await _storage.read(key: _passwordKey);
    if (email != null &&
        email.isNotEmpty &&
        password != null &&
        password.isNotEmpty) {
      return (email, password);
    }

    final legacyEmail = await _legacyStorage.read(key: _emailKey);
    final legacyPassword = await _legacyStorage.read(key: _passwordKey);
    if (legacyEmail == null ||
        legacyEmail.isEmpty ||
        legacyPassword == null ||
        legacyPassword.isEmpty) {
      return null;
    }

    await saveLoginCredentials(legacyEmail, legacyPassword);
    await _legacyStorage.delete(key: _enabledKey);
    await _legacyStorage.delete(key: _emailKey);
    await _legacyStorage.delete(key: _passwordKey);
    return (legacyEmail, legacyPassword);
  }

  Future<bool> hasPromptedForSetup() async {
    final prompted = await _storage.read(key: _promptedKey) == 'true';
    if (prompted) return true;
    final legacyPrompted =
        await _legacyStorage.read(key: _promptedKey) == 'true';
    if (legacyPrompted) {
      await _storage.write(key: _promptedKey, value: 'true');
    }
    return legacyPrompted;
  }

  Future<void> markSetupPrompted() =>
      _storage.write(key: _promptedKey, value: 'true');

  Future<void> saveLoginCredentials(String email, String password) async {
    try {
      await _storage.write(key: _emailKey, value: email.trim());
      await _storage.write(key: _passwordKey, value: password);
      await _storage.write(key: _enabledKey, value: 'true');
      await _storage.write(key: _promptedKey, value: 'true');
    } catch (_) {
      await _clearCurrentLoginCredentials();
      rethrow;
    }
  }

  Future<void> rememberDisplayName(String displayName) async {
    final name = displayName.trim();
    if (name.isEmpty) return;
    await _storage.write(key: _displayNameKey, value: name);
  }

  Future<String?> lastDisplayName() async {
    final name = await _storage.read(key: _displayNameKey);
    return name?.trim().isNotEmpty == true ? name!.trim() : null;
  }

  Future<void> clearLoginCredentials() async {
    await _clearCurrentLoginCredentials();
    await _legacyStorage.delete(key: _enabledKey);
    await _legacyStorage.delete(key: _emailKey);
    await _legacyStorage.delete(key: _passwordKey);
  }

  Future<void> _clearCurrentLoginCredentials() async {
    await _storage.delete(key: _enabledKey);
    await _storage.delete(key: _emailKey);
    await _storage.delete(key: _passwordKey);
  }

  Future<bool> isBiometricsAvailable() async {
    try {
      return await _auth.canCheckBiometrics &&
          (await _auth.getAvailableBiometrics()).isNotEmpty;
    } on PlatformException catch (_) {
      return false;
    }
  }

  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _auth.getAvailableBiometrics();
    } on PlatformException catch (_) {
      return [];
    }
  }

  Future<bool> authenticate({
    String localizedReason = 'Unlock CaliMind with biometrics',
  }) async {
    try {
      final isAvailable = await isBiometricsAvailable();
      if (!isAvailable) return false;

      return await _auth.authenticate(
        localizedReason: localizedReason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
    } on PlatformException catch (_) {
      return false;
    }
  }
}
