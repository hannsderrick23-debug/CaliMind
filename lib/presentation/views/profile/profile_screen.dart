import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:calimind/core/constants/app_colors.dart';
import 'package:calimind/core/constants/app_typography.dart';
import 'package:calimind/presentation/state/auth_provider.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _nameController = TextEditingController();
  String? _loadedUserId;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter your name before saving.')),
      );
      return;
    }
    await ref.read(authProvider.notifier).updateDisplayName(name);
  }

  Future<void> _signOut() async {
    final shouldSignOut = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text('You can sign back in at any time.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (shouldSignOut != true || !mounted) return;
    await ref.read(authProvider.notifier).signOut();
    if (mounted) context.go('/welcome');
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final user = auth.user;
    final metadataName = user?.userMetadata?['full_name'] as String? ??
        user?.userMetadata?['name'] as String?;
    final name = metadataName?.trim() ?? '';
    if (user != null && _loadedUserId != user.id) {
      _loadedUserId = user.id;
      _nameController.text = name;
    }

    return Scaffold(
      backgroundColor: CaliMindColors.background,
      appBar: AppBar(
        title: const Text('Profile'),
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () => context.pop(),
          icon: const Icon(LucideIcons.arrowLeft),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: CaliMindColors.card,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: CaliMindColors.cardBorder),
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 38,
                    backgroundColor:
                        CaliMindColors.primary.withValues(alpha: 0.12),
                    child: Text(
                      _initials(name, user?.email),
                      style: CaliMindTypography.h2.copyWith(
                        color: CaliMindColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    name.isEmpty ? 'Your profile' : name,
                    style: CaliMindTypography.h2,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user?.email ?? '',
                    style: CaliMindTypography.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            Text(
              'Personal information',
              style: CaliMindTypography.h3.copyWith(fontSize: 16),
            ),
            const SizedBox(height: 12),
            Text(
              'Display name',
              style: CaliMindTypography.label.copyWith(
                color: CaliMindColors.foreground,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                prefixIcon: Icon(LucideIcons.userRound),
                hintText: 'Your name',
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Email address',
              style: CaliMindTypography.label.copyWith(
                color: CaliMindColors.foreground,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            InputDecorator(
              decoration: const InputDecoration(
                prefixIcon: Icon(LucideIcons.mail),
                helperText: 'Email is managed by your sign-in provider.',
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  user?.email ?? '',
                  style: CaliMindTypography.bodyMedium.copyWith(
                    color: CaliMindColors.mutedForeground,
                  ),
                ),
              ),
            ),
            if (auth.errorMessage != null) ...[
              const SizedBox(height: 14),
              _ProfileMessage(
                text: auth.errorMessage!,
                color: CaliMindColors.destructive,
              ),
            ],
            if (auth.successMessage != null) ...[
              const SizedBox(height: 14),
              _ProfileMessage(
                text: auth.successMessage!,
                color: CaliMindColors.success,
              ),
            ],
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: auth.isLoading ? null : _saveProfile,
              icon: auth.isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(LucideIcons.check),
              label: const Text('Save profile'),
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: auth.isLoading ? null : _signOut,
              icon: const Icon(LucideIcons.logOut),
              label: const Text('Sign out'),
              style: OutlinedButton.styleFrom(
                foregroundColor: CaliMindColors.destructive,
                side: const BorderSide(color: CaliMindColors.cardBorder),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _initials(String name, String? email) {
    final parts = name.split(RegExp(r'\s+')).where((part) => part.isNotEmpty);
    if (parts.isNotEmpty) {
      return parts.take(2).map((part) => part[0].toUpperCase()).join();
    }
    return email == null || email.isEmpty ? 'C' : email[0].toUpperCase();
  }
}

class _ProfileMessage extends StatelessWidget {
  final String text;
  final Color color;

  const _ProfileMessage({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Text(
        text,
        style: CaliMindTypography.bodySmall.copyWith(
          color: CaliMindColors.foreground,
        ),
      ),
    );
  }
}
