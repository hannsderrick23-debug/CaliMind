import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_typography.dart';
import '../../../data/datasources/audit_remote_datasource.dart';
import '../../../domain/models/audit_log.dart';
import '../../state/auth_provider.dart';
import '../../state/profile_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _auditDatasource = AuditRemoteDatasourceImpl();
  List<AuditLog>? _auditLogs;
  bool _loadingLogs = false;

  Future<void> _loadAuditLogs() async {
    setState(() => _loadingLogs = true);
    final logs = await _auditDatasource.fetchAuditLogs(limit: 20);
    setState(() {
      _auditLogs = logs;
      _loadingLogs = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(profileProvider);

    return Scaffold(
      backgroundColor: CaliMindColors.background,
      appBar: AppBar(
        backgroundColor: CaliMindColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, color: CaliMindColors.foreground),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Settings', style: CaliMindTypography.h2.copyWith(fontSize: 20)),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
          // Security section
          _SectionHeader(title: 'Security', icon: LucideIcons.shieldCheck, color: CaliMindColors.primary),
          const SizedBox(height: 10),
          _SettingsCard(
            children: [
              _SettingsTile(
                icon: LucideIcons.fingerprint,
                title: 'Biometric Unlock',
                subtitle: 'Face ID or Fingerprint',
                trailing: Switch(
                  value: true,
                  onChanged: (_) {},
                  activeColor: CaliMindColors.primary,
                ),
              ),
              _Divider(),
              _SettingsTile(
                icon: LucideIcons.shield,
                title: 'Two-Factor Authentication',
                subtitle: 'TOTP-based MFA',
                trailing: const Icon(LucideIcons.chevronRight, size: 16, color: CaliMindColors.mutedForeground),
                onTap: () {},
              ),
            ],
          ),

          const SizedBox(height: 24),
          // Privacy section
          _SectionHeader(title: 'Privacy', icon: LucideIcons.lock, color: CaliMindColors.catStudy),
          const SizedBox(height: 10),
          _SettingsCard(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: CaliMindColors.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: CaliMindColors.primary.withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(LucideIcons.info, size: 14, color: CaliMindColors.primary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'CaliMind does not read inboxes or process email content.',
                          style: CaliMindTypography.bodySmall.copyWith(color: CaliMindColors.primary),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              profileAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(color: CaliMindColors.primary, strokeWidth: 2),
                ),
                error: (_, __) => const SizedBox.shrink(),
                data: (profile) => Column(
                  children: [
                    _SettingsTile(
                      icon: LucideIcons.database,
                      title: 'Data Retention',
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
                            ref.read(profileProvider.notifier).updateRetentionDays(v.toInt());
                          },
                        ),
                      ),
                    ),
                    _Divider(),
                    _SettingsTile(
                      icon: LucideIcons.mail,
                      title: 'Email Processing',
                      subtitle: 'Allow email content analysis',
                      trailing: Switch(
                        value: profile.allowEmailProcessing,
                        onChanged: (v) => ref.read(profileProvider.notifier).toggleEmailProcessing(v),
                        activeColor: CaliMindColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),
          // Audit Logs
          _SectionHeader(title: 'Audit Log', icon: LucideIcons.fileText, color: CaliMindColors.catPersonal),
          const SizedBox(height: 10),
          _SettingsCard(
            children: [
              _SettingsTile(
                icon: LucideIcons.history,
                title: 'View Security Activity',
                subtitle: 'Recent sign-ins and task actions',
                trailing: const Icon(LucideIcons.chevronRight, size: 16, color: CaliMindColors.mutedForeground),
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
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: CaliMindColors.destructive.withOpacity(0.1),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: CaliMindColors.destructive.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(LucideIcons.logOut, color: CaliMindColors.destructive, size: 18),
                  const SizedBox(width: 8),
                  Text('Sign Out', style: CaliMindTypography.bodyMedium.copyWith(
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
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _AuditLogSheet(logs: _auditLogs ?? []),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;

  const _SectionHeader({required this.title, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 8),
        Text(title, style: CaliMindTypography.label.copyWith(fontWeight: FontWeight.w700, color: color)),
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
                  Text(title, style: CaliMindTypography.bodyMedium.copyWith(fontWeight: FontWeight.w500)),
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
        Container(width: 40, height: 4, decoration: BoxDecoration(color: CaliMindColors.cardBorder, borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              const Icon(LucideIcons.history, size: 18, color: CaliMindColors.primary),
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
                  child: Text('No activity recorded yet.', style: CaliMindTypography.label),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  itemCount: logs.length,
                  separatorBuilder: (_, __) => const Divider(color: CaliMindColors.cardBorder, height: 1),
                  itemBuilder: (ctx, i) {
                    final log = logs[i];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: CaliMindColors.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(log.actionType, style: CaliMindTypography.bodySmall.copyWith(
                              fontSize: 10, fontWeight: FontWeight.w700, color: CaliMindColors.primary,
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
                            Text(log.ipAddressRedacted!, style: CaliMindTypography.bodySmall.copyWith(color: CaliMindColors.mutedForeground)),
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
