import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:calimind/core/services/device_calendar_service.dart';

final deviceCalendarServiceProvider = Provider<DeviceCalendarService>(
  (ref) => DeviceCalendarService(),
);

final deviceCalendarProvider =
    StateNotifierProvider<DeviceCalendarNotifier, DeviceCalendarState>((ref) {
  return DeviceCalendarNotifier(ref.read(deviceCalendarServiceProvider));
});

class DeviceCalendarState {
  final bool enabled;
  final bool isLoading;
  final DeviceCalendarAccessStatus accessStatus;

  const DeviceCalendarState({
    this.enabled = false,
    this.isLoading = false,
    this.accessStatus = DeviceCalendarAccessStatus.notRequested,
  });
}

class DeviceCalendarNotifier extends StateNotifier<DeviceCalendarState> {
  final DeviceCalendarService _service;
  late final Future<void> _preferenceLoad;

  DeviceCalendarNotifier(this._service) : super(const DeviceCalendarState()) {
    _preferenceLoad = _loadPreference();
  }

  Future<void> _loadPreference() async {
    final enabled = await _service.isEnabled();
    if (!mounted) return;
    state = DeviceCalendarState(
      enabled: enabled,
      accessStatus: enabled
          ? DeviceCalendarAccessStatus.granted
          : DeviceCalendarAccessStatus.notRequested,
    );
  }

  Future<DeviceCalendarAccessStatus> enable() async {
    await _preferenceLoad;
    state = const DeviceCalendarState(
      isLoading: true,
      accessStatus: DeviceCalendarAccessStatus.notRequested,
    );
    final status = await _service.enableAfterUserAction();
    if (mounted) {
      state = DeviceCalendarState(
        enabled: status == DeviceCalendarAccessStatus.granted,
        accessStatus: status,
      );
    }
    return status;
  }

  Future<void> disable() async {
    await _preferenceLoad;
    await _service.disable();
    if (!mounted) return;
    state = const DeviceCalendarState(
      enabled: false,
      accessStatus: DeviceCalendarAccessStatus.disabled,
    );
  }

  Future<DeviceCalendarBusyResult> getBusyIntervalsForDay(DateTime day) async {
    if (!state.enabled) {
      return DeviceCalendarBusyResult(
        status: DeviceCalendarAccessStatus.disabled,
      );
    }
    final result = await _service.getBusyIntervalsForDay(day);
    if (mounted && result.status != DeviceCalendarAccessStatus.granted) {
      state = DeviceCalendarState(
        enabled: false,
        accessStatus: result.status,
      );
    }
    return result;
  }
}
