// lib/services/first_session_goal_offer.dart
//
// Offre d'objectif de lecture faite UNE fois, juste après la toute première
// session terminée (carte « Fixe-toi un petit objectif » de
// ReadingSessionSummaryPage).
//
// Pourquoi (audit rétention du 29/09/2026) : parmi les lecteurs qui restent
// au moins 4 jours, 9 sur 17 ont un objectif de lecture, et 7 de ces 9 l'ont
// posé dès le jour 0-1. Aujourd'hui l'objectif n'est proposé que par une carte
// discrète du feed : personne ne le voit au moment où l'envie est la plus
// forte. Corrélation, pas preuve — d'où l'instrumentation PostHog.
//
// Ce service porte trois choses :
//   * le drapeau « offre en attente », posé par EndReadingSessionPage à la fin
//     de la première session et consommé par la page de résumé ;
//   * les trois préréglages proposés ;
//   * la création de l'objectif (GoalsService.saveAllGoals).
//
// ⚠️ Lien avec la popup système de notifications : elle était tirée juste
// après la première session, avant le résumé. Quand l'offre est en attente,
// c'est désormais la page de résumé qui la présente, précédée du pré-prompt
// « On te rappelle pour ton objectif ? » — et seulement si l'objectif a été
// accepté. Voir [askPushWhenDeclined] pour le compromis.

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/reading_goal.dart';
import 'goals_service.dart';

/// Préréglages proposés. Les valeurs sont volontairement celles déjà offertes
/// par ReadingGoalsPage (chips 10 min, 3 jours, « 1 livre par mois » = 12 par
/// an) : l'utilisateur les retrouve telles quelles, sélectionnées, quand il
/// ouvre la page Objectifs.
enum FirstSessionGoalPreset {
  tenMinutesPerDay(GoalType.minutesPerDay, 10, '⏱', 'minutes_10'),
  threeDaysPerWeek(GoalType.daysPerWeek, 3, '🔁', 'days_3'),
  oneBookPerMonth(GoalType.booksPerYear, 12, '📗', 'book_month');

  final GoalType type;
  final int value;
  final String emoji;

  /// Valeur de la propriété `preset` des events PostHog.
  final String analyticsKey;

  const FirstSessionGoalPreset(
    this.type,
    this.value,
    this.emoji,
    this.analyticsKey,
  );
}

class FirstSessionGoalOffer {
  FirstSessionGoalOffer._();

  /// Contient l'id de l'utilisateur pour qui l'offre est en attente : un
  /// drapeau resté sur l'appareil ne doit jamais servir à un autre compte.
  static const _kPendingUserKey = 'first_session_goal_offer_pending_user';

  /// Que fait-on de la popup système de notifications quand l'utilisateur
  /// répond « Plus tard » à la carte objectif ?
  ///
  ///  * `false` (défaut, conforme à la spec) : rien maintenant. La cartouche
  ///    reste intacte et `MainNavigation._runValueGatedPrompts` la présentera
  ///    au prochain lancement.
  ///  * `true` : on la présente tout de suite, comme avant ce changement.
  ///
  /// Le risque du `false` : ceux qui refusent l'objectif ET ne reviennent pas
  /// n'auront jamais de token push (à surveiller : part des nouveaux lecteurs
  /// avec `profiles.fcm_token`). Un seul booléen à basculer si la couverture
  /// chute.
  static const bool askPushWhenDeclined = false;

  static String? get _currentUserId =>
      Supabase.instance.client.auth.currentUser?.id;

  /// Pose le drapeau pour l'utilisateur courant. `false` si impossible (pas de
  /// compte, stockage indisponible) : l'appelant garde alors l'ancien
  /// comportement (popup immédiate).
  static Future<bool> markPending() async {
    final uid = _currentUserId;
    if (uid == null) return false;
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.setString(_kPendingUserKey, uid);
    } catch (e) {
      debugPrint('FirstSessionGoalOffer.markPending error: $e');
      return false;
    }
  }

  static Future<bool> isPending() async {
    final uid = _currentUserId;
    if (uid == null) return false;
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_kPendingUserKey) == uid;
    } catch (e) {
      debugPrint('FirstSessionGoalOffer.isPending error: $e');
      return false;
    }
  }

  static Future<void> clearPending() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kPendingUserKey);
    } catch (e) {
      debugPrint('FirstSessionGoalOffer.clearPending error: $e');
    }
  }

  /// `true` / `false` si l'utilisateur a (ou non) un objectif actif cette
  /// année ; `null` si on ne sait pas (erreur réseau).
  ///
  /// On interroge la table directement plutôt que via
  /// `GoalsService.getActiveGoalsWithProgress`, qui avale les erreurs et
  /// renvoie `[]` : une erreur serait prise pour « aucun objectif », et
  /// `saveAllGoals` désactive tous les objectifs actifs avant d'insérer.
  static Future<bool?> userHasActiveGoal() async {
    final uid = _currentUserId;
    if (uid == null) return null;
    try {
      final rows = await Supabase.instance.client
          .from('reading_goals')
          .select('id')
          .eq('user_id', uid)
          .eq('is_active', true)
          .eq('year', DateTime.now().year)
          .limit(1);
      return (rows as List).isNotEmpty;
    } catch (e) {
      debugPrint('FirstSessionGoalOffer.userHasActiveGoal error: $e');
      return null;
    }
  }

  /// Crée l'objectif du préréglage. Lève en cas d'échec (l'appelant affiche
  /// l'erreur et laisse la carte en place).
  static Future<void> apply(FirstSessionGoalPreset preset) {
    return GoalsService().saveAllGoals({preset.type: preset.value});
  }
}
