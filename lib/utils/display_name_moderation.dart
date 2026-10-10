// lib/utils/display_name_moderation.dart
//
// La modération des pseudos est asynchrone : le trigger SQL appelle l'Edge
// Function `moderate-display-name`, qui remet l'ancien pseudo (ou NULL) et
// passe `display_name_moderation_status` à 'rejected'. Le client n'en est pas
// informé, donc on interroge le statut juste après une sauvegarde.

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Attend le verdict de la modération (max ~6 s) et renvoie true si le pseudo
/// vient d'être rejeté. En cas d'erreur ou de verdict tardif : false.
///
/// Le statut seul ne suffit pas : quand l'Edge Function remet l'ancien pseudo,
/// le trigger repasse le statut à 'pending' puis 'approved' (l'ancien pseudo est
/// valide), donc 'rejected' n'est presque jamais observable. Le signal fiable
/// est que `display_name` ne vaut plus [expectedName] (le pseudo saisi).
Future<bool> isDisplayNameRejectedAfterSave(
  SupabaseClient client,
  String userId, {
  required String expectedName,
}) async {
  try {
    for (var i = 0; i < 4; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 1500));
      final row = await client
          .from('profiles')
          .select('display_name, display_name_moderation_status')
          .eq('id', userId)
          .maybeSingle();
      if (row == null) continue;
      final name = row['display_name'] as String?;
      final status = row['display_name_moderation_status'] as String?;
      // Pseudo annulé côté serveur (remplacé par l'ancien ou NULL).
      if (name != expectedName) return true;
      // Verdict final positif pour CE pseudo.
      if (status == 'approved') return false;
    }
  } catch (e) {
    debugPrint('isDisplayNameRejectedAfterSave: $e');
  }
  return false;
}
