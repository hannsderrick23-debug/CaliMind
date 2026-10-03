import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:calimind/domain/services/focus_session_controller.dart';

final focusSessionControllerProvider = Provider<FocusSessionController>((ref) {
  final controller = FocusSessionController(
    storage: SharedPreferencesFocusSessionStorage(),
  );
  ref.onDispose(controller.dispose);
  return controller;
});
