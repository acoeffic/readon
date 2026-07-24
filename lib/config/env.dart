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

  // ── Google Places / Maps ─────────────────────────────────
  static const googlePlacesApiKey = String.fromEnvironment('GOOGLE_PLACES_API_KEY');

  /// Empreinte SHA-1 du certificat de signature Android (format hexadécimal
  /// majuscules avec deux-points, ex: `AB:CD:...`). Nécessaire uniquement si
  /// la clé Places est restreinte aux apps Android : elle est jointe avec le
  /// package aux appels REST. Laisser vide si la clé n'est pas app-restreinte.
  static const androidCertSha1 = String.fromEnvironment('ANDROID_CERT_SHA1');

  // ── RevenueCat ─────────────────────────────────────────────
  static const revenueCatApiKeyIOS = String.fromEnvironment('REVENUECAT_API_KEY_IOS');
  static const revenueCatApiKeyAndroid = String.fromEnvironment('REVENUECAT_API_KEY_ANDROID');

  // ── Google Sign-In ────────────────────────────────────────
  static const googleWebClientId = String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');
  static const googleIosClientId = String.fromEnvironment('GOOGLE_IOS_CLIENT_ID');

  // ── Notion ────────────────────────────────────────────────
  static const notionClientId = String.fromEnvironment('NOTION_CLIENT_ID');

  // ── Readon Sync ───────────────────────────────────────────
  static const lexdaySyncUrl = String.fromEnvironment('LEXDAY_SYNC_URL');

  // ── PostHog ──────────────────────────────────────────────
  /// Project API key (preferable: project key public, pas le personal token).
  static const posthogApiKey = String.fromEnvironment('POSTHOG_API_KEY');
  /// Hôte PostHog : `https://eu.i.posthog.com` (UE) ou `https://us.i.posthog.com`.
  /// Default UE pour rester aligné RGPD si non fourni.
  static const posthogHost = String.fromEnvironment(
    'POSTHOG_HOST',
    defaultValue: 'https://eu.i.posthog.com',
  );

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

  /// URL de redirection pour la confirmation d'email (signup) et le reset
  /// de mot de passe. Utilise le custom scheme `lexday://` pour rouvrir
  /// l'app au clic sur le lien dans l'email.
  ///
  /// ⚠️ Cette URL doit être ajoutée dans la « Redirect URL allowlist »
  /// du projet Supabase (Authentication → URL Configuration), sinon
  /// Supabase refusera la redirection et l'utilisateur tombera sur une
  /// page d'erreur.
  static const authEmailCallbackUrl = 'lexday://auth/callback';
}
