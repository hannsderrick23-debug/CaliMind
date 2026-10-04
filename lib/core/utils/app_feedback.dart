import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:calimind/core/constants/app_colors.dart';

class AppFeedback {
  const AppFeedback._();

  static void success(ScaffoldMessengerState messenger, String message) {
    _show(
      messenger,
      message,
      icon: LucideIcons.check,
      color: CaliMindColors.success,
    );
  }

  static void error(ScaffoldMessengerState messenger, String message) {
    _show(
      messenger,
      message,
      icon: LucideIcons.circleAlert,
      color: CaliMindColors.destructive,
    );
  }

  static void info(ScaffoldMessengerState messenger, String message) {
    _show(
      messenger,
      message,
      icon: LucideIcons.info,
      color: CaliMindColors.primary,
    );
  }

  static ScaffoldFeatureController<SnackBar, SnackBarClosedReason> undoable(
    ScaffoldMessengerState messenger,
    String message, {
    required VoidCallback onUndo,
  }) {
    messenger.hideCurrentSnackBar();
    return messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 6),
        backgroundColor: CaliMindColors.foreground,
        content: Row(
          children: [
            const Icon(
              LucideIcons.trash2,
              size: 18,
              color: CaliMindColors.warning,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        action: SnackBarAction(
          label: 'Undo',
          textColor: Colors.white,
          onPressed: onUndo,
        ),
      ),
    );
  }

  static void _show(
    ScaffoldMessengerState messenger,
    String message, {
    required IconData icon,
    required Color color,
  }) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
          backgroundColor: CaliMindColors.foreground,
          content: Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      );
  }
}
