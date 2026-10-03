import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:calimind/core/network/supabase_client.dart';
import 'package:calimind/domain/models/schedule_slot.dart';

abstract class ScheduleRemoteDatasource {
  Future<List<ScheduleSlot>> fetchSlotsForDate(String date);
  Future<List<ScheduleSlot>> fetchSlotsBetween(String startDate, String endDate);
  Future<void> saveSchedule(List<ScheduleSlot> slots, String date);
  Future<void> clearScheduleForDate(String date);
}

class ScheduleRemoteDatasourceImpl implements ScheduleRemoteDatasource {
  ({SupabaseClient client, String userId}) _requireSession() {
    try {
      if (!SupabaseConfig.isConfigured) {
        throw StateError('Supabase is not configured for this app.');
      }
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      if (user == null) {
        throw StateError('Sign in before accessing your schedule.');
      }
      return (client: client, userId: user.id);
    } on StateError {
      rethrow;
    } catch (error) {
      throw StateError('Supabase is not available: $error');
    }
  }

  @override
  Future<List<ScheduleSlot>> fetchSlotsForDate(String date) async {
    final session = _requireSession();
    final rows = await session.client
        .from('schedule_blocks')
        .select('*, tasks(title, category, duration)')
        .eq('user_id', session.userId)
        .eq('schedule_date', date)
        .order('start_time');
    return rows.map((row) => ScheduleSlot.fromJson(row)).toList();
  }

  @override
  Future<List<ScheduleSlot>> fetchSlotsBetween(
    String startDate,
    String endDate,
  ) async {
    final session = _requireSession();
    final rows = await session.client
        .from('schedule_blocks')
        .select('*, tasks(title, category, duration)')
        .eq('user_id', session.userId)
        .gte('schedule_date', startDate)
        .lte('schedule_date', endDate)
        .order('schedule_date')
        .order('start_time');
    return rows.map((row) => ScheduleSlot.fromJson(row)).toList();
  }

  @override
  Future<void> saveSchedule(List<ScheduleSlot> slots, String date) async {
    final session = _requireSession();
    await session.client
        .from('schedule_blocks')
        .delete()
        .eq('user_id', session.userId)
        .eq('schedule_date', date);
    if (slots.isEmpty) return;
    final rows = slots.map((slot) => slot.toJson(session.userId, date)).toList();
    await session.client.from('schedule_blocks').insert(rows);
  }

  @override
  Future<void> clearScheduleForDate(String date) async {
    final session = _requireSession();
    await session.client
        .from('schedule_blocks')
        .delete()
        .eq('user_id', session.userId)
        .eq('schedule_date', date);
  }
}
