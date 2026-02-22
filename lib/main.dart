import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
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

  // Initialiser les notifications mensuelles (monthly wrapped) — pas sur le web
  if (!kIsWeb) {
    await MonthlyNotificationService().initialize();
  }

  await updateWidget();

  runApp(const LexDayApp());
}

Future<void> updateWidget() async {
  await HomeWidget.setAppGroupId('group.com.acoeffic.readon');

  // Remplace ces valeurs par tes vraies données depuis Supabase/local storage
  await HomeWidget.saveWidgetData<String>('currentBook', 'Ton livre en cours');
  await HomeWidget.saveWidgetData<String>('currentAuthor', 'Auteur');
  await HomeWidget.saveWidgetData<int>('todayMinutes', 0);
  await HomeWidget.saveWidgetData<int>('streak', 0);
  await HomeWidget.saveWidgetData<double>('progressPercent', 0.0);

  await HomeWidget.updateWidget(name: 'LexDayWidget');
}