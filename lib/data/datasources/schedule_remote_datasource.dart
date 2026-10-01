import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:calimind/core/network/supabase_client.dart';
import 'package:calimind/domain/models/schedule_slot.dart';

abstract class ScheduleRemoteDatasource {
  Future<List<ScheduleSlot>> fetchSlotsForDate(String date);
  Future<void> saveSchedule(List<ScheduleSlot> slots, String date);
  Future<void> clearScheduleForDate(String date);
}

class ScheduleRemoteDatasourceImpl implements ScheduleRemoteDatasource {
  final Map<String, List<ScheduleSlot>> _mockSchedule = {};

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
  Future<List<ScheduleSlot>> fetchSlotsForDate(String date) async {
    final client = _client;
    final uid = _userId;
    if (client != null && uid != null) {
      try {
        final res = await client
            .from('schedule_blocks')
            .select('*, tasks(title, category)')
            .eq('user_id', uid)
            .eq('schedule_date', date)
            .order('start_time');
        return (res as List).map((row) => ScheduleSlot.fromJson(row as Map<String, dynamic>)).toList();
      } catch (e) {
        debugPrint('Fetch schedule remote error: $e');
      }
    }
    return _mockSchedule[date] ?? [];
  }

  @override
  Future<void> saveSchedule(List<ScheduleSlot> slots, String date) async {
    final client = _client;
    final uid = _userId ?? 'mock-user';

    await clearScheduleForDate(date);

    if (client != null && uid != 'mock-user') {
      try {
        final rows = slots.map((s) => s.toJson(uid, date)).toList();
        await client.from('schedule_blocks').insert(rows);
        return;
      } catch (e) {
        debugPrint('Save schedule remote error: $e');
      }
    }
    _mockSchedule[date] = List.from(slots);
  }

  @override
  Future<void> clearScheduleForDate(String date) async {
    final client = _client;
    final uid = _userId;
    if (client != null && uid != null && uid != 'mock-user') {
      try {
        await client.from('schedule_blocks').delete().eq('user_id', uid).eq('schedule_date', date);
        return;
      } catch (e) {
        debugPrint('Clear schedule remote error: $e');
      }
    }
    _mockSchedule.remove(date);
  }
}
