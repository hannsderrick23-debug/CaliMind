import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:calimind/core/network/supabase_client.dart';
import 'package:calimind/domain/models/profile.dart';

abstract class ProfileRemoteDatasource {
  Future<PrivacyProfile> fetchProfile();
  Future<PrivacyProfile> updateProfile(PrivacyProfile profile);
}

class ProfileRemoteDatasourceImpl implements ProfileRemoteDatasource {
  PrivacyProfile _mockProfile = PrivacyProfile(
    userId: 'mock-user',
    dataRetentionDays: 90,
    allowEmailProcessing: true,
    marketingOptIn: false,
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  SupabaseClient? get _client {
    try {
      if (SupabaseConfig.isConfigured) return Supabase.instance.client;
    } catch (_) {}
    return null;
  }

  String? get _userId {
    try {
      return Supabase.instance.client.auth.currentUser?.id;
    } catch (_) {
      return 'mock-user';
    }
  }

  @override
  Future<PrivacyProfile> fetchProfile() async {
    final client = _client;
    final uid = _userId;
    if (client != null && uid != null && uid != 'mock-user') {
      try {
        final res = await client.from('profiles').select().eq('user_id', uid).maybeSingle();
        if (res != null) return PrivacyProfile.fromJson(res);
      } catch (e) {
        debugPrint('Fetch profile remote error: $e');
      }
    }
    return _mockProfile;
  }

  @override
  Future<PrivacyProfile> updateProfile(PrivacyProfile profile) async {
    final client = _client;
    final uid = _userId;
    if (client != null && uid != null && uid != 'mock-user') {
      try {
        final res = await client.from('profiles').upsert(profile.toJson()).eq('user_id', uid).select().single();
        return PrivacyProfile.fromJson(res);
      } catch (e) {
        debugPrint('Update profile remote error: $e');
      }
    }
    _mockProfile = profile;
    return _mockProfile;
  }
}
