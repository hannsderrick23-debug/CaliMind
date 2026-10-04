import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:calimind/core/services/widget_service.dart';
import 'package:calimind/core/utils/app_feedback.dart';
import 'package:calimind/domain/models/task.dart';
import 'package:calimind/presentation/state/schedule_provider.dart';
import 'package:calimind/presentation/state/task_provider.dart';

Future<void> deleteTaskWithUndo(
  BuildContext context,
  WidgetRef ref,
  Task task, {
  bool confirm = false,
}) async {
  if (confirm) {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete task?'),
        content: Text('“${task.title}” will be removed from your task list.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
  }

  final notifier = ref.read(taskProvider.notifier);
  if (!notifier.stageTaskDeletion(task.id)) {
    AppFeedback.error(
      ScaffoldMessenger.of(context),
      'Could not remove this task. Please try again.',
    );
    return;
  }
  await _refreshWidget(ref);
  if (!context.mounted) {
    await notifier.commitTaskDeletion(task.id);
    return;
  }

  final notification = AppFeedback.undoable(
    ScaffoldMessenger.of(context),
    'Task deleted.',
    onUndo: () {
      if (notifier.undoTaskDeletion(task.id) && context.mounted) {
        unawaited(_refreshWidget(ref));
      }
    },
  );
  final reason = await notification.closed;
  if (reason == SnackBarClosedReason.action) return;

  final deleted = await notifier.commitTaskDeletion(task.id);
  if (context.mounted) await _refreshWidget(ref);
  if (!deleted && context.mounted) {
    final error = notifier.lastOperationError;
    AppFeedback.error(
      ScaffoldMessenger.of(context),
      error == null || error.isEmpty
          ? 'Could not delete this task. Please try again.'
          : 'Could not delete task: $error',
    );
  }
}

Future<void> _refreshWidget(WidgetRef ref) => WidgetService.refresh(
      ref.read(taskProvider).valueOrNull ?? const <Task>[],
      scheduledTaskIds:
          ref.read(scheduleProvider).slots.map((slot) => slot.taskId),
    );
