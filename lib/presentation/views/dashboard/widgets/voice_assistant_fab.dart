import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:calimind/core/constants/app_colors.dart';
import 'package:calimind/presentation/state/voice_assistant_provider.dart';

class VoiceAssistantFab extends ConsumerWidget {
  final VoidCallback onTap;

  const VoiceAssistantFab({super.key, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final voiceState = ref.watch(voiceAssistantProvider);
    final isListening = voiceState.voiceState == VoiceState.listening;
    final level = voiceState.soundLevel;

    return GestureDetector(
      onTap: onTap,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer pulse ring (animated when listening)
          if (isListening)
            Container(
              width: 80 + (level * 20),
              height: 80 + (level * 20),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: CaliMindColors.primary.withValues(alpha: 0.15),
              ),
            ).animate(onPlay: (c) => c.repeat()).scale(
                  begin: const Offset(1.0, 1.0),
                  end: const Offset(1.2, 1.2),
                  duration: 900.ms,
                  curve: Curves.easeInOut,
                ),
          // Middle ring
          if (isListening)
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: CaliMindColors.primary.withValues(alpha: 0.2),
              ),
            ).animate(onPlay: (c) => c.repeat(reverse: true)).scale(
                  begin: const Offset(1.0, 1.0),
                  end: const Offset(1.08, 1.08),
                  duration: 700.ms,
                ),
          // Main FAB button
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              gradient: CaliMindColors.mindGradient,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: CaliMindColors.primary.withValues(alpha: isListening ? 0.6 : 0.35),
                  blurRadius: isListening ? 28 : 18,
                  spreadRadius: isListening ? 3 : 1,
                ),
              ],
            ),
            child: Icon(
              isListening ? LucideIcons.micOff : LucideIcons.mic,
              color: Colors.white,
              size: 26,
            ),
          ),
        ],
      ),
    );
  }
}
