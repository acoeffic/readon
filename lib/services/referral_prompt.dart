// lib/services/referral_prompt.dart
//
// Invitations de parrainage contextuelles, affichées aux « moments de fierté »
// (livre terminé, paliers de flow) plutôt que cachées dans les Réglages.
//
// Pourquoi (analyse du 09/11/2026) : le parrainage est branché de bout en bout
// depuis août mais n'avait qu'une ligne en base (1 invitation « pending »),
// pour 230 profils : personne ne le voyait. On demande quand l'utilisateur est
// content, avec des garde-fous pour ne jamais harceler :
//  - un même déclencheur ne se présente qu'une fois par compte ;
//  - au moins [_cooldownDays] jours entre deux invitations, tous déclencheurs
//    confondus ;
//  - au plus [_maxPrompts] invitations au total par compte.
//
// Complémentaire de FriendChallengeOffer (défi à deux, 2e journée de lecture),
// qui reste prioritaire sur l'écran de fin de session.

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ReferralPrompt {
  ReferralPrompt._();

  /// Déclencheurs (valeur envoyée dans la property `source` d'analytics).
  static const String bookFinished = 'book_finished';
  static String streak(int days) => 'streak_$days';

  /// Paliers de flow qui déclenchent une invitation.
  static const Set<int> streakMilestones = {7, 14, 30};

  static const int _cooldownDays = 10;
  static const int _maxPrompts = 5;

  static const _seenKey = 'referral_prompt_seen_triggers';
  static const _lastKey = 'referral_prompt_last_ms';
  static const _userKey = 'referral_prompt_user';

  /// true si l'invitation [trigger] peut être affichée maintenant.
  /// Best-effort : toute erreur → false (on ne montre rien).
  static Future<bool> shouldPrompt(String trigger) async {
    try {
      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (uid == null) return false;
      final prefs = await SharedPreferences.getInstance();
      await _resetIfOtherUser(prefs, uid);

      final seen = prefs.getStringList(_seenKey) ?? const <String>[];
      if (seen.contains(trigger)) return false;
      if (seen.length >= _maxPrompts) return false;

      final lastMs = prefs.getInt(_lastKey);
      if (lastMs != null) {
        final elapsed = DateTime.now()
            .difference(DateTime.fromMillisecondsSinceEpoch(lastMs));
        if (elapsed.inDays < _cooldownDays) return false;
      }
      return true;
    } catch (e) {
      debugPrint('Erreur ReferralPrompt.shouldPrompt: $e');
      return false;
    }
  }

  /// Marque l'invitation comme affichée : elle ne reviendra pas pour ce
  /// déclencheur, et le délai avant la suivante démarre.
  static Future<void> markShown(String trigger) async {
    try {
      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (uid == null) return;
      final prefs = await SharedPreferences.getInstance();
      await _resetIfOtherUser(prefs, uid);
      final seen = [...(prefs.getStringList(_seenKey) ?? const <String>[])];
      if (!seen.contains(trigger)) seen.add(trigger);
      await prefs.setStringList(_seenKey, seen);
      await prefs.setInt(_lastKey, DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      debugPrint('Erreur ReferralPrompt.markShown: $e');
    }
  }

  /// Les compteurs sont locaux à l'appareil : on les remet à zéro si un autre
  /// compte se connecte, pour ne pas hériter de l'historique du précédent.
  static Future<void> _resetIfOtherUser(
      SharedPreferences prefs, String uid) async {
    if (prefs.getString(_userKey) == uid) return;
    await prefs.remove(_seenKey);
    await prefs.remove(_lastKey);
    await prefs.setString(_userKey, uid);
  }
}
