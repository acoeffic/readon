// lib/services/friend_challenge_offer.dart
//
// Carte « Lis avec un ami » : proposée UNE fois par compte, sur l'écran de fin
// de session de la 2e journée de lecture.
//
// Pourquoi (audit rétention du 29/09/2026) : « invite tes amis » est un
// mauvais prétexte ; un défi (7 jours, 10 min par jour) en est un bon. Version
// légère : aucun suivi in-app (group_challenges n'est pas utilisé : 5 défis en
// base, aucun terminé). On ne fait que fournir un message prêt à envoyer avec
// le lien de parrainage personnel — le destinataire arrive attribué, et les
// deux gagnent 14 jours de premium.
//
// Pourquoi la 2e journée : la 1re session porte déjà l'objectif
// (FirstSessionGoalOffer), la popup notifications, le paywall… Empiler une
// demande de plus serait contre-productif.

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FriendChallengeOffer {
  FriendChallengeOffer._();

  static const _doneKey = 'friend_challenge_offer_done_user';

  /// Durée et rythme annoncés dans le message (voir friendChallengeShareText).
  static const int challengeDays = 7;
  static const int challengeMinutesPerDay = 10;

  /// On propose quand le nombre de jours de lecture distincts vaut 2 (ou 3, si
  /// la 2e session n'a pas pu afficher la carte). Au-delà, l'élan est passé et
  /// les lecteurs déjà installés depuis longtemps ne sont pas sollicités.
  static const int _minDays = 2;
  static const int _maxDays = 3;

  /// true si la carte doit être affichée pour l'utilisateur courant.
  /// Best-effort : toute erreur → false (on ne montre rien).
  static Future<bool> shouldOffer() async {
    try {
      final client = Supabase.instance.client;
      final uid = client.auth.currentUser?.id;
      if (uid == null) return false;

      final prefs = await SharedPreferences.getInstance();
      if (prefs.getString(_doneKey) == uid) return false;

      // 60 dernières sessions terminées suffisent : on s'arrête à 3 jours.
      final rows = await client
          .from('reading_sessions')
          .select('start_time')
          .eq('user_id', uid)
          .not('end_time', 'is', null)
          .order('start_time', ascending: false)
          .limit(60);

      final days = <String>{};
      for (final r in (rows as List)) {
        final raw = (r as Map)['start_time'] as String?;
        final t = raw == null ? null : DateTime.tryParse(raw)?.toLocal();
        if (t == null) continue;
        days.add('${t.year}-${t.month}-${t.day}');
      }

      // Session du jour incluse (elle vient d'être terminée). Si la liste est
      // tronquée à 60 sessions, days >= 3 de toute façon → pas d'offre.
      return days.length >= _minDays && days.length <= _maxDays;
    } catch (e) {
      debugPrint('Erreur FriendChallengeOffer.shouldOffer: $e');
      return false;
    }
  }

  /// Marque l'offre comme faite (affichée) pour l'utilisateur courant : elle
  /// ne reviendra pas, qu'il partage ou non.
  static Future<void> markDone() async {
    try {
      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (uid == null) return;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_doneKey, uid);
    } catch (e) {
      debugPrint('Erreur FriendChallengeOffer.markDone: $e');
    }
  }
}
