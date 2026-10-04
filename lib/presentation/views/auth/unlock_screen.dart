import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:calimind/core/constants/app_colors.dart';
import 'package:calimind/core/constants/app_typography.dart';
import 'package:calimind/presentation/state/auth_provider.dart';
import 'package:calimind/presentation/widgets/auth_backdrop.dart';
import 'package:calimind/presentation/widgets/calimind_mark.dart';

class UnlockScreen extends ConsumerStatefulWidget {
  const UnlockScreen({super.key});

  @override
  ConsumerState<UnlockScreen> createState() => _UnlockScreenState();
}

class _UnlockScreenState extends ConsumerState<UnlockScreen> {
  bool _isAuthenticating = false;
  String? _error;

  Future<void> _unlock() async {
    setState(() {
      _isAuthenticating = true;
      _error = null;
    });
    final success = await ref.read(authProvider.notifier).biometricUnlock();
    if (!mounted) return;
    setState(() => _isAuthenticating = false);
    if (success) {
      context.go('/home');
    } else {
      setState(() {
        _error = 'Biometric verification did not complete. Try again or sign in.';
      });
    }
  }

  Future<void> _usePassword() async {
    final signedOut = await ref.read(authProvider.notifier).signOut();
    if (!mounted) return;
    if (signedOut) {
      context.go('/login');
    } else {
      setState(() {
        _error = ref.read(authProvider).errorMessage ??
            'Could not sign out. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthBackdrop(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: GlassPanel(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CaliMindMark(size: 76),
                  const SizedBox(height: 24),
                  Text(
                    'Welcome back',
                    style: CaliMindTypography.h1.copyWith(
                      color: CaliMindColors.foreground,
                      fontSize: 30,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Verify it’s you to unlock your private planner.',
                    textAlign: TextAlign.center,
                    style: CaliMindTypography.bodyMedium.copyWith(
                      color: CaliMindColors.mutedForeground,
                    ),
                  ),
                  const SizedBox(height: 26),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _isAuthenticating ? null : _unlock,
                      icon: _isAuthenticating
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: CaliMindColors.primary,
                              ),
                            )
                          : const Icon(LucideIcons.fingerprint),
                      label: const Text('Unlock with biometrics'),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 14),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _isAuthenticating ? null : _usePassword,
                    child: const Text('Sign in with password instead'),
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
