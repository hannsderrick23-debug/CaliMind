import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:calimind/core/constants/app_colors.dart';
import 'package:calimind/core/constants/app_typography.dart';
import 'package:calimind/presentation/widgets/auth_backdrop.dart';
import 'package:calimind/presentation/widgets/calimind_mark.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AuthBackdrop(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: GlassPanel(
              padding: const EdgeInsets.fromLTRB(26, 32, 26, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CaliMindMark(size: 82)
                      .animate()
                      .fadeIn(duration: 700.ms)
                      .scale(begin: const Offset(0.82, 0.82), curve: Curves.easeOutBack),
                  const SizedBox(height: 22),
                  Text(
                    'Make room for what matters.',
                    textAlign: TextAlign.center,
                    style: CaliMindTypography.h1.copyWith(
                      color: CaliMindColors.foreground,
                      fontSize: 32,
                      height: 1.12,
                    ),
                  ).animate().fadeIn(delay: 120.ms).slideY(begin: 0.08),
                  const SizedBox(height: 12),
                  Text(
                    'A calmer way to gather your thoughts, shape your day, and follow through.',
                    textAlign: TextAlign.center,
                    style: CaliMindTypography.bodyMedium.copyWith(
                      color: CaliMindColors.mutedForeground,
                      height: 1.55,
                    ),
                  ).animate().fadeIn(delay: 220.ms),
                  const SizedBox(height: 27),
                  const _WelcomeBenefit(
                    icon: LucideIcons.audioLines,
                    title: 'Say what’s on your mind',
                    detail: 'Capture a task in your own words.',
                  ).animate().fadeIn(delay: 320.ms).slideX(begin: -0.06),
                  const SizedBox(height: 12),
                  const _WelcomeBenefit(
                    icon: LucideIcons.sparkles,
                    title: 'Turn it into a clear plan',
                    detail: 'Review every detail before it is saved.',
                  ).animate().fadeIn(delay: 420.ms).slideX(begin: 0.06),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                        onPressed: () => context.go('/register'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: CaliMindColors.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          'Get started',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                    ),
                  ).animate().fadeIn(delay: 520.ms).slideY(begin: 0.12),
                  const SizedBox(height: 7),
                  Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        'Already have an account?',
                        style: TextStyle(
                          color: CaliMindColors.mutedForeground,
                        ),
                      ),
                      TextButton(
                        onPressed: () => context.go('/login'),
                        child: const Text(
                          'Sign in',
                          style: TextStyle(
                            color: CaliMindColors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ).animate().fadeIn(delay: 600.ms),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WelcomeBenefit extends StatelessWidget {
  final IconData icon;
  final String title;
  final String detail;

  const _WelcomeBenefit({
    required this.icon,
    required this.title,
    required this.detail,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: CaliMindColors.surfaceOverlay,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: CaliMindColors.cardBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: CaliMindColors.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: CaliMindColors.primary, size: 19),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: CaliMindColors.foreground,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  detail,
                  style: TextStyle(
                    color: CaliMindColors.mutedForeground,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
