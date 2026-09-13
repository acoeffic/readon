import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'kindle_background_sync.dart';

class KindleAutoSyncService {
  static const String _lastSyncKey = 'kindle_last_sync';
  static const String _lastAttemptKey = 'kindle_last_attempt';
  static const String _failedAttemptsKey = 'kindle_failed_attempts';
  static const String _autoSyncEnabledKey = 'kindle_auto_sync_enabled';

  /// Une connexion Kindle vient d'aboutir mais les surlignages n'ont pas
  /// encore été récupérés. La synchro de première connexion
  /// (KindleLoginPage) n'a pas de phase highlights — elle pose pourtant
  /// `kindle_last_sync`, ce qui verrouillait l'auto-sync 24 h : un nouvel
  /// utilisateur ne voyait ses surlignages que le lendemain. Ce flag fait
  /// sauter le verrou (et le backoff) pour UNE tentative d'auto-sync.
  static const String _highlightsPendingKey = 'kindle_highlights_pending';

  /// Incrémenté par KindleLoginPage quand une connexion aboutit, écouté par
  /// MainNavigation pour déclencher l'auto-sync (donc les surlignages)
  /// immédiatement, sans attendre un passage en arrière-plan. Même pattern
  /// que `ReadingSessionService.activeSessionsVersion`.
  static final ValueNotifier<int> connectedVersion = ValueNotifier<int>(0);
  static void notifyConnected() => connectedVersion.value++;

  /// Ancien flag booléen (une notification d'expiration à vie). Conservé
  /// uniquement pour être purgé : il est remplacé par `_expiredNotifiedAtKey`.
  static const String _legacyExpiredNotifiedKey = 'kindle_expired_notified';
  static const String _expiredNotifiedAtKey = 'kindle_expired_notified_at';

  static const Duration _syncInterval = Duration(hours: 24);

  /// Après un échec (session expirée, réseau, layout Amazon changé), on ne
  /// retente pas avant ce délai. Sans ça, `shouldAutoSync` ne regardait que
  /// `kindle_last_sync` — écrit uniquement en cas de succès — donc un échec
  /// relançait une WebView cachée à chaque retour au premier plan.
  ///
  /// Le délai double à chaque échec consécutif (6 h → 12 h → 24 h → 48 h) pour
  /// qu'une panne durable (refonte d'Amazon, compte fermé) ne réveille pas une
  /// WebView deux fois par jour à vie.
  static const Duration _failureBackoff = Duration(hours: 6);
  static const int _maxBackoffDoublings = 3;

  /// Une session expirée est re-signalée à cet intervalle. Avant, la
  /// notification était unique « à vie » : un utilisateur qui ratait le
  /// SnackBar de 8 s n'était jamais réinvité à se reconnecter.
  static const Duration _expiredRenotifyInterval = Duration(days: 7);

  /// Vérifie si l'auto-sync doit se déclencher
  Future<bool> shouldAutoSync({required bool isPremium}) async {
    if (!isPremium) {
      debugPrint('KindleAutoSync: skip — pas premium');
      return false;
    }

    final prefs = await SharedPreferences.getInstance();

    // Kindle jamais connecté
    final lastSync = prefs.getString(_lastSyncKey);
    if (lastSync == null) {
      debugPrint('KindleAutoSync: skip — Kindle jamais connecté sur ce device');
      return false;
    }

    // Auto-sync désactivé par l'utilisateur
    final enabled = prefs.getBool(_autoSyncEnabledKey) ?? true;
    if (!enabled) {
      debugPrint('KindleAutoSync: skip — auto-sync désactivé par l\'utilisateur');
      return false;
    }

    // Surlignages en attente après une connexion : on saute le verrou 24 h
    // ET le backoff — les cookies viennent d'être posés par un login réussi,
    // la tentative a toutes ses chances. Le flag est consommé au démarrage du
    // widget d'auto-sync (une seule tentative garantie, pas de boucle).
    if (prefs.getBool(_highlightsPendingKey) ?? false) {
      debugPrint(
        'KindleAutoSync: surlignages en attente post-connexion, déclenchement',
      );
      return true;
    }

    // Dernier sync réussi trop récent (< 24h)
    try {
      final lastSyncDate = DateTime.parse(lastSync);
      final elapsed = DateTime.now().difference(lastSyncDate);
      if (elapsed < _syncInterval) {
        debugPrint(
            'KindleAutoSync: skip — dernier sync il y a ${elapsed.inHours}h (< 24h)');
        return false;
      }
    } catch (e) {
      debugPrint('KindleAutoSync: erreur parsing lastSync: $e');
      return false;
    }

    // Dernière TENTATIVE trop récente (backoff exponentiel sur échec)
    final lastAttempt = prefs.getString(_lastAttemptKey);
    if (lastAttempt != null) {
      try {
        final failures = prefs.getInt(_failedAttemptsKey) ?? 0;
        final doublings =
            failures <= 1 ? 0 : (failures - 1).clamp(0, _maxBackoffDoublings);
        final backoff = _failureBackoff * (1 << doublings);
        final elapsed = DateTime.now().difference(DateTime.parse(lastAttempt));
        if (elapsed < backoff) {
          debugPrint(
              'KindleAutoSync: skip — tentative il y a ${elapsed.inMinutes} min '
              '($failures échec(s), backoff ${backoff.inHours}h)');
          return false;
        }
      } catch (_) {
        // Valeur corrompue : on l'ignore plutôt que de bloquer le sync.
      }
    }

    debugPrint('KindleAutoSync: conditions remplies, déclenchement');
    return true;
  }

  /// Trace une tentative de sync. Appelé au démarrage du widget d'auto-sync,
  /// avant tout travail réseau : le compteur d'échecs est incrémenté d'emblée
  /// et remis à zéro par `recordSuccess()` en fin de pipeline.
  Future<void> recordAttempt() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastAttemptKey, DateTime.now().toIso8601String());
    await prefs.setInt(
      _failedAttemptsKey,
      (prefs.getInt(_failedAttemptsKey) ?? 0) + 1,
    );
  }

  /// Pose le flag « surlignages à récupérer » (appelé par KindleLoginPage
  /// après une connexion réussie).
  Future<void> markHighlightsPending() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_highlightsPendingKey, true);
  }

  /// Consomme le flag. Appelé au DÉMARRAGE de la tentative d'auto-sync (pas à
  /// sa réussite) : si la tentative échoue, on retombe sur le backoff normal
  /// au lieu de marteler Amazon à chaque retour au premier plan — les
  /// surlignages arriveront au sync suivant, l'import est idempotent.
  Future<void> clearHighlightsPending() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_highlightsPendingKey);
  }

  // ─── Mini-sync « progression seule » (palier 1 du « rien à faire ») ───
  //
  // Le sync complet (bibliothèque + streaks + surlignages) reste verrouillé
  // 24 h. La progression, elle, est un pur GET HTML par livre (~1 s) : on la
  // relance à chaque retour au premier plan, espacée d'au moins
  // [_progressSyncInterval], pour qu'une lecture Kindle de la veille soit
  // déjà en session quand l'utilisateur ouvre l'app.
  static const String _lastProgressSyncKey = 'kindle_last_progress_sync';
  static const Duration _progressSyncInterval = Duration(hours: 1);

  /// Faut-il lancer un mini-sync progression ? Mêmes portes que le sync
  /// complet (premium, Kindle connecté, auto-sync actif), puis l'espacement.
  /// À n'appeler que si [shouldAutoSync] a répondu non : le sync complet
  /// couvre déjà la progression.
  Future<bool> shouldProgressSync({required bool isPremium}) async {
    if (!isPremium) return false;
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString(_lastSyncKey) == null) return false;
    if (!(prefs.getBool(_autoSyncEnabledKey) ?? true)) return false;
    final last = prefs.getString(_lastProgressSyncKey);
    if (last != null) {
      final parsed = DateTime.tryParse(last);
      if (parsed != null) {
        final elapsed = DateTime.now().difference(parsed);
        if (elapsed < _progressSyncInterval) {
          debugPrint(
              'KindleAutoSync: progression — skip, dernière il y a ${elapsed.inMinutes} min');
          return false;
        }
      }
    }
    debugPrint('KindleAutoSync: progression — déclenchement');
    return true;
  }

  /// Horodate la tentative de mini-sync (succès ou échec : l'espacement
  /// vaut dans les deux cas, on ne martèle pas Amazon sur une session morte).
  Future<void> recordProgressAttempt() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _lastProgressSyncKey, DateTime.now().toIso8601String());
  }

  // ─── Crawl incrémental des surlignages ───
  //
  // Le notebook Amazon est relu livre par livre (fragments AJAX paginés) :
  // ~1 min pour 95 livres alors qu'un sync quotidien n'apporte des nouveautés
  // que sur les livres réellement lus. On ne recrawle donc que les livres dont
  // la progression a bougé depuis le sync précédent, plus ceux jamais crawlés
  // (nouveaux achats), et on refait un passage complet tous les
  // [_fullHighlightCrawlInterval] pour rattraper les surlignages posés sans
  // progression (relecture, livre déjà terminé).
  static const String _hlCrawledKey = 'kindle_hl_crawled';
  static const String _hlFullCrawlAtKey = 'kindle_hl_full_crawl_at';
  static const Duration _fullHighlightCrawlInterval = Duration(days: 7);

  /// ASIN déjà crawlés au moins une fois.
  Future<Set<String>> highlightCrawledAsins() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_hlCrawledKey) ?? const [];
    return list.toSet();
  }

  /// Un passage complet est-il dû (jamais fait, ou plus vieux que 7 jours) ?
  Future<bool> isFullHighlightCrawlDue() async {
    final prefs = await SharedPreferences.getInstance();
    final at = DateTime.tryParse(prefs.getString(_hlFullCrawlAtKey) ?? '');
    if (at == null) return true;
    return DateTime.now().difference(at) >= _fullHighlightCrawlInterval;
  }

  /// Mémorise les ASIN crawlés (fusion) ; `full` horodate le passage complet.
  Future<void> markHighlightsCrawled(Iterable<String> asins,
      {bool full = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final merged = (prefs.getStringList(_hlCrawledKey) ?? const []).toSet()
      ..addAll(asins);
    await prefs.setStringList(_hlCrawledKey, merged.toList());
    if (full) {
      await prefs.setString(
          _hlFullCrawlAtKey, DateTime.now().toIso8601String());
    }
  }

  /// Sync mené à son terme : on repart d'un backoff neuf.
  Future<void> recordSuccess() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_failedAttemptsKey);
    await prefs.remove(_lastAttemptKey);
  }

  /// L'utilisateur a-t-il déjà été prévenu récemment que sa session Kindle a
  /// expiré ? (pour ne pas spammer à chaque ouverture, tout en re-signalant
  /// le problème une fois par semaine tant qu'il persiste)
  Future<bool> hasNotifiedExpired() async {
    final prefs = await SharedPreferences.getInstance();
    final notifiedAt = prefs.getString(_expiredNotifiedAtKey);
    if (notifiedAt == null) return false;
    try {
      final elapsed = DateTime.now().difference(DateTime.parse(notifiedAt));
      return elapsed < _expiredRenotifyInterval;
    } catch (_) {
      return false;
    }
  }

  /// Marque l'expiration comme notifiée (horodatée).
  Future<void> markExpiredNotified() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _expiredNotifiedAtKey,
      DateTime.now().toIso8601String(),
    );
    await prefs.remove(_legacyExpiredNotifiedKey);
  }

  /// Réinitialise le flag (après un sync réussi ou une reconnexion).
  Future<void> clearExpiredNotified() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_expiredNotifiedAtKey);
    await prefs.remove(_legacyExpiredNotifiedKey);
  }

  /// Vérifie si l'auto-sync est activé dans les préférences
  Future<bool> isAutoSyncEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_autoSyncEnabledKey) ?? true;
  }

  /// Active/désactive l'auto-sync
  Future<void> setAutoSyncEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoSyncEnabledKey, enabled);
    // Le sync d'arrière-plan suit le même interrupteur.
    if (enabled) {
      await KindleBackgroundSync.ensureScheduled();
    } else {
      await KindleBackgroundSync.cancel();
    }
  }

  /// Kindle connecté sur ce device ET auto-sync activé : les deux portes
  /// communes au sync complet, au mini-sync et à la tâche d'arrière-plan.
  Future<bool> isBackgroundSyncEligible() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString(_lastSyncKey) == null) return false;
    return prefs.getBool(_autoSyncEnabledKey) ?? true;
  }

  /// Vérifie si le Kindle a déjà été connecté
  Future<bool> isKindleConnected() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_lastSyncKey) != null;
  }

  /// Supprime la préférence d'auto-sync pour que la prochaine reconnexion
  /// reparte sur la valeur par défaut (activé).
  Future<void> clearPreference() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_autoSyncEnabledKey);
    await prefs.remove(_hlCrawledKey);
    await prefs.remove(_hlFullCrawlAtKey);
    await prefs.remove(_lastAttemptKey);
    await prefs.remove(_failedAttemptsKey);
    await prefs.remove(_highlightsPendingKey);
  }
}
