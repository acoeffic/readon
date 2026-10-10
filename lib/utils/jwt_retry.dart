import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Vrai si l'erreur est un JWT expiré côté PostgREST (PGRST303) ou Auth.
bool isJwtExpiredError(Object e) {
  if (e is PostgrestException) {
    return e.code == 'PGRST303' ||
        e.message.toLowerCase().contains('jwt expired');
  }
  return e.toString().toLowerCase().contains('jwt expired');
}

/// Rafraîchit la session si le token est expiré ou expire dans < 60 s.
/// Best-effort : ne lève jamais (hors ligne, on laisse l'appel suivant échouer
/// normalement et la logique offline prendre le relais).
Future<void> ensureFreshSession() async {
  try {
    final auth = Supabase.instance.client.auth;
    final session = auth.currentSession;
    if (session == null) return;
    final exp = session.expiresAt; // secondes epoch
    if (exp == null) return;
    final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    if (exp - nowSec > 60) return;
    // Borné : un refresh bloqué (réseau dégradé) ne doit pas empêcher la
    // bascule offline des appelants.
    await auth.refreshSession().timeout(const Duration(seconds: 5));
  } catch (e) {
    debugPrint('ensureFreshSession (non bloquant): $e');
  }
}

/// Exécute [op] ; si le JWT est expiré (app restée longtemps en arrière-plan,
/// timer d'auto-refresh suspendu), rafraîchit la session puis rejoue [op]
/// une seule fois.
Future<T> withJwtRetry<T>(Future<T> Function() op) async {
  await ensureFreshSession();
  try {
    return await op();
  } catch (e) {
    if (!isJwtExpiredError(e)) rethrow;
    await Supabase.instance.client.auth.refreshSession();
    return await op();
  }
}
