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
//
// ⚠️ Session Supabase : LECTURE SEULE dans cet isolate (fix 05/10/2026).
// `Supabase.initialize()` avec les options par défaut relisait la session
// persistée et, si le JWT (1 h) était expiré, la RAFRAÎCHISSAIT ici. Les
// refresh tokens Supabase tournent à chaque usage : l'app au premier plan,
// qui gardait l'ancien token en mémoire, échouait à son propre refresh au
// retour (« Invalid Refresh Token: Already Used »), gotrue supprimait alors
// la session (`_removeSession` + `signedOut`) et supabase_flutter effaçait
// la session persistée. Résultat vécu : utilisateur connecté/premium, mais
// `currentUser == null` → murs « Crée un compte » partout, puis écran de
// connexion au lancement suivant. Ici on ne rafraîchit JAMAIS : JWT encore
// valide → on l'utilise tel quel ; expiré → on saute l'exécution.
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

  /// Clé SharedPreferences où supabase_flutter persiste la session — même
  /// formule que `Supabase.initialize` quand aucun `localStorage` n'est
  /// fourni (`supabase.dart`, 2.10.x).
  static String get _sessionPrefsKey =>
      'sb-${Uri.parse(Env.supabaseUrl).host.split('.').first}-auth-token';

  /// Marge sous laquelle on ne lance pas la sync : un JWT qui expire pendant
  /// l'exécution ferait échouer les inserts, sans qu'on puisse (ni veuille)
  /// le rafraîchir ici.
  static const _minJwtValidity = Duration(minutes: 2);

  /// Session persistée par l'app, si son JWT est encore valide. Retourne le
  /// JSON tel que stocké (celui que `setInitialSession` attend), sinon null.
  static Future<String?> _readValidSessionJson() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_sessionPrefsKey);
    if (raw == null || raw.isEmpty) return null;
    final exp = _jwtExpiry(raw);
    if (exp == null) return null;
    final remaining = exp.difference(DateTime.now());
    if (remaining < _minJwtValidity) {
      debugPrint(
        'KindleBackgroundSync: JWT expiré ou presque '
        '(${remaining.inSeconds}s), skip — jamais de refresh ici',
      );
      return null;
    }
    return raw;
  }

  /// Date d'expiration du JWT contenu dans la session persistée (claim `exp`
  /// de l'access token ; `expires_at` en secours). Null si illisible.
  static DateTime? _jwtExpiry(String sessionJson) {
    try {
      var map = jsonDecode(sessionJson) as Map<String, dynamic>;
      // Ancien format supabase_flutter 1.x : {"currentSession": {...}}.
      if (map['currentSession'] is Map<String, dynamic>) {
        map = map['currentSession'] as Map<String, dynamic>;
      }
      final token = map['access_token'] as String?;
      if (token != null) {
        final parts = token.split('.');
        if (parts.length == 3) {
          final payload = jsonDecode(
            utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
          ) as Map<String, dynamic>;
          final exp = payload['exp'];
          if (exp is int) {
            return DateTime.fromMillisecondsSinceEpoch(exp * 1000);
          }
        }
      }
      final expiresAt = map['expires_at'];
      if (expiresAt is int) {
        return DateTime.fromMillisecondsSinceEpoch(expiresAt * 1000);
      }
    } catch (e) {
      debugPrint('KindleBackgroundSync: session persistée illisible: $e');
    }
    return null;
  }

  /// Une exécution complète dans l'isolate headless.
  static Future<void> runOnce() async {
    DartPluginRegistrant.ensureInitialized();

    if (Env.supabaseUrl.isEmpty || Env.supabaseAnonKey.isEmpty) return;

    final sessionJson = await _readValidSessionJson();
    if (sessionJson == null) {
      debugPrint('KindleBackgroundSync: pas de session valide, skip');
      return;
    }

    try {
      await Supabase.initialize(
        url: Env.supabaseUrl,
        anonKey: Env.supabaseAnonKey,
        authOptions: FlutterAuthClientOptions(
          // Jamais de refresh dans l'isolate (cf. en-tête).
          autoRefreshToken: false,
          // Et jamais d'écriture/suppression de la session persistée : seule
          // l'app au premier plan en est propriétaire.
          localStorage: _ReadOnlySessionStorage(sessionJson),
        ),
      );
    } catch (_) {
      // Déjà initialisé dans cet isolate (réutilisé par workmanager) : on
      // recharge simplement la session la plus récente écrite par l'app,
      // sans réseau.
      try {
        await Supabase.instance.client.auth.setInitialSession(sessionJson);
      } catch (e) {
        debugPrint('KindleBackgroundSync: setInitialSession KO: $e');
        return;
      }
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

/// Stockage de session en lecture seule pour l'isolate headless : expose la
/// session persistée par l'app, ignore toute écriture ou suppression.
/// Sans lui, supabase_flutter réécrit la session à chaque `initialSession` /
/// `tokenRefreshed` et l'efface sur `signedOut` — depuis un isolate qui n'a
/// pas à toucher à la session de l'app.
class _ReadOnlySessionStorage extends LocalStorage {
  const _ReadOnlySessionStorage(this._sessionJson);

  final String _sessionJson;

  @override
  Future<void> initialize() async {}

  @override
  Future<bool> hasAccessToken() async => true;

  @override
  Future<String?> accessToken() async => _sessionJson;

  @override
  Future<void> persistSession(String persistSessionString) async {}

  @override
  Future<void> removePersistedSession() async {}
}
