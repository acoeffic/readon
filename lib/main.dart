import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app.dart';
import 'services/notification_service.dart';

// Handler pour les messages en arrière-plan
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('📬 Message reçu en arrière-plan: ${message.notification?.title}');
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialiser Firebase
  await Firebase.initializeApp();

  // Configurer le handler pour les messages en arrière-plan
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

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