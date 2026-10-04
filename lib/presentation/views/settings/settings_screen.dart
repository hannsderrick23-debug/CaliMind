import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:calimind/core/constants/app_colors.dart';
import 'package:calimind/core/constants/app_typography.dart';
import 'package:calimind/core/services/biometric_service.dart';
import 'package:calimind/core/services/device_calendar_service.dart';
import 'package:calimind/core/services/push_notification_service.dart';
import 'package:calimind/core/services/task_reminder_service.dart';
import 'package:calimind/core/services/widget_service.dart';
import 'package:calimind/core/utils/app_feedback.dart';
import 'package:calimind/data/datasources/audit_remote_datasource.dart';
import 'package:calimind/domain/models/audit_log.dart';
import 'package:calimind/presentation/state/auth_provider.dart';
import 'package:calimind/presentation/state/device_calendar_provider.dart';
import 'package:calimind/presentation/state/profile_provider.dart';
import 'package:calimind/presentation/state/schedule_provider.dart';
import 'package:calimind/presentation/state/task_provider.dart';
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
  bool _widgetTitleSharingEnabled = false;
  bool _isChangingWidgetTitleSharing = false;
  bool _notificationsEnabled = true;
  bool _notificationSoundEnabled = true;
  bool _isChangingNotifications = false;
  bool _isChangingNotificationSound = false;
  bool _isSigningOut = false;
  final _biometrics = BiometricService();
  final _reminders = TaskReminderService();

  @override
  void initState() {
    super.initState();
    _loadBiometricSetting();
    _loadWidgetSharingSetting();
    _loadNotificationSettings();
  }

  Future<void> _loadNotificationSettings() async {
    try {
      final enabled = await _reminders.areNotificationsEnabled();
      final soundEnabled = await _reminders.isSoundEnabled();
      if (!mounted) return;
      setState(() {
        _notificationsEnabled = enabled;
        _notificationSoundEnabled = soundEnabled;
      });
    } catch (error) {
      debugPrint('Could not load notification preferences: $error');
      if (mounted) {
        _showFeedback(
          'Could not load notification preferences.',
          isError: true,
        );
      }
    }
  }

  Future<void> _setNotificationsEnabled(bool enabled) async {
    setState(() => _isChangingNotifications = true);
    try {
      final configureError = await PushNotificationService.instance
          .configureNotifications(enabled);
      if (configureError != null) {
        final currentEnabled = await _reminders.areNotificationsEnabled();
        if (mounted) {
          setState(() => _notificationsEnabled = currentEnabled);
          _showFeedback(configureError, isError: true);
        }
        return;
      }
      if (!mounted) return;

      if (enabled) {
        final tasks = ref.read(taskProvider).valueOrNull ?? const [];
        var failed = 0;
        for (final task in tasks.where(
          (task) => !task.completed && task.reminderAt != null,
        )) {
          final scheduled = await _reminders.scheduleTaskReminder(
            taskId: task.id,
            title: task.title,
            reminderAt: task.reminderAt!,
          );
          if (!scheduled) failed++;
        }
        if (failed > 0 && mounted) {
          _showFeedback(
            'Notifications are on, but $failed task reminder(s) could not be scheduled.',
            isError: true,
          );
        }
      }

      if (mounted) {
        setState(() => _notificationsEnabled = enabled);
        _showFeedback(
          enabled ? 'Notifications are on.' : 'Notifications are off.',
        );
      }
    } catch (error) {
      debugPrint('Could not update notification preferences: $error');
      if (mounted) {
        _showFeedback(
          'Could not update notification preferences. Please try again.',
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isChangingNotifications = false);
    }
  }

  Future<void> _setNotificationSoundEnabled(bool enabled) async {
    setState(() => _isChangingNotificationSound = true);
    try {
      await _reminders.setSoundEnabled(enabled);
      if (!mounted) return;
      final tasks = ref.read(taskProvider).valueOrNull ?? const [];
      var failed = 0;
      for (final task in tasks.where(
        (task) => !task.completed && task.reminderAt != null,
      )) {
        final scheduled = await _reminders.scheduleTaskReminder(
          taskId: task.id,
          title: task.title,
          reminderAt: task.reminderAt!,
        );
        if (!scheduled) failed++;
      }
      if (mounted) {
        setState(() => _notificationSoundEnabled = enabled);
        _showFeedback(
          failed > 0
              ? 'Sound preference saved, but $failed reminder(s) could not be updated.'
              : enabled
                  ? 'Reminder sounds are on.'
                  : 'Reminder sounds are off.',
          isError: failed > 0,
        );
      }
    } catch (error) {
      debugPrint('Could not update reminder sound preference: $error');
      if (mounted) {
        _showFeedback('Could not update the sound setting.', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isChangingNotificationSound = false);
    }
  }

  Future<void> _signOut() async {
    if (_isSigningOut) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text('You can sign back in at any time.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _isSigningOut = true);
    try {
      final signedOut = await ref.read(authProvider.notifier).signOut();
      if (!signedOut) {
        if (mounted) {
          _showFeedback(
            ref.read(authProvider).errorMessage ?? 'Could not sign out.',
            isError: true,
          );
        }
        return;
      }
      AppFeedback.success(messenger, 'Signed out.');
      if (mounted) context.go('/welcome');
    } catch (error) {
      debugPrint('Could not sign out: $error');
      if (mounted) {
        _showFeedback('Could not sign out. Please try again.', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isSigningOut = false);
    }
  }

  Future<void> _loadWidgetSharingSetting() async {
    try {
      final enabled = await WidgetService.isTaskTitleSharingEnabled();
      if (mounted) setState(() => _widgetTitleSharingEnabled = enabled);
    } catch (error) {
      debugPrint('Could not load widget privacy setting: $error');
      if (mounted) {
        _showFeedback('Could not load the widget privacy setting.',
            isError: true);
      }
    }
  }

  Future<void> _setWidgetTitleSharingEnabled(bool enabled) async {
    setState(() => _isChangingWidgetTitleSharing = true);
    try {
      await WidgetService.setTaskTitleSharingEnabled(enabled);
      if (enabled) {
        final tasks = ref.read(taskProvider).valueOrNull ?? const [];
        final scheduledTaskIds =
            ref.read(scheduleProvider).slots.map((slot) => slot.taskId);
        await WidgetService.refresh(
          tasks,
          scheduledTaskIds: scheduledTaskIds,
        );
      }
      if (mounted) {
        setState(() => _widgetTitleSharingEnabled = enabled);
      }
    } catch (error) {
      debugPrint('Could not update widget privacy setting: $error');
      if (mounted) {
        _showFeedback('Could not update the home-screen widget setting.',
            isError: true);
      }
    } finally {
      if (mounted) setState(() => _isChangingWidgetTitleSharing = false);
    }
  }

  Future<void> _loadBiometricSetting() async {
    final enabled = await _biometrics.isEnabled() &&
        await _biometrics.isBiometricsAvailable();
    if (mounted) setState(() => _biometricEnabled = enabled);
  }

  Future<void> _setCalendarBusyTimesEnabled(bool enabled) async {
    try {
      if (!enabled) {
        await ref.read(deviceCalendarProvider.notifier).disable();
        return;
      }
      final status = await ref.read(deviceCalendarProvider.notifier).enable();
      if (!mounted || status == DeviceCalendarAccessStatus.granted) return;
      final message = switch (status) {
        DeviceCalendarAccessStatus.denied =>
          'Calendar access was denied. You can enable it in device settings.',
        DeviceCalendarAccessStatus.restricted =>
          'Calendar access is restricted on this device.',
        DeviceCalendarAccessStatus.unsupported =>
          'Read-only calendar access is unavailable on this platform.',
        DeviceCalendarAccessStatus.disabled =>
          'Calendar busy-time planning was not enabled.',
        DeviceCalendarAccessStatus.notRequested =>
          'Calendar permission was not requested. Try again.',
        DeviceCalendarAccessStatus.error =>
          'Could not enable calendar busy-time planning.',
        DeviceCalendarAccessStatus.granted => '',
      };
      AppFeedback.error(ScaffoldMessenger.of(context), message);
    } catch (error) {
      debugPrint('Could not update calendar busy-time setting: $error');
      if (mounted) {
        AppFeedback.error(
          ScaffoldMessenger.of(context),
          'Could not update calendar busy-time planning.',
        );
      }
    }
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
    final calendar = ref.watch(deviceCalendarProvider);
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
          const _SectionHeader(
            title: 'Preferences',
            icon: LucideIcons.slidersHorizontal,
            color: CaliMindColors.primary,
          ),
          const SizedBox(height: 10),
          _SettingsCard(
            children: [
              _SettingsTile(
                icon: LucideIcons.bell,
                title: 'Notifications and reminders',
                subtitle: _isChangingNotifications
                    ? 'Updating notification settings...'
                    : _notificationsEnabled
                        ? 'Task reminders and schedule updates are enabled.'
                        : 'Task reminders and schedule updates are paused.',
                trailing: _isChangingNotifications
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: CaliMindColors.primary,
                        ),
                      )
                    : Switch(
                        value: _notificationsEnabled,
                        onChanged: _setNotificationsEnabled,
                        activeThumbColor: CaliMindColors.primary,
                      ),
              ),
              _Divider(),
              _SettingsTile(
                icon: LucideIcons.volume2,
                title: 'Local reminder sound',
                subtitle:
                    'Control sound for scheduled reminders and in-app alerts.',
                trailing: Switch(
                  value: _notificationSoundEnabled,
                  onChanged:
                      !_notificationsEnabled || _isChangingNotificationSound
                          ? null
                          : _setNotificationSoundEnabled,
                  activeThumbColor: CaliMindColors.primary,
                ),
              ),
              _Divider(),
              const _SettingsTile(
                icon: LucideIcons.alarmClock,
                title: 'About alarm reminders',
                subtitle:
                    'CaliMind schedules notifications, not alarms in your Clock app. Delivery time can depend on device permissions and battery settings.',
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
                onTap: _isTestingVoiceService ? null : _testVoiceAssistant,
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
          const _SectionHeader(
            title: 'Planning integrations',
            icon: LucideIcons.calendarClock,
            color: CaliMindColors.primary,
          ),
          const SizedBox(height: 10),
          _SettingsCard(
            children: [
              _SettingsTile(
                icon: LucideIcons.calendarDays,
                title: 'Use device calendar busy times',
                subtitle: calendar.isLoading
                    ? 'Checking calendar permission...'
                    : !DeviceCalendarService.supportsReadOnlyCalendarAccess
                        ? 'Unavailable here: granting calendar access could also allow changes.'
                        : calendar.enabled
                            ? 'Only event times are used; event details stay private.'
                            : 'Off by default. Reads busy times only after you enable it.',
                trailing: Switch(
                  value: calendar.enabled,
                  onChanged: calendar.isLoading ||
                          !DeviceCalendarService.supportsReadOnlyCalendarAccess
                      ? null
                      : _setCalendarBusyTimesEnabled,
                  activeThumbColor: CaliMindColors.primary,
                ),
              ),
              _Divider(),
              _SettingsTile(
                icon: LucideIcons.calendarPlus,
                title: 'Add events to your calendar',
                subtitle: DeviceCalendarService.supportsEventCreation
                    ? 'Open your calendar app from a task and review each event before saving.'
                    : 'Event creation from tasks is currently available on Android.',
              ),
              _Divider(),
              _SettingsTile(
                icon: LucideIcons.layoutDashboard,
                title: 'Share next task with widgets',
                subtitle: _isChangingWidgetTitleSharing
                    ? 'Updating widget privacy...'
                    : _widgetTitleSharingEnabled
                        ? 'Shows the next task title on your home screen.'
                        : 'Off by default. Hides task titles from widgets.',
                trailing: Switch(
                  value: _widgetTitleSharingEnabled,
                  onChanged: _isChangingWidgetTitleSharing
                      ? null
                      : _setWidgetTitleSharingEnabled,
                  activeThumbColor: CaliMindColors.primary,
                ),
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
            onTap: _isSigningOut ? null : _signOut,
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
                  _isSigningOut
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: CaliMindColors.destructive,
                          ),
                        )
                      : const Icon(LucideIcons.logOut,
                          color: CaliMindColors.destructive, size: 18),
                  const SizedBox(width: 8),
                  Text(_isSigningOut ? 'Signing out...' : 'Sign Out',
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
