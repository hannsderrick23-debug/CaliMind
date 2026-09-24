import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_typography.dart';
import '../state/auth_provider.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;
    if (email.isEmpty || password.isEmpty) return;

    final isSignIn = _tabController.index == 0;
    if (isSignIn) {
      await ref.read(authProvider.notifier).signIn(email, password);
    } else {
      await ref.read(authProvider.notifier).signUp(email, password);
    }
  }

  void _continueAsDemo() {
    ref.read(authProvider.notifier).signInAsMockUser();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: CaliMindColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 20),
              // Logo
              _buildLogo().animate().fadeIn(duration: 600.ms).slideY(begin: -0.2),
              const SizedBox(height: 48),
              // Tab Bar
              _buildTabBar(),
              const SizedBox(height: 32),
              // Form
              _buildForm(auth),
              const SizedBox(height: 24),
              // Error
              if (auth.errorMessage != null)
                _buildErrorMessage(auth.errorMessage!),
              const SizedBox(height: 32),
              // Submit Button
              _buildSubmitButton(auth),
              const SizedBox(height: 20),
              // Demo separator
              _buildDemoSeparator(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            gradient: CaliMindColors.mindGradient,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: CaliMindColors.primary.withOpacity(0.4),
                blurRadius: 24,
                spreadRadius: 2,
              ),
            ],
          ),
          child: const Icon(LucideIcons.brain, color: Colors.white, size: 36),
        ),
        const SizedBox(height: 16),
        Text('CaliMind', style: CaliMindTypography.h1.copyWith(fontSize: 32)),
        const SizedBox(height: 6),
        Text(
          'Voice-first daily task planner',
          style: CaliMindTypography.label,
        ),
      ],
    );
  }

  Widget _buildTabBar() {
    return Container(
      decoration: BoxDecoration(
        color: CaliMindColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: CaliMindColors.cardBorder),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          gradient: CaliMindColors.mindGradient,
          borderRadius: BorderRadius.circular(10),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        labelStyle: CaliMindTypography.bodyMedium.copyWith(fontWeight: FontWeight.w600),
        unselectedLabelStyle: CaliMindTypography.bodyMedium,
        labelColor: Colors.white,
        unselectedLabelColor: CaliMindColors.mutedForeground,
        dividerColor: Colors.transparent,
        tabs: const [
          Tab(text: 'Sign In', height: 44),
          Tab(text: 'Create Account', height: 44),
        ],
      ),
    );
  }

  Widget _buildForm(AuthState auth) {
    return Column(
      children: [
        _buildTextField(
          controller: _emailCtrl,
          hint: 'Email address',
          icon: LucideIcons.mail,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _passwordCtrl,
          hint: 'Password',
          icon: LucideIcons.lock,
          obscureText: _obscurePassword,
          suffixIcon: IconButton(
            icon: Icon(
              _obscurePassword ? LucideIcons.eyeOff : LucideIcons.eye,
              color: CaliMindColors.mutedForeground,
              size: 18,
            ),
            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
          ),
        ),
      ],
    ).animate().fadeIn(delay: 200.ms, duration: 500.ms).slideY(begin: 0.1);
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffixIcon,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: CaliMindColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: CaliMindColors.cardBorder),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        style: CaliMindTypography.bodyMedium,
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: CaliMindColors.mutedForeground, size: 18),
          hintText: hint,
          hintStyle: CaliMindTypography.bodyMedium.copyWith(color: CaliMindColors.mutedForeground),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          suffixIcon: suffixIcon,
        ),
      ),
    );
  }

  Widget _buildErrorMessage(String message) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: CaliMindColors.destructive.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: CaliMindColors.destructive.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(LucideIcons.alertCircle, color: CaliMindColors.destructive, size: 16),
          const SizedBox(width: 10),
          Expanded(child: Text(message, style: CaliMindTypography.bodySmall.copyWith(color: CaliMindColors.destructive))),
        ],
      ),
    ).animate().shake();
  }

  Widget _buildSubmitButton(AuthState auth) {
    final isSignIn = _tabController.index == 0;
    final label = isSignIn ? 'Sign In' : 'Create Account';

    return SizedBox(
      width: double.infinity,
      height: 52,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: CaliMindColors.mindGradient,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: CaliMindColors.primary.withOpacity(0.3),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: auth.isLoading ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: auth.isLoading
              ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
              : Text(label, style: CaliMindTypography.bodyLarge.copyWith(fontWeight: FontWeight.w600, color: Colors.white)),
        ),
      ),
    );
  }

  Widget _buildDemoSeparator() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: Divider(color: CaliMindColors.cardBorder, thickness: 1)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Text('or', style: CaliMindTypography.label),
            ),
            Expanded(child: Divider(color: CaliMindColors.cardBorder, thickness: 1)),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton(
            onPressed: _continueAsDemo,
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: CaliMindColors.primary.withOpacity(0.5)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: Text(
              'Continue with Demo Account',
              style: CaliMindTypography.bodyMedium.copyWith(color: CaliMindColors.primary, fontWeight: FontWeight.w500),
            ),
          ),
        ),
      ],
    ).animate().fadeIn(delay: 400.ms);
  }
}
