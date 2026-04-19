  import 'package:flutter/foundation.dart';
  import 'package:flutter/material.dart';
  import 'package:supabase_flutter/supabase_flutter.dart';
  import '../../theme/app_theme.dart';
  import '../../navigation/main_navigation.dart';
  import '../../services/monthly_notification_service.dart';
  import '../../services/feed_prefetcher.dart';
  import '../../services/push_notification_service.dart';
  import '../../services/subscription_service.dart';
  import '../onboarding/onboarding_page.dart';
  import 'login_page.dart';

  class AuthGate extends StatefulWidget {
    const AuthGate({super.key});

    @override
    State<AuthGate> createState() => _AuthGateState();
  }

  class _AuthGateState extends State<AuthGate> {
    bool _loading = true;
    Widget? _destination;

    @override
    void initState() {
      super.initState();
      _checkAuthState();
    }

    Future<void> _checkAuthState() async {
      final session = Supabase.instance.client.auth.currentSession;

      if (session == null) {
        setState(() {
          _destination = const LoginPage();
          _loading = false;
        });
        return;
      }

      try {
        final user = session.user;
        final userId = user.id;

        // Associer l'utilisateur à RevenueCat
        await SubscriptionService().loginUser(userId);

        // Verifier si le profil existe
        final profile = await Supabase.instance.client
            .from('profiles')
            .select('onboarding_completed')
            .eq('id', userId)
            .maybeSingle();

        // Si le profil n'existe pas (signup avec confirmation email),
        // le creer maintenant avec les metadata de l'utilisateur
        if (profile == null) {
          final meta = user.userMetadata ?? {};
          await Supabase.instance.client.from('profiles').upsert({
            'id': userId,
            'email': user.email,
            'display_name': meta['display_name'] ?? meta['full_name'] ?? meta['name'] ?? '',
            'created_at': DateTime.now().toIso8601String(),
          });

          if (!mounted) return;
          setState(() {
            _destination = const OnboardingPage();
            _loading = false;
          });
          return;
        }

        final completed = profile['onboarding_completed'] == true;

        if (!mounted) return;
        if (completed) FeedPrefetcher.start();
        setState(() {
          _destination =
              completed ? const MainNavigation() : const OnboardingPage();
          _loading = false;
        });
      } catch (e, stack) {
        debugPrint('AuthGate error: $e\n$stack');
        if (!mounted) return;
        setState(() {
          _destination = const MainNavigation();
          _loading = false;
        });
      } finally {
        if (Supabase.instance.client.auth.currentUser != null) {
          await PushNotificationService().initialize();
          // Schedule reading reminders from user profile settings
          await _scheduleReadingRemindersFromProfile();
        }
      }
    }

    Future<void> _scheduleReadingRemindersFromProfile() async {
      try {
        final userId = Supabase.instance.client.auth.currentUser?.id;
        if (userId == null) return;

        final profile = await Supabase.instance.client
            .from('profiles')
            .select('notifications_enabled, notification_reminder_time, notification_days')
            .eq('id', userId)
            .maybeSingle();

        if (profile == null) return;

        final svc = MonthlyNotificationService();
        final enabled = profile['notifications_enabled'] ?? true;

        if (!enabled) {
          await svc.cancelReadingReminders();
          return;
        }

        // Parse reminder time
        final timeStr = profile['notification_reminder_time'] as String? ?? '20:00';
        final parts = timeStr.split(':');
        final time = TimeOfDay(
          hour: int.tryParse(parts[0]) ?? 20,
          minute: int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0,
        );

        // Parse days (default: all days)
        final daysRaw = profile['notification_days'] as List<dynamic>?;
        final days = daysRaw != null && daysRaw.isNotEmpty
            ? daysRaw.cast<int>()
            : <int>[1, 2, 3, 4, 5, 6, 7];

        await svc.scheduleReadingReminders(time: time, isoDays: days);
      } catch (e) {
        debugPrint('Reading reminders scheduling error: $e');
      }
    }

    @override
    Widget build(BuildContext context) {
      if (_loading) {
        return const Scaffold(
          backgroundColor: AppColors.bgLight,
          body: Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
        );
      }
      return _destination!;
    }
  }
