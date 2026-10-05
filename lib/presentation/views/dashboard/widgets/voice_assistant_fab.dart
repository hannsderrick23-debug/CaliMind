import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:calimind/core/constants/app_colors.dart';
import 'package:calimind/presentation/state/voice_assistant_provider.dart';
import 'package:calimind/presentation/widgets/star_loading_indicator.dart';

class VoiceAssistantFab extends ConsumerWidget {
  final VoidCallback onTap;

  const VoiceAssistantFab({super.key, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final voiceState = ref.watch(voiceAssistantProvider);
    final isListening = voiceState.voiceState == VoiceState.listening;
    final isProcessing = voiceState.voiceState == VoiceState.processing;
    final label = isListening
        ? 'Stop voice recording'
        : isProcessing
            ? 'Voice request processing'
            : 'Start voice recording';

    return Semantics(
      button: true,
      label: label,
      child: Tooltip(
        message: label,
        child: Material(
          color: Colors.transparent,
          child: InkResponse(
            onTap: isProcessing ? null : onTap,
            radius: 40,
            child: SizedBox(
              width: 58,
              height: 58,
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  if (isListening)
                    Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: CaliMindColors.destructive
                            .withValues(alpha: 0.10),
                        border: Border.all(
                          color: CaliMindColors.destructive
                              .withValues(alpha: 0.35),
                        ),
                      ),
                    ),
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: isListening
                          ? CaliMindColors.destructive
                          : CaliMindColors.primary,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: isProcessing
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: const StarLoadingIndicator(
                              size: 22,
                              color: Colors.white,
                            ),
                          )
                        : Icon(
                            LucideIcons.mic,
                            color: Colors.white,
                            size: 24,
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
