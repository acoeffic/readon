import 'package:flutter/material.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../l10n/app_localizations.dart';
import '../../services/monthly_notification_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/back_header.dart';
import '../../widgets/constrained_content.dart';

class NotificationSettingsPage extends StatefulWidget {
  const NotificationSettingsPage({super.key});

  @override
  State<NotificationSettingsPage> createState() =>
      _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<NotificationSettingsPage> {
  final supabase = Supabase.instance.client;

  // Rappels de lecture
  bool _notificationsEnabled = true;
  TimeOfDay _reminderTime = const TimeOfDay(hour: 20, minute: 0);
  List<bool> _selectedDays = List.filled(7, true);

  // Notifications push
  bool _notifyFriendRequests = true;

  // Notifications email
  bool _notifyFriendRequestsEmail = true;

  bool _isLoading = true;

  static const _dayLabels = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];

  /// IANA timezone name from the device (e.g. "Europe/Paris").
  Future<String> _getTimezone() async {
    try {
      return await FlutterTimezone.getLocalTimezone();
    } catch (_) {
      return 'Europe/Paris';
    }
  }

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      final response = await supabase
          .from('profiles')
          .select(
            'notifications_enabled, notification_reminder_time, notification_days, notify_friend_requests, notify_friend_requests_email',
          )
          .eq('id', userId)
          .maybeSingle();

      if (response != null) {
        setState(() {
          _notificationsEnabled = response['notifications_enabled'] ?? true;

          final timeString =
              response['notification_reminder_time'] as String?;
          if (timeString != null && timeString.isNotEmpty) {
            final parts = timeString.split(':');
            if (parts.length == 2) {
              _reminderTime = TimeOfDay(
                hour: int.tryParse(parts[0]) ?? 20,
                minute: int.tryParse(parts[1]) ?? 0,
              );
            }
          }

          final days = response['notification_days'] as List<dynamic>?;
          if (days != null && days.isNotEmpty) {
            _selectedDays = List.filled(7, false);
            for (final d in days) {
              final index = (d as int) - 1;
              if (index >= 0 && index < 7) {
                _selectedDays[index] = true;
              }
            }
          }

          _notifyFriendRequests =
              response['notify_friend_requests'] ?? true;
          _notifyFriendRequestsEmail =
              response['notify_friend_requests_email'] ?? true;

          _isLoading = false;
        });
        // Sync local notifications with loaded settings
        _syncLocalReminders();
      }
    } catch (e) {
      debugPrint('Erreur chargement paramètres: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateProfile(Map<String, dynamic> fields) async {
    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId == null) return;

      await supabase.from('profiles').update({
        ...fields,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', userId);

      if (mounted) {
        final l = AppLocalizations.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l.settingsSaved),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Sync local reading reminder notifications with current settings.
  Future<void> _syncLocalReminders() async {
    final svc = MonthlyNotificationService();
    if (!_notificationsEnabled) {
      await svc.cancelReadingReminders();
      return;
    }
    final days = <int>[];
    for (var i = 0; i < 7; i++) {
      if (_selectedDays[i]) days.add(i + 1); // 1=Mon … 7=Sun
    }
    await svc.scheduleReadingReminders(time: _reminderTime, isoDays: days);
  }

  Future<void> _toggleNotifications(bool value) async {
    setState(() => _notificationsEnabled = value);
    try {
      final tz = await _getTimezone();
      await _updateProfile({'notifications_enabled': value, 'timezone': tz});
      await _syncLocalReminders();
    } catch (_) {
      setState(() => _notificationsEnabled = !value);
    }
  }

  Future<void> _toggleFriendRequests(bool value) async {
    setState(() => _notifyFriendRequests = value);
    try {
      await _updateProfile({'notify_friend_requests': value});
    } catch (_) {
      setState(() => _notifyFriendRequests = !value);
    }
  }

  Future<void> _toggleFriendRequestsEmail(bool value) async {
    setState(() => _notifyFriendRequestsEmail = value);
    try {
      await _updateProfile({'notify_friend_requests_email': value});
    } catch (_) {
      setState(() => _notifyFriendRequestsEmail = !value);
    }
  }

  Future<void> _changeReminderTime() async {
    final newTime = await showTimePicker(
      context: context,
      initialTime: _reminderTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            timePickerTheme: TimePickerThemeData(
              backgroundColor: Theme.of(context).cardColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.l),
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (newTime == null) return;

    setState(() => _reminderTime = newTime);

    final timeString =
        '${newTime.hour.toString().padLeft(2, '0')}:${newTime.minute.toString().padLeft(2, '0')}';
    final tz = await _getTimezone();
    await _updateProfile({
      'notifications_enabled': _notificationsEnabled,
      'notification_reminder_time': timeString,
      'timezone': tz,
    });
    await _syncLocalReminders();
  }

  Future<void> _toggleDay(int index) async {
    final updated = List<bool>.from(_selectedDays);
    updated[index] = !updated[index];

    if (!updated.contains(true)) return;

    setState(() => _selectedDays = updated);

    try {
      final daysList = <int>[];
      for (var i = 0; i < 7; i++) {
        if (updated[i]) daysList.add(i + 1);
      }
      final tz = await _getTimezone();
      await _updateProfile({'notification_days': daysList, 'timezone': tz});
      await _syncLocalReminders();
    } catch (e) {
      setState(() {
        _selectedDays[index] = !_selectedDays[index];
      });
    }
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: const SafeArea(
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: ConstrainedContent(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpace.l),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BackHeader(title: l.notificationCenter, titleColor: Colors.black),
              const SizedBox(height: AppSpace.s),
              Text(
                l.notificationCenterDescription,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.6),
                    ),
              ),
              const SizedBox(height: AppSpace.xl),

              // ── Section Push ──
              _SectionHeader(
                icon: Icons.notifications_active,
                title: l.pushSection,
                subtitle: l.pushSectionDescription,
              ),
              const SizedBox(height: AppSpace.m),
              _SettingsCard(
                children: [
                  _SwitchRow(
                    icon: Icons.person_add,
                    iconColor: Colors.orange,
                    title: l.friendRequestNotifications,
                    subtitle: l.friendRequestNotificationsDesc,
                    value: _notifyFriendRequests,
                    onChanged: _toggleFriendRequests,
                  ),
                ],
              ),

              const SizedBox(height: AppSpace.xl),

              // ── Section Email ──
              _SectionHeader(
                icon: Icons.email_outlined,
                title: l.emailSection,
                subtitle: l.emailSectionDescription,
              ),
              const SizedBox(height: AppSpace.m),
              _SettingsCard(
                children: [
                  _SwitchRow(
                    icon: Icons.person_add,
                    iconColor: Colors.orange,
                    title: l.friendRequestEmail,
                    subtitle: l.friendRequestEmailDesc,
                    value: _notifyFriendRequestsEmail,
                    onChanged: _toggleFriendRequestsEmail,
                  ),
                ],
              ),

              const SizedBox(height: AppSpace.xl),

              // ── Section Rappels de lecture ──
              _SectionHeader(
                icon: Icons.menu_book,
                title: l.readingReminders,
                subtitle: l.remindersDescription,
              ),
              const SizedBox(height: AppSpace.m),
              _SettingsCard(
                children: [
                  _SwitchRow(
                    icon: _notificationsEnabled
                        ? Icons.notifications_active
                        : Icons.notifications_off,
                    iconColor: AppColors.primary,
                    title: l.enableNotifications,
                    subtitle: l.receiveDailyReminders,
                    value: _notificationsEnabled,
                    onChanged: _toggleNotifications,
                  ),
                  if (_notificationsEnabled) ...[
                    const Divider(height: AppSpace.l),
                    // Jours
                    Row(
                      children: [
                        _IconBox(
                          icon: Icons.calendar_today,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: AppSpace.m),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l.reminderDays,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                              Text(
                                l.whichDays,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withValues(alpha: 0.6),
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpace.m),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(7, (index) {
                        final selected = _selectedDays[index];
                        return GestureDetector(
                          onTap: () => _toggleDay(index),
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: selected
                                  ? AppColors.primary
                                  : Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withValues(alpha: 0.08),
                              borderRadius:
                                  BorderRadius.circular(AppRadius.m),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              _dayLabels[index],
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: selected
                                    ? Colors.white
                                    : Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.5),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                    const Divider(height: AppSpace.l),
                    // Heure
                    InkWell(
                      onTap: _changeReminderTime,
                      child: Row(
                        children: [
                          _IconBox(
                            icon: Icons.access_time,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: AppSpace.m),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  l.reminderTime,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w600),
                                ),
                                Text(
                                  l.whenReminder,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurface
                                            .withValues(alpha: 0.6),
                                      ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            _formatTime(_reminderTime),
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          const SizedBox(width: AppSpace.s),
                          Icon(
                            Icons.arrow_forward_ios,
                            size: 16,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.4),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),

              const SizedBox(height: AppSpace.xl),

              // ── Info box ──
              Container(
                padding: const EdgeInsets.all(AppSpace.l),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppRadius.l),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.2),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      color: AppColors.primary,
                      size: 24,
                    ),
                    const SizedBox(width: AppSpace.m),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l.aboutNotifications,
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            l.notificationInfo,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  color:
                                      AppColors.primary.withValues(alpha: 0.8),
                                ),
                          ),
                        ],
                      ),
                    ),
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

// ── Reusable widgets ──

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 22, color: AppColors.primary),
        const SizedBox(width: AppSpace.s),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.6),
                    ),
              ),
            ],
          ),
        ),
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
      padding: const EdgeInsets.all(AppSpace.l),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(AppRadius.l),
      ),
      child: Column(children: children),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _IconBox(icon: icon, color: value ? iconColor : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
        const SizedBox(width: AppSpace.m),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.6),
                    ),
              ),
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: AppColors.primary,
        ),
      ],
    );
  }
}

class _IconBox extends StatelessWidget {
  final IconData icon;
  final Color color;

  const _IconBox({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpace.s),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.m),
      ),
      child: Icon(icon, color: color, size: 24),
    );
  }
}
