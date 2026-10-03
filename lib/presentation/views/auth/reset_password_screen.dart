import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:calimind/core/constants/app_colors.dart';
import 'package:calimind/core/constants/app_typography.dart';
import 'package:calimind/presentation/state/auth_provider.dart';

class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  ConsumerState<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _updatePassword() async {
    if (_passwordController.text.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password must be at least 8 characters.')),
      );
      return;
    }
    if (_passwordController.text != _confirmController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('The passwords do not match.')),
      );
      return;
    }
    await ref.read(authProvider.notifier).updatePassword(_passwordController.text);
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    return Scaffold(
      backgroundColor: CaliMindColors.background,
      appBar: AppBar(title: const Text('Choose a new password')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Secure your account', style: CaliMindTypography.h1.copyWith(fontSize: 26)),
              const SizedBox(height: 20),
              TextField(
                controller: _passwordController,
                obscureText: true,
                autofillHints: const [AutofillHints.newPassword],
                decoration: const InputDecoration(hintText: 'New password'),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _confirmController,
                obscureText: true,
                decoration: const InputDecoration(hintText: 'Confirm new password'),
              ),
              if (auth.errorMessage != null) ...[
                const SizedBox(height: 16),
                Text(auth.errorMessage!, style: CaliMindTypography.bodySmall.copyWith(color: CaliMindColors.destructive)),
              ],
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: auth.isLoading ? null : _updatePassword,
                  child: auth.isLoading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Update password'),
                ),
              ),
              TextButton(
                onPressed: () => context.go('/login'),
                child: Text('Back to sign in', style: CaliMindTypography.bodySmall),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
