import 'package:calimind/domain/models/task.dart';
import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _androidWidgetProvider =
    'com.calimind.calimind.CaliMindWidgetProvider';
const String _iosWidgetKind = 'CaliMindNextTaskWidget';
const String _iosAppGroup = 'group.io.supabase.calimind';
const String _privacyPreferenceKey = 'next_task_widget_enabled';
const String _taskTitleKey = 'next_task_title';

/// Publishes a minimal, privacy-conscious next-task summary to the home widget.
///
/// Call [refresh] after task or schedule changes. Only a task title is shared
/// with the native widget; descriptions and other task fields are never saved.
class WidgetService {
  WidgetService._();

  /// URI opened by the widget voice shortcut. The app should route this to its
  /// voice-capture screen from the `voice-capture` host. Microphone capture is
  /// started only after the explicit widget tap opens the app.
  static const String voiceCaptureDeepLink =
      'io.supabase.calimind://voice-capture';

  /// Returns whether the user has explicitly opted in to sharing the next
  /// task title with the home-screen widget. The privacy-safe default is off.
  static Future<bool> isTaskTitleSharingEnabled() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(_privacyPreferenceKey) ?? false;
  }

  /// Publishes the selected task title and refreshes the native widget.
  ///
  /// Call after task mutations and schedule changes. Only a title is shared;
  /// descriptions and other task fields are never saved. Pass task IDs in
  /// schedule display order to prioritize scheduled tasks.
  static Future<void> refresh(
    Iterable<Task> tasks, {
    Iterable<String> scheduledTaskIds = const [],
  }) async {
    try {
      await HomeWidget.setAppGroupId(_iosAppGroup);
      final privacyEnabled = await isTaskTitleSharingEnabled();
      final nextTask = privacyEnabled
          ? selectNextIncompleteTask(
              tasks,
              scheduledTaskIds: scheduledTaskIds,
            )
          : null;
      final title = nextTask?.title.trim().replaceAll(RegExp(r'\s+'), ' ');

      await HomeWidget.saveWidgetData<String>(
        _taskTitleKey,
        title == null || title.isEmpty ? null : title,
      );
      await _updateWidget();
    } catch (error) {
      debugPrint('Could not refresh CaliMind home widget: $error');
    }
  }

  /// Disables task-title sharing when false; the widget then shows generic
  /// text while keeping the voice shortcut available. Call [refresh] after
  /// re-enabling sharing to publish the latest task title.
  static Future<void> setTaskTitleSharingEnabled(bool enabled) async {
    await HomeWidget.setAppGroupId(_iosAppGroup);
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_privacyPreferenceKey, enabled);
    if (!enabled) {
      await HomeWidget.saveWidgetData<String>(_taskTitleKey, null);
    }
    await _updateWidget();
  }

  /// Clears any task data exposed by the widget without changing opt-in.
  static Future<void> clearPublishedTaskTitle() async {
    try {
      await HomeWidget.setAppGroupId(_iosAppGroup);
      await HomeWidget.saveWidgetData<String>(_taskTitleKey, null);
      await _updateWidget();
    } catch (error) {
      debugPrint('Could not clear the home-widget task title: $error');
    }
  }

  static Future<void> _updateWidget() async {
    await HomeWidget.updateWidget(
      androidName: _androidWidgetProvider,
      iOSName: _iosWidgetKind,
    );
  }
}

/// Selects the next incomplete task, preferring the supplied schedule order.
///
/// Tasks not present in [scheduledTaskIds] follow by earliest deadline, then
/// higher priority, creation time, and stable ID. Task descriptions are never
/// used or returned by this selector.
Task? selectNextIncompleteTask(
  Iterable<Task> tasks, {
  Iterable<String> scheduledTaskIds = const [],
}) {
  final incompleteTasks = tasks
      .where((task) => !task.completed && task.title.trim().isNotEmpty)
      .toList();
  if (incompleteTasks.isEmpty) return null;

  final scheduleOrder = <String, int>{};
  for (final taskId in scheduledTaskIds) {
    scheduleOrder.putIfAbsent(taskId, () => scheduleOrder.length);
  }

  incompleteTasks.sort((left, right) {
    final leftScheduleOrder = scheduleOrder[left.id];
    final rightScheduleOrder = scheduleOrder[right.id];
    if (leftScheduleOrder != null || rightScheduleOrder != null) {
      if (leftScheduleOrder == null) return 1;
      if (rightScheduleOrder == null) return -1;
      final bySchedule = leftScheduleOrder.compareTo(rightScheduleOrder);
      if (bySchedule != 0) return bySchedule;
    }

    final leftDeadline = left.deadline;
    final rightDeadline = right.deadline;
    if (leftDeadline != null || rightDeadline != null) {
      if (leftDeadline == null) return 1;
      if (rightDeadline == null) return -1;
      final byDeadline = leftDeadline.compareTo(rightDeadline);
      if (byDeadline != 0) return byDeadline;
    }

    final byPriority = left.priority.compareTo(right.priority);
    if (byPriority != 0) return byPriority;
    final byCreated = left.createdAt.compareTo(right.createdAt);
    if (byCreated != 0) return byCreated;
    return left.id.compareTo(right.id);
  });
  return incompleteTasks.first;
}
