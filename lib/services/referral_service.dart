import 'dart:io';

import 'package:android_play_install_referrer/android_play_install_referrer.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/app_constants.dart';

/// Résultat de l'application d'un code de parrainage.
enum ApplyReferralResult {
  success,
  invalidCode,
  selfReferral,
  alreadyReferred,
  notEligible,
  error,
}

/// Service de parrainage (référral récompensé).
///
/// - Chaque profil possède un `referral_code` unique (généré en base).
/// - Le filleul applique un code via l'Edge Function `apply-referral`.
/// - La récompense (14 j de premium pour les deux) est accordée côté serveur
///   quand le filleul termine sa première session de lecture.
class ReferralService {
  ReferralService([SupabaseClient? client])
      : _supabase = client ?? Supabase.instance.client;

  final SupabaseClient _supabase;

  static const _pendingCodeKey = 'pending_referral_code';

  /// Le Play Install Referrer n'est lisible qu'une fois : on note qu'on l'a
  /// consulté pour ne pas interroger le Play Store à chaque lancement.
  static const _installReferrerCheckedKey = 'install_referrer_checked';

  /// Base du lien de partage (le site redirige vers l'app / le store).
  static const String _referralBaseUrl = 'https://www.lexday.fr/r/';

  /// Lien personnel mis en cache, pour un accès **synchrone** depuis les
  /// constructeurs de textes de partage (`buildShareText` & co. ne sont pas
  /// async, et les rendre async contaminerait une dizaine d'appelants).
  ///
  /// Rempli par [primeShareLink] au démarrage. Tant qu'il est vide, on
  /// retombe sur la page de renvoi neutre — jamais sur `kAppStoreUrl`, qui
  /// laisserait un destinataire Android sans rien.
  static String? _cachedShareLink;

  /// URL à faire figurer dans TOUT partage sortant : lien de parrainage
  /// personnel si disponible, page de renvoi neutre sinon.
  ///
  /// Transforme une sortie d'app en porte d'entrée attribuée : le destinataire
  /// arrive avec le code de son parrain, et les deux gagnent 14 jours.
  static String get shareUrl => _cachedShareLink ?? kShareLandingUrl;

  /// À appeler après l'authentification. Best-effort : un échec laisse
  /// simplement le lien neutre en place.
  Future<void> primeShareLink() async {
    try {
      final link = await getShareLink();
      if (link != null) _cachedShareLink = link;
    } catch (_) {
      // Silencieux : le partage doit fonctionner même sans code.
    }
  }

  /// Vide le cache (déconnexion) pour ne pas partager le code du compte
  /// précédent.
  static void clearShareLinkCache() => _cachedShareLink = null;

  /// Code de parrainage de l'utilisateur courant.
  Future<String?> getMyCode() async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) return null;
    final row = await _supabase
        .from('profiles')
        .select('referral_code')
        .eq('id', uid)
        .maybeSingle();
    return row?['referral_code'] as String?;
  }

  /// Lien d'invitation partageable (ex: https://www.lexday.fr/r/ABC123).
  Future<String?> getShareLink() async {
    final code = await getMyCode();
    if (code == null) return null;
    return '$_referralBaseUrl$code';
  }

  /// Nombre de filleuls (total) et combien ont déclenché la récompense.
  Future<({int total, int rewarded})> getStats() async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) return (total: 0, rewarded: 0);
    final rows = await _supabase
        .from('referrals')
        .select('status')
        .eq('referrer_id', uid);
    final list = (rows as List);
    final rewarded =
        list.where((r) => (r as Map)['status'] == 'rewarded').length;
    return (total: list.length, rewarded: rewarded);
  }

  /// Applique un code de parrainage pour l'utilisateur courant.
  Future<ApplyReferralResult> applyCode(String code) async {
    final clean = code.trim().toUpperCase();
    if (clean.isEmpty) return ApplyReferralResult.invalidCode;
    try {
      final res = await _supabase.functions.invoke(
        'apply-referral',
        body: {'code': clean},
      );
      final data = res.data;
      if (data is Map && data['success'] == true) {
        return ApplyReferralResult.success;
      }
      return _mapError(data is Map ? data['error'] as String? : null);
    } on FunctionException catch (e) {
      final details = e.details;
      final err = details is Map ? details['error'] as String? : null;
      return _mapError(err);
    } catch (_) {
      return ApplyReferralResult.error;
    }
  }

  ApplyReferralResult _mapError(String? err) {
    switch (err) {
      case 'invalid_code':
        return ApplyReferralResult.invalidCode;
      case 'self_referral':
        return ApplyReferralResult.selfReferral;
      case 'already_referred':
        return ApplyReferralResult.alreadyReferred;
      case 'not_eligible':
        return ApplyReferralResult.notEligible;
      default:
        return ApplyReferralResult.error;
    }
  }

  // ── Code en attente (deep link ouvert avant l'authentification) ──

  /// Mémorise un code reçu via deep link, à appliquer une fois connecté.
  Future<void> storePendingCode(String code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pendingCodeKey, code.trim().toUpperCase());
  }

  /// Récupère le code transmis par le Play Store à l'installation.
  ///
  /// C'est le seul mécanisme d'**attribution différée** officiel et gratuit :
  /// le lien `/r/CODE` envoie vers le Play Store avec `&referrer=code%3DCODE`,
  /// et Google le restitue ici au premier lancement, même si l'app vient
  /// d'être installée. iOS n'a aucun équivalent — là-bas, le filleul saisit
  /// son code à la main (le lien affiche le code à recopier).
  ///
  /// Best-effort et exécuté une seule fois. À appeler au démarrage, AVANT
  /// [applyPendingCode].
  Future<void> captureInstallReferrer() async {
    if (kIsWeb || !Platform.isAndroid) return;
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_installReferrerCheckedKey) == true) return;

    try {
      final details = await AndroidPlayInstallReferrer.installReferrer;
      final raw = details.installReferrer;
      await prefs.setBool(_installReferrerCheckedKey, true);
      if (raw == null || raw.isEmpty) return;

      // Le referrer est une query string : `code=ABC123` éventuellement
      // accompagnée des utm_* que Play ajoute de son côté.
      final code = Uri.splitQueryString(raw)['code'];
      if (code == null || code.trim().isEmpty) return;

      // Ne pas écraser un code déjà en attente (deep link plus récent).
      if (prefs.getString(_pendingCodeKey)?.isNotEmpty == true) return;
      await storePendingCode(code);
      debugPrint('Install referrer: code de parrainage capté');
    } catch (e) {
      debugPrint('Install referrer indisponible: $e');
      // Pas de nouvelle tentative : l'API n'est fiable qu'au premier lancement.
      await prefs.setBool(_installReferrerCheckedKey, true);
    }
  }

  /// Applique le code en attente (le cas échéant) et le supprime en cas de
  /// résultat définitif. À appeler après l'authentification (ex: AuthGate).
  Future<ApplyReferralResult?> applyPendingCode() async {
    if (_supabase.auth.currentUser == null) return null;
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_pendingCodeKey);
    if (code == null || code.isEmpty) return null;

    final result = await applyCode(code);
    // On efface sauf en cas d'erreur réseau transitoire (on pourra retenter).
    if (result != ApplyReferralResult.error) {
      await prefs.remove(_pendingCodeKey);
    }
    return result;
  }
}
