// lib/services/kindle_background_sync.dart
//
// Palier 2 du « rien à faire » : sync de la progression Kindle SANS ouvrir
// l'app, via workmanager (BGAppRefreshTask sur iOS, WorkManager périodique
// sur Android). Tout est du HTTP + cookies ([KindleHttpSync]) : aucune
// WebView n'est nécessaire dans l'isolate headless.
//
// Limites assumées : iOS décide seul quand il exécute la tâche (souvent
// toutes les quelques heures, seulement si l'app est utilisée régulièrement,
// jamais garanti) ; budget ≈ 30 s par exécution. Android : périodique, 15 min
// minimum, on demande 1 h.
//
// Partage avec le premier plan : même espacement (`kindle_last_progress_sync`),
// mêmes portes (Kindle connecté, auto-sync activé), même import
// (`importKindleBooks` → sessions). Premium vérifié en base
// (`profiles.is_premium`), le provider n'existant pas ici.
import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:workmanager/workmanager.dart';

import '../config/env.dart';
import '../l10n/app_localizations.dart';
import 'kindle_auto_sync_service.dart';
import 'kindle_cookie_store.dart';
import 'kindle_http_sync.dart';

/// Identifiant de tâche. Doit figurer dans Info.plist
/// (`BGTaskSchedulerPermittedIdentifiers`) et être enregistré dans
/// AppDelegate (`WorkmanagerPlugin.registerPeriodicTask`).
const String kKindleProgressTaskId = 'fr.lexday.app.kindleProgress';

/// Sur iOS (workmanager 0.7, vérifié dans SwiftWorkmanagerPlugin.swift), la
/// BGAppRefreshTaskRequest est soumise avec le **uniqueName**, pas le
/// taskName : il doit donc être l'identifiant autorisé par Info.plist.
const String _uniqueName = kKindleProgressTaskId;

/// Point d'entrée de l'isolate headless. Annoté pour survivre au tree-shaking.
@pragma('vm:entry-point')
void kindleBackgroundDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task != kKindleProgressTaskId && task != Workmanager.iOSBackgroundTask) {
      return true;
    }
    try {
      await KindleBackgroundSync.runOnce();
    } catch (e) {
      debugPrint('KindleBackgroundSync: échec $e');
    }
    // Toujours `true` : un `false` ferait retenter WorkManager avec backoff,
    // alors qu'on gère nous-mêmes l'espacement.
    return true;
  });
}

class KindleBackgroundSync {
  static bool _initialized = false;

  /// À appeler au premier plan quand le mini-sync est pertinent (Kindle
  /// connecté + auto-sync actif) : enregistre la tâche périodique. Idempotent
  /// (`ExistingWorkPolicy.keep`).
  static Future<void> ensureScheduled() async {
    if (kIsWeb) return;
    try {
      if (!_initialized) {
        await Workmanager().initialize(
          kindleBackgroundDispatcher,
          isInDebugMode: false,
        );
        _initialized = true;
      }
      await Workmanager().registerPeriodicTask(
        _uniqueName,
        kKindleProgressTaskId,
        frequency: const Duration(hours: 1),
        existingWorkPolicy: ExistingWorkPolicy.keep,
        constraints: Constraints(networkType: NetworkType.connected),
        backoffPolicy: BackoffPolicy.linear,
        backoffPolicyDelay: const Duration(minutes: 30),
      );
      debugPrint('KindleBackgroundSync: tâche périodique enregistrée');
    } catch (e) {
      debugPrint('KindleBackgroundSync: enregistrement KO: $e');
    }
  }

  /// Déconnexion Kindle / opt-out : plus de tâche, plus de cookies en cache.
  static Future<void> cancel() async {
    if (kIsWeb) return;
    try {
      if (!_initialized) {
        await Workmanager().initialize(kindleBackgroundDispatcher);
        _initialized = true;
      }
      await Workmanager().cancelByUniqueName(_uniqueName);
    } catch (e) {
      debugPrint('KindleBackgroundSync: annulation KO: $e');
    }
    await KindleCookieStore.clear();
  }

  /// Une exécution complète dans l'isolate headless.
  static Future<void> runOnce() async {
    DartPluginRegistrant.ensureInitialized();

    if (Env.supabaseUrl.isEmpty || Env.supabaseAnonKey.isEmpty) return;
    try {
      await Supabase.initialize(
        url: Env.supabaseUrl,
        anonKey: Env.supabaseAnonKey,
      );
    } catch (_) {
      // Déjà initialisé dans cet isolate : on continue.
    }
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      debugPrint('KindleBackgroundSync: pas de session utilisateur, skip');
      return;
    }

    // Premium en base (pas de provider ici).
    bool premium = false;
    try {
      final row = await Supabase.instance.client
          .from('profiles')
          .select('is_premium')
          .eq('id', user.id)
          .maybeSingle();
      premium = row?['is_premium'] == true;
    } catch (e) {
      debugPrint('KindleBackgroundSync: lecture premium KO: $e');
      return;
    }

    final gate = KindleAutoSyncService();
    if (!await gate.shouldProgressSync(isPremium: premium)) return;

    final cookies = await KindleCookieStore.cachedHeader();
    if (cookies == null) {
      debugPrint('KindleBackgroundSync: pas de cookies en cache, skip');
      return;
    }

    await gate.recordProgressAttempt();
    final result = await KindleHttpSync(cookieHeader: cookies).run();
    debugPrint(
      'KindleBackgroundSync: ${result.booksFetched} livres, '
      '${result.withProgress} avec progression, '
      '${result.sessionsCreated} session(s)'
      '${result.sessionExpired ? ', session Amazon expirée' : ''}'
      '${result.error != null ? ', erreur: ${result.error}' : ''}',
    );

    if (result.sessionsCreated > 0) {
      await _notify(result.sessionsCreated);
    }
  }

  static Future<void> _notify(int count) async {
    try {
      final plugin = FlutterLocalNotificationsPlugin();
      await plugin.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
      );
      final locale = _localeFromPlatform();
      final l10n = lookupAppLocalizations(locale);
      await plugin.show(
        90210,
        'LexDay',
        l10n.kindleSessionsAdded(count),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'kindle_sync',
            'Kindle',
            channelDescription: 'Synchronisation Kindle',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
            icon: '@mipmap/ic_launcher',
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: false,
            presentSound: false,
          ),
        ),
        payload: 'kindle_sessions',
      );
    } catch (e) {
      debugPrint('KindleBackgroundSync: notification KO: $e');
    }
  }

  /// Locale système → une des locales supportées (fr par défaut, comme
  /// `preferred-supported-locales` de l10n.yaml).
  static Locale _localeFromPlatform() {
    final code = Platform.localeName.split(RegExp('[_-]')).first.toLowerCase();
    for (final l in AppLocalizations.supportedLocales) {
      if (l.languageCode == code) return l;
    }
    return const Locale('fr');
  }
}
