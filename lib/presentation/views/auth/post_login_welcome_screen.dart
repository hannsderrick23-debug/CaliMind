import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:calimind/core/constants/app_colors.dart';
import 'package:calimind/core/constants/app_typography.dart';
import 'package:calimind/presentation/state/auth_provider.dart';
import 'package:calimind/presentation/widgets/auth_backdrop.dart';
import 'package:calimind/presentation/widgets/calimind_mark.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PostLoginWelcomeScreen extends ConsumerWidget {
  const PostLoginWelcomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    final metadataName = user?.userMetadata?['full_name'] as String?;
    final firstName = metadataName?.trim().split(RegExp(r'\s+')).first;

    return AuthBackdrop(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: GlassPanel(
              padding: const EdgeInsets.fromLTRB(26, 32, 26, 26),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CaliMindMark(size: 84),
                  const SizedBox(height: 24),
                  Text(
                    firstName == null || firstName.isEmpty
                        ? 'You’re in.'
                        : 'Welcome, $firstName.',
                    textAlign: TextAlign.center,
                    style: CaliMindTypography.h1.copyWith(
                      color: CaliMindColors.foreground,
                      fontSize: 31,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Your space is ready. Let’s make today feel a little more manageable.',
                    textAlign: TextAlign.center,
                    style: CaliMindTypography.bodyMedium.copyWith(
                      color: CaliMindColors.mutedForeground,
                      height: 1.55,
                    ),
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton.icon(
                      onPressed: () => context.go('/dashboard'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: CaliMindColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      icon: const Icon(
                        LucideIcons.arrowRight,
                        color: Colors.white,
                        size: 18,
                      ),
                      label: const Text(
                        'Open my planner',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Your plans stay yours. You’re always in control.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: CaliMindColors.mutedForeground,
                      fontSize: 12,
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
