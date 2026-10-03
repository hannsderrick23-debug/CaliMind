import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SecureLocalStorage extends LocalStorage {
  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  @override
  Future<void> initialize() async {}

  @override
  Future<String?> accessToken() async {
    return _storage.read(key: supabasePersistSessionKey);
  }

  @override
  Future<bool> hasAccessToken() async {
    return _storage.containsKey(key: supabasePersistSessionKey);
  }

  @override
  Future<void> persistSession(String persistSessionString) async {
    await _storage.write(
      key: supabasePersistSessionKey,
      value: persistSessionString,
    );
  }

  @override
  Future<void> removePersistedSession() async {
    await _storage.delete(key: supabasePersistSessionKey);
  }
}

class SupabaseConfig {
  static const String defaultUrl = 'https://ehntfznnwqnbfekkojcf.supabase.co';
  static const String defaultPublishableKey =
      'sb_publishable_ChDmtcte4IKvLpOvAboh5A_v1yToL8M';

  static String url =
      const String.fromEnvironment('SUPABASE_URL', defaultValue: defaultUrl);
  static String publishableKey = const String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: defaultPublishableKey,
  );

  static bool get isConfigured => url.isNotEmpty && publishableKey.isNotEmpty;

  static SupabaseClient get client => Supabase.instance.client;

  static Future<void> initialize({
    String? customUrl,
    String? customPublishableKey,
  }) async {
    final effectiveUrl = customUrl ?? url;
    final effectiveKey = customPublishableKey ?? publishableKey;
    url = effectiveUrl;
    publishableKey = effectiveKey;

    await Supabase.initialize(
      url: effectiveUrl,
      publishableKey: effectiveKey,
      authOptions: FlutterAuthClientOptions(
        localStorage: SecureLocalStorage(),
      ),
    );
  }
}
