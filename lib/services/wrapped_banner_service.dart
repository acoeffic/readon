// services/wrapped_banner_service.dart
// Gère l'état persistant de la bannière "Wrapped mensuel" dans le feed.
//
// Quand une notification de wrapped arrive (FCM ou cold start), on enregistre
// le mois/année + un timestamp `available_until` (= now + 24 h). La FeedPage
// lit cet état et affiche une bannière cliquable tant qu'elle n'est ni expirée
// ni explicitement fermée par l'utilisateur.
//
// La bannière est persistée via SharedPreferences (donc survit aux redémarrages
// de l'app), mais expire seule au bout de 24 h.

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WrappedBannerData {
  final int month;
  final int year;
  final DateTime availableUntil;

  const WrappedBannerData({
    required this.month,
    required this.year,
    required this.availableUntil,
  });

  bool get isExpired => DateTime.now().isAfter(availableUntil);
}

class WrappedBannerService {
  WrappedBannerService._();
  static final WrappedBannerService _instance = WrappedBannerService._();
  factory WrappedBannerService() => _instance;

  static const _kMonth = 'wrapped_banner_month';
  static const _kYear = 'wrapped_banner_year';
  static const _kAvailableUntil = 'wrapped_banner_available_until';
  static const _kDismissedKey = 'wrapped_banner_dismissed_key';

  /// Notifie les écouteurs (ex: FeedPage) qu'un nouveau wrapped est dispo.
  /// Incrémenté chaque fois que `setPending` est appelé.
  static final ValueNotifier<int> changes = ValueNotifier<int>(0);

  /// Durée de vie de la bannière dans le feed (1 jour).
  static const Duration ttl = Duration(days: 1);

  String _key(int month, int year) => '$month-$year';

  /// Marque un wrapped comme "à voir" — affiche la bannière pour 24 h.
  /// Si appelé pour un (month, year) déjà fermé manuellement, ré-affiche
  /// (cas où l'utilisateur tape à nouveau la notif).
  Future<void> setPending({required int month, required int year}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final until = DateTime.now().add(ttl);

      await prefs.setInt(_kMonth, month);
      await prefs.setInt(_kYear, year);
      await prefs.setString(_kAvailableUntil, until.toIso8601String());
      // Reset dismissed pour ce wrapped — un re-tap doit ré-afficher.
      final dismissed = prefs.getString(_kDismissedKey);
      if (dismissed == _key(month, year)) {
        await prefs.remove(_kDismissedKey);
      }

      changes.value++;
      debugPrint('WrappedBanner: set pending $month/$year until $until');
    } catch (e) {
      debugPrint('WrappedBanner setPending error: $e');
    }
  }

  /// Lit l'état courant. Retourne null si :
  ///   - aucun wrapped n'est enregistré,
  ///   - la fenêtre de 24 h est dépassée,
  ///   - l'utilisateur a fermé la bannière manuellement.
  Future<WrappedBannerData?> getPending() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final month = prefs.getInt(_kMonth);
      final year = prefs.getInt(_kYear);
      final untilStr = prefs.getString(_kAvailableUntil);

      if (month == null || year == null || untilStr == null) return null;

      final until = DateTime.tryParse(untilStr);
      if (until == null) return null;

      final data = WrappedBannerData(
        month: month,
        year: year,
        availableUntil: until,
      );

      if (data.isExpired) {
        // Nettoyage silencieux des clés expirées.
        await _clearKeys(prefs);
        return null;
      }

      // Si l'utilisateur a fermé cette bannière, on la masque.
      final dismissed = prefs.getString(_kDismissedKey);
      if (dismissed == _key(month, year)) return null;

      return data;
    } catch (e) {
      debugPrint('WrappedBanner getPending error: $e');
      return null;
    }
  }

  /// L'utilisateur ferme la bannière — on la masque jusqu'à la prochaine
  /// notification (un nouveau `setPending` la ré-affichera).
  Future<void> dismiss() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final month = prefs.getInt(_kMonth);
      final year = prefs.getInt(_kYear);
      if (month == null || year == null) return;
      await prefs.setString(_kDismissedKey, _key(month, year));
      changes.value++;
    } catch (e) {
      debugPrint('WrappedBanner dismiss error: $e');
    }
  }

  Future<void> _clearKeys(SharedPreferences prefs) async {
    await prefs.remove(_kMonth);
    await prefs.remove(_kYear);
    await prefs.remove(_kAvailableUntil);
    await prefs.remove(_kDismissedKey);
  }

  /// Auto-armement : si on est dans la fenêtre "début de mois" (jours 1-2),
  /// arme la bannière pour le mois précédent — sauf si l'utilisateur l'a
  /// déjà fermée manuellement, ou si elle est déjà armée et active.
  ///
  /// Appelé au montage de FeedPage : la bannière apparaîtra même sans tap
  /// sur la notif (notif ratée, désactivée, etc.).
  Future<void> maybeAutoArmForPreviousMonth() async {
    try {
      final now = DateTime.now();
      // Fenêtre d'auto-armement : jours 1-2 du mois (laisse 48 h pour ouvrir
      // l'app après la notification).
      if (now.day > 2) return;

      final prevMonth = now.month == 1 ? 12 : now.month - 1;
      final prevYear = now.month == 1 ? now.year - 1 : now.year;

      final prefs = await SharedPreferences.getInstance();

      // Si l'utilisateur a déjà fermé cette bannière → on respecte.
      final dismissed = prefs.getString(_kDismissedKey);
      if (dismissed == _key(prevMonth, prevYear)) return;

      // Si déjà armée pour le bon mois et non expirée → ne rien faire.
      final existingMonth = prefs.getInt(_kMonth);
      final existingYear = prefs.getInt(_kYear);
      final untilStr = prefs.getString(_kAvailableUntil);
      if (existingMonth == prevMonth &&
          existingYear == prevYear &&
          untilStr != null) {
        final until = DateTime.tryParse(untilStr);
        if (until != null && DateTime.now().isBefore(until)) return;
      }

      await setPending(month: prevMonth, year: prevYear);
      debugPrint('WrappedBanner: auto-armed for $prevMonth/$prevYear');
    } catch (e) {
      debugPrint('WrappedBanner maybeAutoArm error: $e');
    }
  }

  /// Effacement complet (à appeler sur sign-out par exemple).
  Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await _clearKeys(prefs);
      changes.value++;
    } catch (e) {
      debugPrint('WrappedBanner clear error: $e');
    }
  }
}
