import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';
import 'app.dart';
import 'config/env.dart';
import 'services/subscription_service.dart';
import 'services/monthly_notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialiser la plateforme WebView
  if (WebViewPlatform.instance == null) {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      WebViewPlatform.instance = WebKitWebViewPlatform();
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      WebViewPlatform.instance = AndroidWebViewPlatform();
    }
  }

  // Initialiser Supabase
  assert(Env.supabaseUrl.isNotEmpty, 'SUPABASE_URL manquant — utiliser --dart-define-from-file=env.json');
  assert(Env.supabaseAnonKey.isNotEmpty, 'SUPABASE_ANON_KEY manquant');
  await Supabase.initialize(
    url: Env.supabaseUrl,
    anonKey: Env.supabaseAnonKey,
  );

  // Initialiser RevenueCat
  await SubscriptionService().initialize();

  // Initialiser les notifications mensuelles (monthly wrapped)
  await MonthlyNotificationService().initialize();

  runApp(const LexstaApp());
}