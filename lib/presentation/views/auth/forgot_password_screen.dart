import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:calimind/core/constants/app_colors.dart';
import 'package:calimind/core/constants/app_typography.dart';
import 'package:calimind/presentation/state/auth_provider.dart';
import 'package:calimind/presentation/widgets/auth_backdrop.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _emailController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendResetLink() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid email address.')),
      );
      return;
    }
    await ref.read(authProvider.notifier).sendPasswordReset(email);
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    ref.listen(authProvider, (previous, next) {
      if (next.successMessage != null &&
          previous?.successMessage != next.successMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.successMessage!)),
        );
        context.go('/login');
      }
    });

    return AuthBackdrop(
      backgroundAsset: 'assets/branding/welcome_photo.jpg',
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(left: 10, top: 4),
              child: IconButton(
                onPressed: () => context.go('/login'),
                icon: const Icon(
                  LucideIcons.arrowLeft,
                  color: Colors.white,
                ),
                tooltip: 'Back to sign in',
                style: IconButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: Colors.white.withValues(alpha: 0.14),
                  side: BorderSide(
                    color: Colors.white.withValues(alpha: 0.48),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(26, 12, 26, 30),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.16),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.44),
                          ),
                        ),
                        child: const Icon(
                          LucideIcons.lockKeyhole,
                          color: Colors.white,
                          size: 27,
                        ),
                      ),
                      const SizedBox(height: 22),
                      Text(
                        'Forgot your password?',
                        style: CaliMindTypography.h1.copyWith(
                          color: Colors.white,
                          fontSize: 28,
                          shadows: const [
                            Shadow(color: Color(0xCC101639), blurRadius: 10),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Enter your account email and we’ll send you a secure password reset link.',
                        style: CaliMindTypography.bodyMedium.copyWith(
                          color: Colors.white.withValues(alpha: 0.9),
                          height: 1.5,
                          shadows: const [
                            Shadow(color: Color(0xCC101639), blurRadius: 8),
                          ],
                        ),
                      ),
                      const SizedBox(height: 28),
                      TextField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        style: const TextStyle(
                          color: CaliMindColors.foreground,
                        ),
                        decoration: const InputDecoration(
                          prefixIcon: Icon(LucideIcons.mail),
                          hintText: 'Email address',
                        ),
                      ),
                      if (auth.errorMessage != null) ...[
                        const SizedBox(height: 16),
                        Text(
                          auth.errorMessage!,
                          style: CaliMindTypography.bodySmall.copyWith(
                            color: Colors.white,
                            shadows: const [
                              Shadow(
                                color: Color(0xCC101639),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: auth.isLoading ? null : _sendResetLink,
                          child: auth.isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Send reset link'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
