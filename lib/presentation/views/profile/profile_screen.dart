import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:calimind/core/constants/app_colors.dart';
import 'package:calimind/core/constants/app_typography.dart';
import 'package:calimind/core/utils/app_feedback.dart';
import 'package:calimind/presentation/state/auth_provider.dart';
import 'package:calimind/presentation/state/task_provider.dart';
import 'package:calimind/presentation/widgets/weekly_progress_widget.dart';
import 'package:calimind/presentation/widgets/star_loading_indicator.dart';
import 'package:calimind/domain/models/task.dart';

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
      AppFeedback.error(
        ScaffoldMessenger.of(context),
        'Enter your name before saving.',
      );
      return;
    }
    await ref.read(authProvider.notifier).updateDisplayName(name);
    if (!mounted) return;
    final updatedAuth = ref.read(authProvider);
    if (updatedAuth.successMessage != null) {
      AppFeedback.success(
        ScaffoldMessenger.of(context),
        updatedAuth.successMessage!,
      );
    } else if (updatedAuth.errorMessage != null) {
      AppFeedback.error(
        ScaffoldMessenger.of(context),
        updatedAuth.errorMessage!,
      );
    }
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
    final messenger = ScaffoldMessenger.of(context);
    final signedOut = await ref.read(authProvider.notifier).signOut();
    if (!signedOut) {
      if (mounted) {
        AppFeedback.error(
          ScaffoldMessenger.of(context),
          ref.read(authProvider).errorMessage ?? 'Could not sign out.',
        );
      }
      return;
    }
    AppFeedback.success(messenger, 'Signed out.');
    if (mounted) context.go('/welcome');
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final tasksAsync = ref.watch(taskProvider);
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
            const SizedBox(height: 20),
            tasksAsync.when(
              loading: () => const Center(
                child: const StarLoadingIndicator(size: 24),
              ),
              error: (error, _) => Text(
                'Activity is unavailable: ${taskOperationErrorMessage(error)}',
                style: CaliMindTypography.bodySmall.copyWith(
                  color: CaliMindColors.mutedForeground,
                ),
              ),
              data: (tasks) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Activity & progress',
                    style: CaliMindTypography.h3.copyWith(fontSize: 16),
                  ),
                  const SizedBox(height: 10),
                  _ProfileActivityCard(tasks: tasks),
                  const SizedBox(height: 12),
                  WeeklyProgressWidget(tasks: tasks),
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
                      child: const StarLoadingIndicator(
                        size: 18,
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

class _ProfileActivityCard extends StatelessWidget {
  const _ProfileActivityCard({required this.tasks});

  final List<Task> tasks;

  @override
  Widget build(BuildContext context) {
    final completed = tasks.where((task) => task.completed).length;
    final active = tasks.length - completed;
    final recent = tasks.where((task) => task.completedAt != null).toList()
      ..sort((a, b) => b.completedAt!.compareTo(a.completedAt!));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: CaliMindColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: CaliMindColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: _ActivityMetric(label: 'Active', value: active)),
              Expanded(
                child: _ActivityMetric(label: 'Completed', value: completed),
              ),
              Expanded(child: _ActivityMetric(label: 'Total', value: tasks.length)),
            ],
          ),
          if (recent.isNotEmpty) ...[
            const SizedBox(height: 18),
            Text(
              'Recently completed',
              style: CaliMindTypography.label.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            for (final task in recent.take(3))
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  children: [
                    const Icon(
                      LucideIcons.circleCheck,
                      size: 15,
                      color: CaliMindColors.success,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        task.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: CaliMindTypography.bodySmall,
                      ),
                    ),
                    Text(
                      DateFormat('MMM d').format(task.completedAt!.toLocal()),
                      style: CaliMindTypography.bodySmall.copyWith(
                        color: CaliMindColors.mutedForeground,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _ActivityMetric extends StatelessWidget {
  const _ActivityMetric({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$value',
            style: CaliMindTypography.h2.copyWith(
              color: CaliMindColors.primary,
            ),
          ),
          Text(
            label,
            style: CaliMindTypography.bodySmall.copyWith(
              color: CaliMindColors.mutedForeground,
            ),
          ),
        ],
      );
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
