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
      showWelcomeImage: true,
      child: Center(
        child: GlassPanel(
          glass: true,
          padding: const EdgeInsets.symmetric(horizontal: 34, vertical: 38),
          borderRadius: BorderRadius.circular(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CaliMindMark(size: 88)
                  .animate()
                  .fadeIn(duration: 550.ms)
                  .scale(
                    begin: const Offset(0.86, 0.86),
                    curve: Curves.easeOutBack,
                  ),
              const SizedBox(height: 24),
              Text(
                'CaliMind',
                style: CaliMindTypography.h1.copyWith(
                  color: CaliMindColors.foreground,
                  fontSize: 36,
                  letterSpacing: -0.8,
                ),
              ).animate().fadeIn(delay: 120.ms).slideY(begin: 0.1),
              const SizedBox(height: 8),
              Text(
                'A little more clarity, every day.',
                textAlign: TextAlign.center,
                style: CaliMindTypography.bodyMedium.copyWith(
                  color: CaliMindColors.mutedForeground,
                  letterSpacing: 0.2,
                ),
              ).animate().fadeIn(delay: 260.ms),
              const SizedBox(height: 38),
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: CaliMindColors.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
