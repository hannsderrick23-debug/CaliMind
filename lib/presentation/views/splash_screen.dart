import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:calimind/core/constants/app_colors.dart';
import 'package:calimind/core/constants/app_typography.dart';
import 'package:calimind/presentation/widgets/auth_backdrop.dart';
import 'package:calimind/presentation/widgets/calimind_mark.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AuthBackdrop(
      child: Center(
        child: GlassPanel(
          padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 42),
          borderRadius: BorderRadius.circular(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CaliMindMark(size: 84)
                  .animate()
                  .fadeIn(duration: 500.ms),
              const SizedBox(height: 18),
              Text(
                'CaliMind',
                style: CaliMindTypography.h1.copyWith(
                  color: CaliMindColors.foreground,
                  fontSize: 32,
                ),
              ).animate().fadeIn(duration: 700.ms).slideY(begin: 0.12),
              const SizedBox(height: 10),
              Text(
                'A little more clarity, every day.',
                style: CaliMindTypography.label.copyWith(
                  color: CaliMindColors.mutedForeground,
                ),
              ).animate().fadeIn(delay: 250.ms),
              const SizedBox(height: 26),
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: CaliMindColors.primary,
                ),
              ),
            ],
          ),
        ).animate().fadeIn(duration: 500.ms).scale(begin: const Offset(0.96, 0.96)),
      ),
    );
  }
}
