/// Configuration centralisée des variables d'environnement.
///
/// Toutes les clés sont injectées au build via `--dart-define-from-file=env.json`
/// ou individuellement via `--dart-define=SUPABASE_URL=...`.
///
/// Aucune valeur par défaut sensible n'est fournie : le build crashera
/// immédiatement si une variable obligatoire est manquante.
abstract final class Env {
  // ── Supabase ───────────────────────────────────────────────
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  // ── Google Books ───────────────────────────────────────────
  static const googleBooksApiKey = String.fromEnvironment('GOOGLE_BOOKS_API_KEY');

  // ── RevenueCat ─────────────────────────────────────────────
  static const revenueCatApiKeyIOS = String.fromEnvironment('REVENUECAT_API_KEY_IOS');
  static const revenueCatApiKeyAndroid = String.fromEnvironment('REVENUECAT_API_KEY_ANDROID');

  // ── Dev ──────────────────────────────────────────────────
  /// Forcer le statut premium sans RevenueCat (dev/test uniquement).
  /// Passer `--dart-define=DEV_FORCE_PREMIUM=true` ou l'ajouter dans env.json.
  static const devForcePremium = bool.fromEnvironment('DEV_FORCE_PREMIUM');

  /// URL de base du storage public Supabase (pour les assets badges, audio, etc.)
  static String get supabaseStorageUrl =>
      '$supabaseUrl/storage/v1/object/public';

  /// URL de callback auth Supabase
  static String get authCallbackUrl => '$supabaseUrl/auth/callback';
  static String get authV1CallbackUrl => '$supabaseUrl/auth/v1/callback';
}
