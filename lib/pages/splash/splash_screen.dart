import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

import '../../config/env.dart';
import '../../services/analytics_service.dart';
import '../../services/subscription_service.dart';
import '../../services/monthly_notification_service.dart';
import '../../services/deep_link_service.dart';
import '../../services/widget_service.dart';
import '../../services/watch_control_service.dart';
import '../auth/auth_gate.dart';

const _logoAsset = 'assets/images/logo_lexday.svg';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _logoController;
  late final AnimationController _titleController;
  late final AnimationController _subtitleController;

  late final Animation<double> _logoFade;
  late final Animation<Offset> _logoSlide;
  late final Animation<double> _titleFade;
  late final Animation<Offset> _titleSlide;
  late final Animation<double> _subtitleFade;
  late final Animation<Offset> _subtitleSlide;

  @override
  void initState() {
    super.initState();

    // Logo animation
    _logoController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _logoFade = CurvedAnimation(
      parent: _logoController,
      curve: Curves.easeOut,
    );
    _logoSlide = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _logoController,
      curve: Curves.easeOut,
    ));

    // Title animation
    _titleController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _titleFade = CurvedAnimation(
      parent: _titleController,
      curve: Curves.easeOut,
    );
    _titleSlide = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _titleController,
      curve: Curves.easeOut,
    ));

    // Subtitle animation
    _subtitleController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _subtitleFade = CurvedAnimation(
      parent: _subtitleController,
      curve: Curves.easeOut,
    );
    _subtitleSlide = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _subtitleController,
      curve: Curves.easeOut,
    ));

    // Start staggered animations
    _logoController.forward();
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _titleController.forward();
    });
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) _subtitleController.forward();
    });

    _initializeAndNavigate();
  }

  /// Exécute une init non-critique en best-effort : timeout + try/catch.
  /// Fix 2026-08-11 : le splash enchaînait des `await` sans timeout ni
  /// try/catch — une seule init qui pend (Wi-Fi « connecté sans internet »)
  /// ou qui lève une exception (RevenueCat, notifications…) bloquait l'app
  /// sur le splash pour toujours. Aucune de ces inits ne doit empêcher
  /// d'atteindre l'AuthGate.
  Future<void> _bestEffort(
    String label,
    Future<void> Function() init, {
    Duration timeout = const Duration(seconds: 6),
  }) async {
    try {
      await init().timeout(timeout);
    } catch (e) {
      debugPrint('Splash init "$label" ignorée (non bloquante): $e');
    }
  }

  Future<void> _initializeAndNavigate() async {
    final minDelay = Future.delayed(const Duration(milliseconds: 2500));

    // Initialize WebView platform
    if (WebViewPlatform.instance == null) {
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        WebViewPlatform.instance = WebKitWebViewPlatform();
      } else if (defaultTargetPlatform == TargetPlatform.android) {
        WebViewPlatform.instance = AndroidWebViewPlatform();
      }
    }

    // Initialize Supabase
    // Vrai check (pas un assert) : un build release sans dart-defines doit
    // échouer bruyamment au splash plutôt que produire une app où toute
    // l'auth casse silencieusement ("No host specified in URI" — cf. incident
    // AAB 1.0.5+11 d'août 2026).
    if (Env.supabaseUrl.isEmpty || Env.supabaseAnonKey.isEmpty) {
      throw StateError(
          'SUPABASE_URL / SUPABASE_ANON_KEY manquants — build lancé sans '
          '--dart-define-from-file=env.json');
    }
    // Critique (l'app est inutilisable sans) mais 100% local : pas de réseau
    // dans initialize(), ne peut pas pendre.
    await Supabase.initialize(
      url: Env.supabaseUrl,
      anonKey: Env.supabaseAnonKey,
    );

    // Inits non critiques : best-effort, jamais bloquantes.
    //
    // Fix 2026-09-28 : ces 4 inits étaient auparavant awaitées l'une après
    // l'autre (jusqu'à 4 × 6s de timeout bout à bout, ~24s pire cas, avant
    // même d'atteindre l'écran de connexion — cf. audit friction du 18/08,
    // même défaut que les 3 vérifications de badges corrigées le 26/09 en
    // fin de session). On les lance toutes en même temps : le temps
    // d'attente réel devient le plus lent des quatre, pas leur somme.
    final nonCriticalInits = <Future<void>>[
      _bestEffort('posthog', () => AnalyticsService().init()),
      _bestEffort('revenuecat', () => SubscriptionService().initialize()),
    ];
    if (!kIsWeb) {
      nonCriticalInits.add(_bestEffort(
          'notifications', () => MonthlyNotificationService().initialize()));
      nonCriticalInits
          .add(_bestEffort('widget', () => WidgetService().initialize()));
    }
    await Future.wait(nonCriticalInits);

    // Doit venir après `Supabase.initialize` : émet signup_completed /
    // login_succeeded depuis un point unique, quel que soit le fournisseur.
    AnalyticsService().attachAuthListener();

    if (!kIsWeb) {
      // La mise à jour avec les vraies données se fera après l'auth
      // (via AuthGate ou la page d'accueil)
      // Démarre le pont Apple Watch (no-op hors iOS / sans Watch appairée).
      try {
        WatchControlService().start();
      } catch (e) {
        debugPrint('WatchControlService.start ignoré: $e');
      }
    }

    // Initialize deep link handling (Notion OAuth + book links)
    try {
      DeepLinkService().init();
    } catch (e) {
      debugPrint('DeepLinkService.init ignoré: $e');
    }

    // Wait for minimum splash duration
    await minDelay;

    if (!mounted) return;

    // Navigate with fade transition
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const AuthGate(),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }


  @override
  void dispose() {
    _logoController.dispose();
    _titleController.dispose();
    _subtitleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F1EB),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Logo bookmark
            SlideTransition(
              position: _logoSlide,
              child: FadeTransition(
                opacity: _logoFade,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: SvgPicture.asset(
                    _logoAsset,
                    height: 120,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Title "LexDay"
            SlideTransition(
              position: _titleSlide,
              child: FadeTransition(
                opacity: _titleFade,
                child: const Text(
                  'LexDay',
                  style: TextStyle(
                    fontFamily: 'Cormorant Garamond',
                    fontWeight: FontWeight.w300,
                    fontSize: 32,
                    letterSpacing: 6,
                    color: Color(0xFF2A2520),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Subtitle
            SlideTransition(
              position: _subtitleSlide,
              child: FadeTransition(
                opacity: _subtitleFade,
                child: const Text(
                  'UNE PAGE. CHAQUE JOUR.',
                  style: TextStyle(
                    fontFamily: 'DM Sans',
                    fontWeight: FontWeight.w300,
                    fontSize: 12,
                    letterSpacing: 2.4, // 0.2em ≈ 12 * 0.2
                    color: Color(0xFF6B6460),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
