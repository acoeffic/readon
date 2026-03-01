import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:home_widget/home_widget.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

import '../../config/env.dart';
import '../../services/subscription_service.dart';
import '../../services/monthly_notification_service.dart';
import '../auth/auth_gate.dart';

const _bookmarkSvg = '''
<svg viewBox="0 0 28 38" fill="none" xmlns="http://www.w3.org/2000/svg">
  <path d="M6 0 H22 C25.31 0 28 2.69 28 6 V35.5 C28 36.8 26.4 37.5 25.4 36.6 L14.6 27.2 C14.26 26.9 13.74 26.9 13.4 27.2 L2.6 36.6 C1.6 37.5 0 36.8 0 35.5 V6 C0 2.69 2.69 0 6 0 Z" fill="#6B988D"/>
</svg>
''';

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
    assert(Env.supabaseUrl.isNotEmpty,
        'SUPABASE_URL manquant — utiliser --dart-define-from-file=env.json');
    assert(Env.supabaseAnonKey.isNotEmpty, 'SUPABASE_ANON_KEY manquant');
    await Supabase.initialize(
      url: Env.supabaseUrl,
      anonKey: Env.supabaseAnonKey,
    );

    // Initialize RevenueCat
    await SubscriptionService().initialize();

    // Initialize monthly notifications
    if (!kIsWeb) {
      await MonthlyNotificationService().initialize();
    }

    if (!kIsWeb) {
      await _updateWidget();
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

  Future<void> _updateWidget() async {
    await HomeWidget.setAppGroupId('group.com.acoeffic.lexday');
    await HomeWidget.saveWidgetData<String>('currentBook', 'Ton livre en cours');
    await HomeWidget.saveWidgetData<String>('currentAuthor', 'Auteur');
    await HomeWidget.saveWidgetData<int>('todayMinutes', 0);
    await HomeWidget.saveWidgetData<int>('streak', 0);
    await HomeWidget.saveWidgetData<double>('progressPercent', 0.0);
    await HomeWidget.updateWidget(name: 'LexDayWidget');
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
                child: SvgPicture.string(
                  _bookmarkSvg,
                  height: 72,
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
                  'YOUR READING LIFE, TRACKED',
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
