import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final SupabaseClient _supabase = Supabase.instance.client;

  String? _fcmToken;
  String? get fcmToken => _fcmToken;

  // Initialiser le service de notifications
  Future<void> initialize() async {
    try {
      // Demander la permission pour les notifications
      NotificationSettings settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        debugPrint('✅ Permission de notification accordée');

        // Obtenir le token FCM
        _fcmToken = await _messaging.getToken();
        debugPrint('📱 FCM Token: $_fcmToken');

        // Sauvegarder le token dans Supabase
        if (_fcmToken != null) {
          await _saveFcmTokenToDatabase(_fcmToken!);
        }

        // Écouter les changements de token
        _messaging.onTokenRefresh.listen(_saveFcmTokenToDatabase);

        // Configurer les handlers de messages
        _setupMessageHandlers();
      } else {
        debugPrint('❌ Permission de notification refusée');
      }
    } catch (e) {
      debugPrint('❌ Erreur lors de l\'initialisation des notifications: $e');
    }
  }

  // Sauvegarder le token FCM dans la base de données
  Future<void> _saveFcmTokenToDatabase(String token) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      await _supabase.from('users').update({
        'fcm_token': token,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', userId);

      debugPrint('✅ Token FCM sauvegardé dans la base de données');
    } catch (e) {
      debugPrint('❌ Erreur lors de la sauvegarde du token FCM: $e');
    }
  }

  // Configurer les handlers pour les messages
  void _setupMessageHandlers() {
    // Message reçu quand l'app est au premier plan
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('📬 Message reçu (app au premier plan)');
      debugPrint('Titre: ${message.notification?.title}');
      debugPrint('Corps: ${message.notification?.body}');

      // Vous pouvez afficher une notification locale ici si besoin
      _handleMessage(message);
    });

    // Message cliqué quand l'app est en arrière-plan
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('📬 Message cliqué (app en arrière-plan)');
      _handleMessage(message);
    });

    // Vérifier si l'app a été ouverte depuis une notification
    _messaging.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        debugPrint('📬 App ouverte depuis une notification');
        _handleMessage(message);
      }
    });
  }

  // Gérer les actions quand une notification est reçue/cliquée
  void _handleMessage(RemoteMessage message) {
    // Extraire les données de la notification
    final data = message.data;

    if (data['type'] == 'streak_reminder') {
      // Rediriger vers la page de lecture ou la home
      debugPrint('🔥 Notification de rappel de streak');
      // TODO: Navigation vers la page appropriée
    }
  }

  // Mettre à jour les préférences de notification de l'utilisateur
  Future<void> updateNotificationPreferences({
    required bool enabled,
    String? reminderTime, // Format: "HH:mm" (ex: "20:00")
  }) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      await _supabase.from('users').update({
        'notifications_enabled': enabled,
        if (reminderTime != null) 'notification_reminder_time': reminderTime,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', userId);

      debugPrint('✅ Préférences de notification mises à jour');
    } catch (e) {
      debugPrint('❌ Erreur lors de la mise à jour des préférences: $e');
    }
  }

  // Supprimer le token FCM (lors de la déconnexion)
  Future<void> clearFcmToken() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      await _supabase.from('users').update({
        'fcm_token': null,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', userId);

      await _messaging.deleteToken();
      _fcmToken = null;

      debugPrint('✅ Token FCM supprimé');
    } catch (e) {
      debugPrint('❌ Erreur lors de la suppression du token FCM: $e');
    }
  }

  // Tester l'envoi d'une notification (pour debug)
  Future<void> testNotification() async {
    debugPrint('🧪 Test de notification - Token: $_fcmToken');
    // Le token sera utilisé par votre backend pour envoyer une notification test
  }
}
