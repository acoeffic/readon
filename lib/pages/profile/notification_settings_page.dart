import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/app_theme.dart';
import '../../widgets/back_header.dart';
class NotificationSettingsPage extends StatefulWidget {
  const NotificationSettingsPage({super.key});

  @override
  State<NotificationSettingsPage> createState() => _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<NotificationSettingsPage> {
  final supabase = Supabase.instance.client;

  bool _notificationsEnabled = true;
  TimeOfDay _reminderTime = const TimeOfDay(hour: 20, minute: 0);
  // Jours sélectionnés : index 0=Lundi, 6=Dimanche (tous actifs par défaut)
  List<bool> _selectedDays = List.filled(7, true);
  bool _isLoading = true;

  static const _dayLabels = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];

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
          .select('notifications_enabled, notification_reminder_time, notification_days')
          .eq('id', userId)
          .maybeSingle();

      if (response != null) {
        setState(() {
          _notificationsEnabled = response['notifications_enabled'] ?? true;

          final timeString = response['notification_reminder_time'] as String?;
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
              final index = (d as int) - 1; // 1-7 → 0-6
              if (index >= 0 && index < 7) {
                _selectedDays[index] = true;
              }
            }
          }

          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Erreur chargement paramètres: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleNotifications(bool value) async {
    setState(() => _notificationsEnabled = value);

    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId != null) {
        await supabase.from('profiles').update({
          'notifications_enabled': value,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', userId);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              value
                  ? '✅ Notifications activées'
                  : '🔕 Notifications désactivées',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() => _notificationsEnabled = !value);

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

    try {
      final timeString = '${newTime.hour.toString().padLeft(2, '0')}:${newTime.minute.toString().padLeft(2, '0')}';

      final userId = supabase.auth.currentUser?.id;
      if (userId != null) {
        await supabase.from('profiles').update({
          'notifications_enabled': _notificationsEnabled,
          'notification_reminder_time': timeString,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', userId);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⏰ Heure de rappel mise à jour'),
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

  Future<void> _toggleDay(int index) async {
    final updated = List<bool>.from(_selectedDays);
    updated[index] = !updated[index];

    // Empêcher de tout désélectionner
    if (!updated.contains(true)) return;

    setState(() => _selectedDays = updated);

    try {
      final userId = supabase.auth.currentUser?.id;
      if (userId != null) {
        final daysList = <int>[];
        for (var i = 0; i < 7; i++) {
          if (updated[i]) daysList.add(i + 1); // 0-6 → 1-7
        }
        await supabase.from('profiles').update({
          'notification_days': daysList,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', userId);
      }
    } catch (e) {
      setState(() {
        _selectedDays[index] = !_selectedDays[index];
      });
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

  String _formatTime(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: const SafeArea(
          child: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpace.l),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const BackHeader(title: 'Notifications'),
              const SizedBox(height: AppSpace.l),

              Text(
                'Rappels de lecture',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: AppSpace.s),
              Text(
                'Reste motivé avec des rappels quotidiens pour maintenir ton flow de lecture.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
              ),
              const SizedBox(height: AppSpace.xl),

              Container(
                padding: const EdgeInsets.all(AppSpace.l),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(AppRadius.l),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(AppSpace.s),
                          decoration: BoxDecoration(
                            color: _notificationsEnabled
                                ? AppColors.primary.withValues(alpha: 0.1)
                                : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(AppRadius.m),
                          ),
                          child: Icon(
                            _notificationsEnabled
                                ? Icons.notifications_active
                                : Icons.notifications_off,
                            color: _notificationsEnabled
                                ? AppColors.primary
                                : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: AppSpace.m),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Activer les notifications',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                              Text(
                                'Reçois des rappels quotidiens',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                    ),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: _notificationsEnabled,
                          onChanged: _toggleNotifications,
                          activeThumbColor: AppColors.primary,
                        ),
                      ],
                    ),
                    if (_notificationsEnabled) ...[
                      const Divider(height: AppSpace.l),
                      // Sélection des jours
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(AppSpace.s),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(AppRadius.m),
                            ),
                            child: const Icon(
                              Icons.calendar_today,
                              color: AppColors.primary,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: AppSpace.m),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Jours de rappel',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                                Text(
                                  'Quels jours veux-tu être notifié ?',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
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
                                    : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(AppRadius.m),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                _dayLabels[index],
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: selected
                                      ? Colors.white
                                      : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                                ),
                              ),
                            ),
                          );
                        }),
                      ),
                      const Divider(height: AppSpace.l),
                      // Heure du rappel
                      InkWell(
                        onTap: _changeReminderTime,
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(AppSpace.s),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha:0.1),
                                borderRadius: BorderRadius.circular(AppRadius.m),
                              ),
                              child: const Icon(
                                Icons.access_time,
                                color: AppColors.primary,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: AppSpace.m),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Heure du rappel',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.w600,
                                        ),
                                  ),
                                  Text(
                                    'Quand veux-tu recevoir le rappel ?',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
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
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppSpace.xl),

              Container(
                padding: const EdgeInsets.all(AppSpace.l),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha:0.1),
                  borderRadius: BorderRadius.circular(AppRadius.l),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha:0.2),
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
                            'À propos des notifications',
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
                            'Tu recevras une notification les jours sélectionnés pour te rappeler de lire et maintenir ton flow.',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  color: AppColors.primary.withValues(alpha:0.8),
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
    );
  }
}
