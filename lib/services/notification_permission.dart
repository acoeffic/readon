// lib/services/notification_permission.dart
//
// Lecture **non intrusive** du statut de la permission notifications.
//
// Pourquoi un helper partagé : deux plugins demandent la même autorisation
// système (`firebase_messaging` pour le push, `flutter_local_notifications`
// pour les rappels locaux et le Wrapped mensuel). Sur iOS ils tapent tous les
// deux dans `UNUserNotificationCenter`, sur Android 13+ dans la même
// permission `POST_NOTIFICATIONS`. Il n'y a donc qu'**une seule** popup
// système, et elle n'est présentée qu'**une seule fois** dans la vie de
// l'app : le premier qui la déclenche a consommé la cartouche.
//
// D'où la règle : personne n'appelle `requestPermission()` en marge. Les deux
// services *lisent* le statut via ce helper et se contentent de ne rien
// planifier tant que la permission n'est pas accordée. Le seul point qui
// présente la popup est `PushNotificationService.promptPermissionAndRegister()`,
// appelé après la première session de lecture terminée.
//
// L'implémentation s'appuie sur `firebase_messaging.getNotificationSettings()`,
// qui ne présente jamais de popup et reflète l'état réel côté OS, quel que
// soit le plugin qui l'a obtenu.

import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Mémorise qu'on a présenté la popup, indépendamment de la réponse.
///
/// ⚠️ Indispensable pour Android : contrairement à iOS, Android ne connaît pas
/// `notDetermined`. `getNotificationSettings()` y renvoie `denied` aussi bien
/// pour « jamais demandé » que pour « refusé ». Sans ce drapeau, un garde du
/// type `status == notDetermined` empêcherait la popup de s'afficher **une
/// seule fois** sur Android — c'est-à-dire jamais.
const _kPromptShownKey = 'notification_prompt_shown';

/// Statut courant, sans jamais présenter de popup.
Future<AuthorizationStatus> notificationPermissionStatus() async {
  if (kIsWeb) return AuthorizationStatus.denied;
  try {
    final settings = await FirebaseMessaging.instance.getNotificationSettings();
    return settings.authorizationStatus;
  } catch (e) {
    debugPrint('notificationPermissionStatus error: $e');
    return AuthorizationStatus.notDetermined;
  }
}

/// `true` si les notifications sont autorisées (ou provisoirement autorisées).
Future<bool> hasNotificationPermission() async {
  final status = await notificationPermissionStatus();
  return status == AuthorizationStatus.authorized ||
      status == AuthorizationStatus.provisional;
}

/// `true` si la popup a déjà été présentée au moins une fois sur cet appareil.
Future<bool> notificationPromptAlreadyShown() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kPromptShownKey) == true;
  } catch (e) {
    debugPrint('notificationPromptAlreadyShown error: $e');
    return false;
  }
}

/// À appeler juste après avoir présenté la popup, quelle que soit la réponse.
Future<void> markNotificationPromptShown() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kPromptShownKey, true);
  } catch (e) {
    debugPrint('markNotificationPromptShown error: $e');
  }
}

/// `true` s'il reste une cartouche à tirer : permission pas encore accordée et
/// popup jamais présentée.
///
/// Le raisonnement diffère par plateforme :
///   * **iOS** expose un vrai `notDetermined`. On s'en sert en plus du drapeau
///     local : ça évite un appel inutile quand l'utilisateur a déjà refusé sur
///     une version antérieure de l'app (iOS ne réafficherait pas la popup).
///   * **Android** ne distingue pas « jamais demandé » de « refusé ». Seul le
///     drapeau local fait foi, sinon on ne demanderait jamais rien.
Future<bool> canStillAskNotificationPermission() async {
  if (kIsWeb) return false;
  if (await hasNotificationPermission()) return false;
  if (await notificationPromptAlreadyShown()) return false;

  if (Platform.isIOS) {
    return await notificationPermissionStatus() ==
        AuthorizationStatus.notDetermined;
  }
  return true;
}
