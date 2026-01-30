import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';
import 'app.dart';

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
  await Supabase.initialize(
    url: 'https://nzbhmshkcwudzydeahrq.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im56Ymhtc2hrY3d1ZHp5ZGVhaHJxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjE1NTk0NDksImV4cCI6MjA3NzEzNTQ0OX0.oE5vXlZjT89q13wpj1y_B_OwZ_rQd2VNKC0OgEuRGwM',
  );

  // Initialiser le service de notifications
  // Sera fait après la connexion de l'utilisateur

  runApp(const ReadOnApp());
}