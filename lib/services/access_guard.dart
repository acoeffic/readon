// lib/services/access_guard.dart
// Vérifie si l'utilisateur courant a le droit d'accéder aux données d'un autre.

import 'package:supabase_flutter/supabase_flutter.dart';

/// Retourne `true` si le current user peut accéder aux données de [targetUserId].
///
/// Règles :
/// 1. Soi-même → toujours autorisé
/// 2. Ami accepté → autorisé
/// 3. Profil public → autorisé
/// 4. Sinon → refusé
Future<bool> canAccessUserData(String targetUserId) async {
  final supabase = Supabase.instance.client;
  final currentUserId = supabase.auth.currentUser?.id;

  if (currentUserId == null) return false;
  if (currentUserId == targetUserId) return true;

  // Vérifier amitié acceptée OU profil public en une seule requête
  final result = await supabase.rpc(
    'can_access_user_data',
    params: {'p_target_user_id': targetUserId},
  );

  return result == true;
}
