// lib/services/auth_resend_service.dart
//
// Wrapper autour de supabase.auth.resend pour renvoyer un email de
// confirmation après inscription. Gère un cooldown 60s par email afin
// d'éviter le spam (le rate-limit Supabase est déjà strict, mais on
// préfère le matérialiser côté client pour donner un feedback explicite
// à l'utilisateur).

import 'package:supabase_flutter/supabase_flutter.dart';

class ResendResult {
  final bool sent;
  final Duration? retryAfter;
  final String? error;

  const ResendResult.sent() : sent = true, retryAfter = null, error = null;
  const ResendResult.cooldown(Duration remaining)
      : sent = false,
        retryAfter = remaining,
        error = null;
  const ResendResult.error(String message)
      : sent = false,
        retryAfter = null,
        error = message;
}

class AuthResendService {
  AuthResendService._();
  static final AuthResendService instance = AuthResendService._();

  static const _cooldown = Duration(seconds: 60);

  // Dernière date d'envoi par email (en mémoire — reset au cold start).
  final Map<String, DateTime> _lastSentAt = {};

  Duration? remainingCooldown(String email) {
    final last = _lastSentAt[email.toLowerCase()];
    if (last == null) return null;
    final elapsed = DateTime.now().difference(last);
    if (elapsed >= _cooldown) return null;
    return _cooldown - elapsed;
  }

  Future<ResendResult> resendSignupConfirmation({
    required String email,
    String? emailRedirectTo,
  }) async {
    final remaining = remainingCooldown(email);
    if (remaining != null) return ResendResult.cooldown(remaining);

    try {
      await Supabase.instance.client.auth.resend(
        type: OtpType.signup,
        email: email,
        emailRedirectTo: emailRedirectTo,
      );
      _lastSentAt[email.toLowerCase()] = DateTime.now();
      return const ResendResult.sent();
    } on AuthException catch (e) {
      return ResendResult.error(e.message);
    } catch (e) {
      return ResendResult.error(e.toString());
    }
  }
}
