import 'package:calimind/data/datasources/schedule_remote_datasource.dart';
import 'package:calimind/domain/models/schedule_slot.dart';

class ScheduleRepositoryImpl {
  final ScheduleRemoteDatasource _datasource;

  ScheduleRepositoryImpl({ScheduleRemoteDatasource? datasource})
      : _datasource = datasource ?? ScheduleRemoteDatasourceImpl();

  Future<List<ScheduleSlot>> getSlotsForDate(String date) =>
      _datasource.fetchSlotsForDate(date);

  Future<void> saveSchedule(List<ScheduleSlot> slots, String date) =>
      _datasource.saveSchedule(slots, date);

  Future<void> clearScheduleForDate(String date) =>
      _datasource.clearScheduleForDate(date);
}
