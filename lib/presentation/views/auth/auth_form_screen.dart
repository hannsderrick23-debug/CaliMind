import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:calimind/core/constants/app_colors.dart';
import 'package:calimind/core/constants/app_typography.dart';
import 'package:calimind/core/services/biometric_service.dart';
import 'package:calimind/core/utils/app_feedback.dart';
import 'package:calimind/presentation/state/auth_provider.dart';
import 'package:calimind/presentation/widgets/auth_backdrop.dart';
import 'package:calimind/presentation/widgets/calimind_mark.dart';
import 'package:calimind/presentation/widgets/oauth_buttons.dart';

class AuthFormScreen extends ConsumerStatefulWidget {
  final bool isRegister;

  const AuthFormScreen({super.key, required this.isRegister});

  @override
  ConsumerState<AuthFormScreen> createState() => _AuthFormScreenState();
}

class _AuthFormScreenState extends ConsumerState<AuthFormScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _biometricEnabled = false;
  bool _biometricAvailable = false;
  String? _rememberedName;
  final _biometrics = BiometricService();

  @override
  void initState() {
    super.initState();
    if (!widget.isRegister) {
      _loadBiometricSetting();
      _loadRememberedName();
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _loadBiometricSetting() async {
    try {
      final available = await _biometrics.isBiometricsAvailable();
      final enabled = available && await _biometrics.isEnabled();
      if (mounted) {
        setState(() {
          _biometricAvailable = available;
          _biometricEnabled = enabled;
        });
      }
    } catch (error) {
      debugPrint('Could not load biometric sign-in setting: $error');
    }
  }

  Future<void> _loadRememberedName() async {
    try {
      final name = await _biometrics.lastDisplayName();
      if (mounted && name != null) {
        setState(() => _rememberedName = name);
      }
    } catch (error) {
      debugPrint('Could not load the remembered display name: $error');
    }
  }

  Future<void> _unlockWithBiometrics() async {
    if (!_biometricAvailable) {
      AppFeedback.info(
        ScaffoldMessenger.of(context),
        'Set up a fingerprint or face unlock on this device first.',
      );
      return;
    }
    if (!_biometricEnabled) {
      AppFeedback.info(
        ScaffoldMessenger.of(context),
        'Sign in with your password, then enable biometric sign-in in Settings.',
      );
      return;
    }
    final success = await ref.read(authProvider.notifier).biometricSignIn();
    if (!mounted || success) return;
    final message = ref.read(authProvider).errorMessage ??
        'Biometric sign-in did not work. Use your password instead.';
    AppFeedback.error(ScaffoldMessenger.of(context), message);
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (!email.contains('@')) {
      _showMessage('Enter a valid email address.');
      return;
    }
    if (password.length < 8) {
      _showMessage('Your password must be at least 8 characters.');
      return;
    }
    if (widget.isRegister && password != _confirmPasswordController.text) {
      _showMessage('Your passwords do not match.');
      return;
    }

    final notifier = ref.read(authProvider.notifier);
    if (widget.isRegister) {
      await notifier.signUp(email, password);
      final auth = ref.read(authProvider);
      if (mounted && auth.errorMessage != null) {
        AppFeedback.error(
          ScaffoldMessenger.of(context),
          auth.errorMessage!,
        );
      } else if (mounted && auth.successMessage != null) {
        AppFeedback.success(
          ScaffoldMessenger.of(context),
          auth.successMessage!,
        );
      }
    } else {
      await notifier.signIn(email, password);
      if (mounted && ref.read(authProvider).biometricSetupPending) {
        await _offerBiometricSetup();
      } else if (mounted && ref.read(authProvider).errorMessage != null) {
        AppFeedback.error(
          ScaffoldMessenger.of(context),
          ref.read(authProvider).errorMessage!,
        );
      } else if (mounted &&
          ref.read(authProvider).status == AuthStatus.authenticated) {
        AppFeedback.success(
          ScaffoldMessenger.of(context),
          'You’re signed in.',
        );
      }
    }
  }

  Future<void> _offerBiometricSetup() async {
    final wantsSetup = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(
          LucideIcons.fingerprint,
          color: CaliMindColors.primary,
          size: 32,
        ),
        title: const Text('Use your fingerprint next time?'),
        content: const Text(
          'CaliMind can save your sign-in details in this device’s secure storage and use biometrics to sign in. Your credentials stay on this device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Not now'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.pop(dialogContext, true),
            icon: const Icon(LucideIcons.fingerprint, size: 18),
            label: const Text('Set up'),
          ),
        ],
      ),
    );
    if (!mounted) return;

    if (wantsSetup != true) {
      await ref.read(authProvider.notifier).finishBiometricSetup(enable: false);
      if (!mounted) return;
      AppFeedback.success(
        ScaffoldMessenger.of(context),
        'You’re signed in.',
      );
      return;
    }

    final verified = await _biometrics.authenticate(
      localizedReason: 'Confirm your fingerprint to enable CaliMind sign-in',
    );
    if (!mounted) return;
    if (!verified) {
      await ref.read(authProvider.notifier).finishBiometricSetup(enable: false);
      if (!mounted) return;
      AppFeedback.info(
        ScaffoldMessenger.of(context),
        'Biometric setup was skipped. You can enable it later in Settings.',
      );
      return;
    }

    await ref.read(authProvider.notifier).finishBiometricSetup(enable: true);
    if (!mounted) return;
    final error = ref.read(authProvider).errorMessage;
    if (error != null) {
      AppFeedback.error(ScaffoldMessenger.of(context), error);
    } else {
      AppFeedback.success(
        ScaffoldMessenger.of(context),
        'Fingerprint sign-in is ready on this device.',
      );
    }
  }

  void _showMessage(String message) {
    AppFeedback.error(ScaffoldMessenger.of(context), message);
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final rememberedFirstName =
        _rememberedName?.trim().split(RegExp(r'\s+')).first;
    final title = widget.isRegister
        ? 'Create your account'
        : rememberedFirstName == null || rememberedFirstName.isEmpty
            ? 'Welcome back'
            : 'Welcome back, $rememberedFirstName';
    final formContent = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: CaliMindTypography.h2.copyWith(
            fontSize: 26,
            color: Colors.white,
            shadows: const [
              Shadow(color: Color(0xCC101639), blurRadius: 10),
            ],
          ),
        ),
        const SizedBox(height: 7),
        Text(
          widget.isRegister
              ? 'A clearer day starts with one small step.'
              : 'Sign in to pick up where your mind left off.',
          style: CaliMindTypography.bodySmall.copyWith(
            color: Colors.white.withValues(alpha: 0.88),
            height: 1.45,
            shadows: const [
              Shadow(color: Color(0xCC101639), blurRadius: 8),
            ],
          ),
        ),
        const SizedBox(height: 23),
        _AuthField(
          controller: _emailController,
          label: 'Email address',
          hint: 'you@example.com',
          icon: LucideIcons.mail,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
        ),
        const SizedBox(height: 15),
        _AuthField(
          controller: _passwordController,
          label: 'Password',
          hint: 'At least 8 characters',
          icon: LucideIcons.lockKeyhole,
          obscureText: _obscurePassword,
          autofillHints: [
            widget.isRegister
                ? AutofillHints.newPassword
                : AutofillHints.password,
          ],
          suffixIcon: IconButton(
            onPressed: () =>
                setState(() => _obscurePassword = !_obscurePassword),
            icon: Icon(
              _obscurePassword ? LucideIcons.eyeOff : LucideIcons.eye,
              size: 18,
              color: CaliMindColors.mutedForeground,
            ),
          ),
        ),
        if (widget.isRegister) ...[
          const SizedBox(height: 15),
          _AuthField(
            controller: _confirmPasswordController,
            label: 'Confirm password',
            hint: 'Enter your password again',
            icon: LucideIcons.shieldCheck,
            obscureText: _obscureConfirmPassword,
            autofillHints: const [AutofillHints.newPassword],
            suffixIcon: IconButton(
              onPressed: () => setState(
                () => _obscureConfirmPassword = !_obscureConfirmPassword,
              ),
              icon: Icon(
                _obscureConfirmPassword ? LucideIcons.eyeOff : LucideIcons.eye,
                size: 18,
                color: CaliMindColors.mutedForeground,
              ),
            ),
          ),
        ],
        if (!widget.isRegister) ...[
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => context.push('/forgot-password'),
              child: Text(
                'Forgot password?',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ),
        ] else
          const SizedBox(height: 12),
        if (auth.errorMessage != null)
          _StatusMessage(message: auth.errorMessage!, isError: true),
        if (auth.successMessage != null)
          _StatusMessage(message: auth.successMessage!),
        if (auth.errorMessage != null || auth.successMessage != null)
          const SizedBox(height: 12),
        _PrimaryAuthButton(
          isLoading: auth.isLoading,
          label: widget.isRegister ? 'Create account' : 'Sign in',
          onPressed: _submit,
        ),
        if (!widget.isRegister) ...[
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: auth.isLoading ? null : _unlockWithBiometrics,
            icon: const Icon(LucideIcons.fingerprint),
            label: const Text('Sign in with biometrics'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
              foregroundColor: Colors.white,
              side: BorderSide(
                color: Colors.white.withValues(alpha: 0.7),
              ),
              backgroundColor: Colors.white.withValues(alpha: 0.12),
            ),
          ),
        ],
        const SizedBox(height: 20),
        OAuthButtons(isLoading: auth.isLoading, photoStyle: true),
        const SizedBox(height: 17),
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              widget.isRegister
                  ? 'Already have an account?'
                  : 'New to CaliMind?',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                shadows: const [
                  Shadow(color: Color(0xCC101639), blurRadius: 8),
                ],
              ),
            ),
            TextButton(
              onPressed: () => context.go(
                widget.isRegister ? '/login' : '/register',
              ),
              child: Text(
                widget.isRegister ? 'Sign in' : 'Create account',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ],
    );

    return AuthBackdrop(
      backgroundAsset: widget.isRegister
          ? 'assets/branding/register_photo.jpg'
          : 'assets/branding/welcome_photo.jpg',
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 14, 22, 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    tooltip: 'Back',
                    onPressed: () => context.go('/welcome'),
                    icon: Icon(
                      LucideIcons.arrowLeft,
                      color: Colors.white,
                    ),
                    style: IconButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: Colors.white.withValues(alpha: 0.14),
                      side: BorderSide(
                        color: Colors.white.withValues(alpha: 0.48),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const CaliMindMark(size: 56),
                const SizedBox(height: 10),
                Text(
                  'CaliMind',
                  style: CaliMindTypography.h2.copyWith(
                    color: Colors.white,
                    fontSize: 25,
                    shadows: const [
                      Shadow(color: Color(0xCC101639), blurRadius: 8),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 0, 4, 0),
                  child: formContent,
                ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.08),
                const SizedBox(height: 18),
                Text(
                  'A little more clarity, one day at a time.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.82),
                    fontSize: 12,
                    shadows: const [
                      Shadow(color: Color(0xCC101639), blurRadius: 8),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AuthField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Iterable<String>? autofillHints;
  final Widget? suffixIcon;

  const _AuthField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    this.keyboardType,
    this.obscureText = false,
    this.autofillHints,
    this.suffixIcon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 7, left: 2),
          child: Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              shadows: const [
                Shadow(color: Color(0xCC101639), blurRadius: 8),
              ],
            ),
          ),
        ),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscureText,
          autofillHints: autofillHints,
          style: const TextStyle(color: CaliMindColors.foreground),
          decoration: InputDecoration(
            prefixIcon:
                Icon(icon, size: 18, color: CaliMindColors.mutedForeground),
            suffixIcon: suffixIcon,
            hintText: hint,
            hintStyle: const TextStyle(color: CaliMindColors.mutedForeground),
            filled: true,
            fillColor: const Color(0xEFFFFFFF),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 16,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: const BorderSide(color: CaliMindColors.cardBorder),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: const BorderSide(color: CaliMindColors.cardBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide:
                  const BorderSide(color: CaliMindColors.primary, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}

class _PrimaryAuthButton extends StatelessWidget {
  final bool isLoading;
  final String label;
  final VoidCallback onPressed;

  const _PrimaryAuthButton({
    required this.isLoading,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: isLoading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        minimumSize: const Size.fromHeight(54),
        backgroundColor: CaliMindColors.primary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      ),
      child: isLoading
          ? const SizedBox(
              width: 21,
              height: 21,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            )
          : Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
    );
  }
}

class _StatusMessage extends StatelessWidget {
  final String message;
  final bool isError;

  const _StatusMessage({required this.message, this.isError = false});

  @override
  Widget build(BuildContext context) {
    final color = isError ? CaliMindColors.destructive : CaliMindColors.success;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Text(
        message,
        style: TextStyle(color: CaliMindColors.foreground),
      ),
    );
  }
}
