import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:calimind/data/repositories/profile_repository_impl.dart';
import 'package:calimind/domain/models/profile.dart';

class ProfileNotifier extends StateNotifier<AsyncValue<PrivacyProfile>> {
  final ProfileRepositoryImpl _repo;

  ProfileNotifier(this._repo) : super(const AsyncValue.loading()) {
    _load();
  }

  Future<void> _load() async {
    try {
      final profile = await _repo.getProfile();
      state = AsyncValue.data(profile);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> updateRetentionDays(int days) async {
    final current = state.valueOrNull;
    if (current == null) return;
    final updated = current.copyWith(dataRetentionDays: days);
    state = AsyncValue.data(updated);
    try {
      await _repo.updateProfile(updated);
    } catch (_) {
      state = AsyncValue.data(current);
    }
  }

  Future<void> toggleEmailProcessing(bool allow) async {
    final current = state.valueOrNull;
    if (current == null) return;
    final updated = current.copyWith(allowEmailProcessing: allow);
    state = AsyncValue.data(updated);
    try {
      await _repo.updateProfile(updated);
    } catch (_) {
      state = AsyncValue.data(current);
    }
  }
}

final profileRepositoryProvider = Provider<ProfileRepositoryImpl>(
  (ref) => ProfileRepositoryImpl(),
);

final profileProvider = StateNotifierProvider<ProfileNotifier, AsyncValue<PrivacyProfile>>((ref) {
  return ProfileNotifier(ref.watch(profileRepositoryProvider));
});
