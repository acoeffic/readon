import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/app_theme.dart';
import '../../navigation/main_navigation.dart';
import '../../services/subscription_service.dart';
import '../welcome/welcome_page.dart';
import '../onboarding/onboarding_page.dart';

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
        _destination = const WelcomePage();
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
          'display_name': meta['display_name'] ?? '',
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
      setState(() {
        _destination =
            completed ? const MainNavigation() : const OnboardingPage();
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _destination = const MainNavigation();
        _loading = false;
      });
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
