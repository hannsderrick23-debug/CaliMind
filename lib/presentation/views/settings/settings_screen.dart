import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:calimind/core/constants/app_colors.dart';
import 'package:calimind/core/constants/app_typography.dart';
import 'package:calimind/core/network/supabase_client.dart';
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
  String? _groqApiKey;
  bool _isTestingGroq = false;

  @override
  void initState() {
    super.initState();
    _loadGroqKey();
  }

  Future<void> _loadGroqKey() async {
    final groq = ref.read(groqServiceProvider);
    final key = await groq.getApiKey();
    if (mounted) {
      setState(() => _groqApiKey = key);
    }
  }

  Future<void> _loadAuditLogs() async {
    final logs = await _auditDatasource.fetchAuditLogs(limit: 20);
    if (mounted) {
      setState(() => _auditLogs = logs);
    }
  }

  Future<void> _configureGroqKey() async {
    final controller = TextEditingController(text: _groqApiKey ?? '');
    var obscure = true;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: CaliMindColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: CaliMindColors.cardBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: CaliMindColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(LucideIcons.bot,
                        size: 20, color: CaliMindColors.primary),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Groq AI API Key', style: CaliMindTypography.h3),
                      Text(
                        'Powers Whisper Large v3 STT & LLaMA 3.3',
                        style: CaliMindTypography.bodySmall,
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),
              TextField(
                controller: controller,
                obscureText: obscure,
                style: CaliMindTypography.bodyMedium,
                decoration: InputDecoration(
                  hintText: 'gsk_...',
                  hintStyle: CaliMindTypography.bodyMedium.copyWith(
                    color: CaliMindColors.mutedForeground,
                  ),
                  filled: true,
                  fillColor: CaliMindColors.background,
                  suffixIcon: IconButton(
                    icon: Icon(
                      obscure ? LucideIcons.eye : LucideIcons.eyeOff,
                      size: 18,
                      color: CaliMindColors.mutedForeground,
                    ),
                    onPressed: () {
                      setModalState(() => obscure = !obscure);
                    },
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: CaliMindColors.cardBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: CaliMindColors.cardBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: CaliMindColors.primary),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  if (_groqApiKey != null)
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: CaliMindColors.destructive,
                          side: const BorderSide(
                              color: CaliMindColors.destructive),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () async {
                          final groq = ref.read(groqServiceProvider);
                          await groq.clearApiKey();
                          await _loadGroqKey();
                          if (ctx.mounted) Navigator.pop(ctx);
                        },
                        child: const Text('Clear Key'),
                      ),
                    ),
                  if (_groqApiKey != null) const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: CaliMindColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () async {
                        final key = controller.text.trim();
                        final groq = ref.read(groqServiceProvider);
                        if (key.isNotEmpty) {
                          await groq.saveApiKey(key);
                        } else {
                          await groq.clearApiKey();
                        }
                        await _loadGroqKey();
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                      child: const Text('Save Encrypted'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _testGroqConnection() async {
    setState(() => _isTestingGroq = true);
    final groq = ref.read(groqServiceProvider);

    final res = await groq.parseVoiceCommandWithAI(
      'schedule a 30 minute study calculus session tomorrow morning',
    );

    if (mounted) {
      setState(() => _isTestingGroq = false);
      final success = res != null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: success
              ? const Color(0xFF10B981)
              : CaliMindColors.destructive,
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
                      ? 'Groq API Connected! LLaMA 3.3 returned valid schedule parse.'
                      : 'Connection failed. Please check your Groq API key.',
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
    final hasGroq = _groqApiKey != null && _groqApiKey!.isNotEmpty;

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
          // Voice AI & Groq Engine
          const _SectionHeader(
            title: 'AI Voice Model (Groq Cloud)',
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
                        gradient: CaliMindColors.mindGradient,
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
                              Text('Groq AI Acceleration',
                                  style: CaliMindTypography.bodyMedium
                                      .copyWith(fontWeight: FontWeight.w600)),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: hasGroq
                                      ? const Color(0xFF10B981)
                                          .withValues(alpha: 0.15)
                                      : CaliMindColors.mutedForeground
                                          .withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  hasGroq ? 'Active' : 'Unconfigured',
                                  style: CaliMindTypography.bodySmall.copyWith(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: hasGroq
                                        ? const Color(0xFF10B981)
                                        : CaliMindColors.mutedForeground,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            hasGroq
                                ? 'Whisper-Large-v3 & LLaMA-3.3 active'
                                : 'Using local speech fallback',
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
                icon: LucideIcons.keyRound,
                title: 'Groq API Key',
                subtitle: hasGroq
                    ? '••••••••${_groqApiKey!.substring(_groqApiKey!.length - 4)}'
                    : 'Set your free Groq API key for cloud AI',
                trailing: const Icon(LucideIcons.chevronRight,
                    size: 16, color: CaliMindColors.mutedForeground),
                onTap: _configureGroqKey,
              ),
              if (hasGroq) ...[
                _Divider(),
                _SettingsTile(
                  icon: LucideIcons.zap,
                  title: 'Test AI Model Latency',
                  subtitle: _isTestingGroq
                      ? 'Testing connection...'
                      : 'Send test prompt to LLaMA 3.3',
                  trailing: _isTestingGroq
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: CaliMindColors.primary),
                        )
                      : const Icon(LucideIcons.playCircle,
                          size: 18, color: CaliMindColors.primary),
                  onTap: _isTestingGroq ? null : _testGroqConnection,
                ),
              ],
            ],
          ),

          const SizedBox(height: 24),
          // Backend & Database (Supabase)
          const _SectionHeader(
            title: 'Database & Auth (Supabase)',
            icon: LucideIcons.database,
            color: Color(0xFF10B981),
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
                        color: const Color(0xFF10B981).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(LucideIcons.server,
                          color: Color(0xFF10B981), size: 20),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text('PostgreSQL Cloud Sync',
                                  style: CaliMindTypography.bodyMedium
                                      .copyWith(fontWeight: FontWeight.w600)),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981)
                                      .withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'RLS Active',
                                  style: CaliMindTypography.bodySmall.copyWith(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF10B981),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            SupabaseConfig.url,
                            style: CaliMindTypography.timeMonospace
                                .copyWith(fontSize: 11),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
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
                trailing: Icon(LucideIcons.check,
                    size: 16, color: Color(0xFF10B981)),
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
                subtitle: 'Face ID or Fingerprint',
                trailing: Switch(
                  value: true,
                  onChanged: (_) {},
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
                  separatorBuilder: (_, __) =>
                      const Divider(color: CaliMindColors.cardBorder, height: 1),
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
                              color: CaliMindColors.primary
                                  .withValues(alpha: 0.1),
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
