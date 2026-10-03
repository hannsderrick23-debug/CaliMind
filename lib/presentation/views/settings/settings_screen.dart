import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:calimind/core/constants/app_colors.dart';
import 'package:calimind/core/constants/app_typography.dart';
import 'package:calimind/core/services/biometric_service.dart';
import 'package:calimind/core/utils/app_feedback.dart';
import 'package:calimind/data/datasources/audit_remote_datasource.dart';
import 'package:calimind/domain/models/audit_log.dart';
import 'package:calimind/presentation/state/auth_provider.dart';
import 'package:calimind/presentation/state/profile_provider.dart';
import 'package:calimind/presentation/state/voice_assistant_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _auditDatasource = AuditRemoteDatasourceImpl();
  List<AuditLog>? _auditLogs;
  bool _isTestingVoiceService = false;
  bool _biometricEnabled = false;
  bool _isChangingBiometric = false;
  final _biometrics = BiometricService();

  @override
  void initState() {
    super.initState();
    _loadBiometricSetting();
  }

  Future<void> _loadBiometricSetting() async {
    final enabled = await _biometrics.isEnabled() &&
        await _biometrics.isBiometricsAvailable();
    if (mounted) setState(() => _biometricEnabled = enabled);
  }

  Future<void> _setBiometricEnabled(bool enabled) async {
    setState(() => _isChangingBiometric = true);
    try {
      if (!enabled) {
        await _biometrics.clearLoginCredentials();
      } else {
        if (!await _biometrics.isBiometricsAvailable()) {
          _showFeedback(
            'Set up Face ID or a fingerprint on this device first.',
            isError: true,
          );
          return;
        }

        final email = ref.read(authProvider).user?.email;
        if (email == null || email.isEmpty) {
          _showFeedback('Sign in with an email and password to set this up.',
              isError: true);
          return;
        }
        final password = await _requestPassword();
        if (password == null || !mounted) return;

        final passwordVerified = await ref
            .read(authProvider.notifier)
            .verifyPasswordForBiometricSetup(email, password);
        if (!passwordVerified) {
          _showFeedback('That password could not be verified. Try again.',
              isError: true);
          return;
        }

        final verified = await _biometrics.authenticate(
          localizedReason:
              'Confirm your identity to enable fingerprint sign-in',
        );
        if (!verified) {
          _showFeedback('Biometric verification was not completed.',
              isError: true);
          return;
        }
        await _biometrics.saveLoginCredentials(email, password);
      }

      if (mounted) {
        setState(() => _biometricEnabled = enabled);
        _showFeedback(
          enabled
              ? 'Fingerprint sign-in is enabled on this device.'
              : 'Fingerprint sign-in is disabled and saved credentials were removed.',
        );
      }
    } catch (error) {
      debugPrint('Could not update biometric sign-in: $error');
      if (mounted) {
        _showFeedback('Could not update biometric sign-in. Please try again.',
            isError: true);
      }
    } finally {
      if (mounted) setState(() => _isChangingBiometric = false);
    }
  }

  Future<String?> _requestPassword() async {
    final controller = TextEditingController();
    try {
      return await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Confirm your password'),
          content: TextField(
            controller: controller,
            autofocus: true,
            obscureText: true,
            textInputAction: TextInputAction.done,
            onSubmitted: (value) => Navigator.pop(dialogContext, value),
            decoration: const InputDecoration(
              labelText: 'Account password',
              prefixIcon: Icon(LucideIcons.lockKeyhole),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, controller.text),
              child: const Text('Continue'),
            ),
          ],
        ),
      );
    } finally {
      controller.dispose();
    }
  }

  void _showFeedback(String message, {bool isError = false}) {
    final messenger = ScaffoldMessenger.of(context);
    if (isError) {
      AppFeedback.error(messenger, message);
    } else {
      AppFeedback.success(messenger, message);
    }
  }

  Future<void> _loadAuditLogs() async {
    final logs = await _auditDatasource.fetchAuditLogs(limit: 20);
    if (mounted) {
      setState(() => _auditLogs = logs);
    }
  }

  Future<void> _testVoiceAssistant() async {
    setState(() => _isTestingVoiceService = true);
    final voiceService = ref.read(aventorVoiceServiceProvider);

    final result = await voiceService.parseVoiceCommandWithAI(
      'schedule a 30 minute study calculus session tomorrow morning',
    );

    if (mounted) {
      setState(() => _isTestingVoiceService = false);
      final success = result != null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor:
              success ? CaliMindColors.success : CaliMindColors.destructive,
          content: Row(
            children: [
              Icon(
                success ? LucideIcons.checkCircle2 : LucideIcons.alertCircle,
                color: Colors.white,
                size: 18,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  success
                      ? 'Aventor Voice is ready.'
                      : 'Aventor Voice could not complete the test. Please try again.',
                  style: CaliMindTypography.bodySmall
                      .copyWith(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(profileProvider);
    final auth = ref.watch(authProvider);
    final profileName = auth.user?.userMetadata?['full_name'] as String? ??
        auth.user?.userMetadata?['name'] as String?;
    final profileSubtitle = profileName?.trim().isNotEmpty == true
        ? profileName!.trim()
        : auth.user?.email ?? 'Manage your account details';

    return Scaffold(
      backgroundColor: CaliMindColors.background,
      appBar: AppBar(
        backgroundColor: CaliMindColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft,
              color: CaliMindColors.foreground),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Settings',
            style: CaliMindTypography.h2.copyWith(fontSize: 20)),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
          _SettingsCard(
            children: [
              _SettingsTile(
                icon: LucideIcons.userRound,
                title: 'Profile',
                subtitle: profileSubtitle,
                trailing: const Icon(
                  LucideIcons.chevronRight,
                  size: 16,
                  color: CaliMindColors.mutedForeground,
                ),
                onTap: () => context.push('/profile'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Voice assistant
          const _SectionHeader(
            title: 'Aventor Voice',
            icon: LucideIcons.sparkles,
            color: CaliMindColors.primary,
          ),
          const SizedBox(height: 10),
          _SettingsCard(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: CaliMindColors.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(LucideIcons.mic,
                          color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text('Aventor Voice',
                                  style: CaliMindTypography.bodyMedium
                                      .copyWith(fontWeight: FontWeight.w600)),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Your spoken requests are securely processed into task details.',
                            style: CaliMindTypography.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              _Divider(),
              _SettingsTile(
                icon: LucideIcons.zap,
                title: 'Test Aventor Voice',
                subtitle: _isTestingVoiceService
                    ? 'Testing connection...'
                    : 'Check voice understanding and task structuring',
                trailing: _isTestingVoiceService
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: CaliMindColors.primary,
                        ),
                      )
                    : const Icon(
                        LucideIcons.playCircle,
                        size: 18,
                        color: CaliMindColors.primary,
                      ),
                onTap:
                    _isTestingVoiceService ? null : _testVoiceAssistant,
              ),
            ],
          ),

          const SizedBox(height: 24),
          // Backend & Database (Supabase)
          const _SectionHeader(
            title: 'Security',
            icon: LucideIcons.database,
            color: CaliMindColors.success,
          ),
          const SizedBox(height: 10),
          _SettingsCard(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: CaliMindColors.success.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(LucideIcons.server,
                          color: CaliMindColors.success, size: 20),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text('Account protection',
                                  style: CaliMindTypography.bodyMedium
                                      .copyWith(fontWeight: FontWeight.w600)),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: CaliMindColors.success
                                      .withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'Protected',
                                  style: CaliMindTypography.bodySmall.copyWith(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: CaliMindColors.success,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Your tasks are protected by sign-in and row-level security.',
                            style: CaliMindTypography.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              _Divider(),
              const _SettingsTile(
                icon: LucideIcons.shieldCheck,
                title: 'Row Level Security',
                subtitle: 'All user tasks are cryptographically isolated',
                trailing: Icon(
                  LucideIcons.check,
                  size: 16,
                  color: CaliMindColors.success,
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),
          // Security section
          const _SectionHeader(
            title: 'Security',
            icon: LucideIcons.shieldCheck,
            color: CaliMindColors.primary,
          ),
          const SizedBox(height: 10),
          _SettingsCard(
            children: [
              _SettingsTile(
                icon: LucideIcons.fingerprint,
                title: 'Biometric Unlock',
                subtitle: _biometricEnabled
                    ? 'Sign in with Face ID or fingerprint on this device'
                    : 'Save your password securely for biometric sign-in',
                trailing: _isChangingBiometric
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: CaliMindColors.primary,
                        ),
                      )
                    : Switch(
                        value: _biometricEnabled,
                        onChanged: _setBiometricEnabled,
                        activeThumbColor: CaliMindColors.primary,
                      ),
              ),
              _Divider(),
              _SettingsTile(
                icon: LucideIcons.shield,
                title: 'Two-Factor Authentication',
                subtitle: 'TOTP-based MFA',
                trailing: const Icon(LucideIcons.chevronRight,
                    size: 16, color: CaliMindColors.mutedForeground),
                onTap: () {},
              ),
            ],
          ),

          const SizedBox(height: 24),
          // Privacy section
          const _SectionHeader(
            title: 'Privacy & Retention',
            icon: LucideIcons.lock,
            color: CaliMindColors.catStudy,
          ),
          const SizedBox(height: 10),
          _SettingsCard(
            children: [
              profileAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(
                      color: CaliMindColors.primary, strokeWidth: 2),
                ),
                error: (_, __) => const SizedBox.shrink(),
                data: (profile) => Column(
                  children: [
                    _SettingsTile(
                      icon: LucideIcons.database,
                      title: 'Data Retention Window',
                      subtitle: '${profile.dataRetentionDays} days',
                      trailing: SizedBox(
                        width: 120,
                        child: Slider(
                          value: profile.dataRetentionDays.toDouble(),
                          min: 1,
                          max: 365,
                          divisions: 36,
                          activeColor: CaliMindColors.primary,
                          inactiveColor: CaliMindColors.cardBorder,
                          onChanged: (v) {
                            ref
                                .read(profileProvider.notifier)
                                .updateRetentionDays(v.toInt());
                          },
                        ),
                      ),
                    ),
                    _Divider(),
                    _SettingsTile(
                      icon: LucideIcons.mail,
                      title: 'Email Processing',
                      subtitle: 'Allow syllabus & schedule auto-intake',
                      trailing: Switch(
                        value: profile.allowEmailProcessing,
                        onChanged: (v) => ref
                            .read(profileProvider.notifier)
                            .toggleEmailProcessing(v),
                        activeThumbColor: CaliMindColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),
          // Audit Logs
          const _SectionHeader(
            title: 'Security Audit Trail',
            icon: LucideIcons.fileText,
            color: CaliMindColors.catPersonal,
          ),
          const SizedBox(height: 10),
          _SettingsCard(
            children: [
              _SettingsTile(
                icon: LucideIcons.history,
                title: 'View Immutable Audit Log',
                subtitle: 'Recent sign-ins, deletes, and task modifications',
                trailing: const Icon(LucideIcons.chevronRight,
                    size: 16, color: CaliMindColors.mutedForeground),
                onTap: () async {
                  await _loadAuditLogs();
                  if (mounted && _auditLogs != null) {
                    _showAuditSheet();
                  }
                },
              ),
            ],
          ),

          const SizedBox(height: 24),
          // Sign Out
          GestureDetector(
            onTap: () async {
              await ref.read(authProvider.notifier).signOut();
              if (!context.mounted) return;
              context.go('/login');
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: CaliMindColors.destructive.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: CaliMindColors.destructive.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(LucideIcons.logOut,
                      color: CaliMindColors.destructive, size: 18),
                  const SizedBox(width: 8),
                  Text('Sign Out',
                      style: CaliMindTypography.bodyMedium.copyWith(
                        color: CaliMindColors.destructive,
                        fontWeight: FontWeight.w600,
                      )),
                ],
              ),
            ),
          ).animate().fadeIn(delay: 300.ms),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  void _showAuditSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: CaliMindColors.card,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _AuditLogSheet(logs: _auditLogs ?? []),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;

  const _SectionHeader(
      {required this.title, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 8),
        Text(title,
            style: CaliMindTypography.label
                .copyWith(fontWeight: FontWeight.w700, color: color)),
      ],
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;

  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: CaliMindColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: CaliMindColors.cardBorder),
      ),
      child: Column(children: children),
    ).animate().fadeIn(duration: 400.ms);
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 18, color: CaliMindColors.mutedForeground),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: CaliMindTypography.bodyMedium
                          .copyWith(fontWeight: FontWeight.w500)),
                  Text(subtitle, style: CaliMindTypography.bodySmall),
                ],
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      const Divider(color: CaliMindColors.cardBorder, height: 1, indent: 48);
}

class _AuditLogSheet extends StatelessWidget {
  final List<AuditLog> logs;

  const _AuditLogSheet({required this.logs});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 12),
        Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
                color: CaliMindColors.cardBorder,
                borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              const Icon(LucideIcons.history,
                  size: 18, color: CaliMindColors.primary),
              const SizedBox(width: 10),
              Text('Security Audit Log', style: CaliMindTypography.h3),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Flexible(
          child: logs.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text('No activity recorded yet.',
                      style: CaliMindTypography.label),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  itemCount: logs.length,
                  separatorBuilder: (_, __) => const Divider(
                      color: CaliMindColors.cardBorder, height: 1),
                  itemBuilder: (ctx, i) {
                    final log = logs[i];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color:
                                  CaliMindColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(log.actionType,
                                style: CaliMindTypography.bodySmall.copyWith(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: CaliMindColors.primary,
                                )),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _formatDate(log.createdAt),
                              style: CaliMindTypography.bodySmall,
                            ),
                          ),
                          if (log.ipAddressRedacted != null)
                            Text(log.ipAddressRedacted!,
                                style: CaliMindTypography.bodySmall.copyWith(
                                    color: CaliMindColors.mutedForeground)),
                        ],
                      ),
                    );
                  },
                ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  String _formatDate(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
