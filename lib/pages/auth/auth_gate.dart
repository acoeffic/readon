  import 'package:flutter/foundation.dart';
  import 'package:flutter/material.dart';
  import 'package:provider/provider.dart';
  import 'package:supabase_flutter/supabase_flutter.dart';
  import '../../providers/guest_mode_provider.dart';
  import '../../theme/app_theme.dart';
  import '../../navigation/main_navigation.dart';
  import '../../services/analytics_service.dart';
  import '../../services/monthly_notification_service.dart';
  import '../../services/feed_prefetcher.dart';
  import '../../services/push_notification_service.dart';
  import '../../services/referral_service.dart';
  import '../../services/subscription_service.dart';
  import '../onboarding/onboarding_page.dart';
  import 'login_page.dart';

  class AuthGate extends StatefulWidget {
    const AuthGate({super.key});

    @override
    State<AuthGate> createState() => _AuthGateState();
  }

  /// Fix 2026-09-28 : `identify`, `loginUser` et la lecture du profil
  /// s'enchaînaient sans AUCUN timeout (pas même les 6s du splash) — un seul
  /// appel qui pend (Wi-Fi « connecté sans internet ») bloquait le spinner
  /// pour toujours, juste avant l'écran qui décide onboarding vs app. Cf.
  /// `SplashScreen._bestEffort`, jamais repris ici (audit friction 18/08).
  const _kAuthGateTimeout = Duration(seconds: 6);

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
        // Mode invité : si l'utilisateur a précédemment choisi "Continuer
        // sans compte", on l'envoie directement dans l'app (contenu public
        // uniquement). Sinon, écran de connexion.
        if (mounted) {
          final guest = context.read<GuestModeProvider>();
          if (!guest.initialized) await guest.load();
          if (!mounted) return;
          if (guest.isGuest) {
            setState(() {
              _destination = const MainNavigation();
              _loading = false;
            });
            return;
          }
        }
        if (!mounted) return;
        setState(() {
          _destination = const LoginPage();
          _loading = false;
        });
        return;
      }

      try {
        final user = session.user;
        final userId = user.id;

        // Identifier l'utilisateur côté PostHog (lie events anonymes ↔ user)
        // et l'associer à RevenueCat : best-effort, jamais bloquant — ni
        // l'un ni l'autre ne doit retarder l'arrivée dans l'app.
        try {
          await AnalyticsService().identify(
            userId: userId,
            properties: {
              if (user.email != null) 'email': user.email!,
              'auth_provider':
                  (user.appMetadata['provider'] as String?) ?? 'email',
            },
          ).timeout(_kAuthGateTimeout);
        } catch (e) {
          debugPrint('AnalyticsService.identify ignoré (non bloquant): $e');
        }
        try {
          await SubscriptionService().loginUser(userId).timeout(_kAuthGateTimeout);
        } catch (e) {
          debugPrint('SubscriptionService.loginUser ignoré (non bloquant): $e');
        }

        // Verifier si le profil existe
        final profile = await Supabase.instance.client
            .from('profiles')
            .select('onboarding_completed')
            .eq('id', userId)
            .maybeSingle()
            .timeout(_kAuthGateTimeout);

        // Si le profil n'existe pas (signup avec confirmation email),
        // le creer maintenant avec les metadata de l'utilisateur
        if (profile == null) {
          final meta = user.userMetadata ?? {};
          await Supabase.instance.client.from('profiles').upsert({
            'id': userId,
            'email': user.email,
            'display_name': meta['display_name'] ?? meta['full_name'] ?? meta['name'] ?? '',
            'created_at': DateTime.now().toIso8601String(),
          }).timeout(_kAuthGateTimeout);

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
          // `initialize()` ne demande PAS la permission système : elle câble
          // seulement le routage des notifications et enregistre le token si
          // la permission est déjà accordée. La popup est présentée plus tard,
          // après la première session de lecture terminée
          // (cf. MainNavigation._maybeAskPushPermission).
          await PushNotificationService().initialize();
          // Schedule reading reminders from user profile settings
          await _scheduleReadingRemindersFromProfile();
          // Parrainage : un code reçu par deep link AVANT l'inscription (cas
          // principal — le filleul n'avait pas l'app) est mémorisé en attente
          // par DeepLinkService. C'est ici, une fois la session ouverte, qu'il
          // faut l'appliquer. Le docstring de `applyPendingCode()` prévoyait
          // cet appel depuis AuthGate ; il n'existait pas, donc aucun
          // parrainage différé n'était jamais attribué.
          await _applyPendingReferral();
        }
      }
    }

    /// Best-effort : ne doit jamais bloquer l'arrivée dans l'app.
    /// `applyPendingCode()` ne consomme le code qu'en cas de résultat
    /// définitif — une erreur réseau le laisse en attente pour le prochain
    /// lancement.
    Future<void> _applyPendingReferral() async {
      try {
        final service = ReferralService();
        // Android : récupère le code transmis par le Play Store à
        // l'installation. No-op ailleurs et après le premier passage.
        await service.captureInstallReferrer();
        // Met en cache le lien personnel pour que TOUS les partages sortants
        // (session, livre terminé, badge, Wrapped…) portent le code de
        // parrainage plutôt qu'un lien App Store anonyme.
        await service.primeShareLink();
        final result = await service.applyPendingCode();
        if (result != null) {
          debugPrint('Parrainage appliqué: $result');
        }
      } catch (e) {
        debugPrint('Parrainage (non bloquant): $e');
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
