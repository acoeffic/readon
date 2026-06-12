// pages/auth/confirm_email_page.dart
// Écran de confirmation d'email (après inscription).
// Reçoit l'email de l'utilisateur pour proposer un renvoi du lien de
// confirmation avec cooldown.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/env.dart';
import '../../l10n/app_localizations.dart';
import '../../services/auth_resend_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/back_header.dart';
import 'auth_gate.dart';

class ConfirmEmailPage extends StatefulWidget {
  /// Email à confirmer. Si null, le bouton de renvoi est masqué (legacy).
  final String? email;

  const ConfirmEmailPage({super.key, this.email});

  @override
  State<ConfirmEmailPage> createState() => _ConfirmEmailPageState();
}

class _ConfirmEmailPageState extends State<ConfirmEmailPage> {
  StreamSubscription<AuthState>? _authSub;
  Timer? _cooldownTicker;
  Duration? _cooldownRemaining;
  bool _resending = false;

  @override
  void initState() {
    super.initState();
    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.signedIn && mounted) {
        _goToAuthGate();
      }
    });
    _refreshCooldown();
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _cooldownTicker?.cancel();
    super.dispose();
  }

  void _goToAuthGate() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AuthGate()),
      (route) => false,
    );
  }

  void _refreshCooldown() {
    final email = widget.email;
    if (email == null) return;
    final remaining =
        AuthResendService.instance.remainingCooldown(email);
    setState(() => _cooldownRemaining = remaining);
    _cooldownTicker?.cancel();
    if (remaining != null) {
      _cooldownTicker = Timer.periodic(const Duration(seconds: 1), (_) {
        final r = AuthResendService.instance.remainingCooldown(email);
        if (!mounted) return;
        setState(() => _cooldownRemaining = r);
        if (r == null) _cooldownTicker?.cancel();
      });
    }
  }

  Future<void> _resend() async {
    final email = widget.email;
    if (email == null || _resending) return;
    setState(() => _resending = true);
    final result = await AuthResendService.instance.resendSignupConfirmation(
      email: email,
      emailRedirectTo: Env.authEmailCallbackUrl,
    );
    if (!mounted) return;
    setState(() => _resending = false);

    final l10n = AppLocalizations.of(context);
    if (result.sent) {
      _refreshCooldown();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.resendConfirmationSent),
          backgroundColor: Colors.green,
        ),
      );
    } else if (result.retryAfter != null) {
      _refreshCooldown();
    } else if (result.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.resendConfirmationError(result.error!)),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final email = widget.email;
    final cooldownSecs = _cooldownRemaining?.inSeconds;
    final canResend = email != null && cooldownSecs == null && !_resending;

    return Theme(
      data: AppTheme.light(),
      child: Scaffold(
        backgroundColor: AppColors.bgLight,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.l),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                BackHeader(title: l10n.emailSent),
                const SizedBox(height: AppSpace.xl),
                Icon(
                  Icons.mark_email_read,
                  size: 90,
                  color: AppColors.primary.withValues(alpha: 0.9),
                ),
                const SizedBox(height: AppSpace.l),
                Text(
                  l10n.checkYourEmail,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: AppSpace.s),
                Text(
                  email != null
                      ? l10n.confirmEmailSentTo(email)
                      : l10n.confirmEmailSent,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const Spacer(),
                if (email != null)
                  TextButton(
                    onPressed: canResend ? _resend : null,
                    child: Text(
                      cooldownSecs != null
                          ? l10n.resendConfirmationCooldown(cooldownSecs)
                          : l10n.resendConfirmationEmail,
                      style: TextStyle(
                        color: canResend
                            ? AppColors.primary
                            : AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                const SizedBox(height: AppSpace.s),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.white,
                      padding:
                          const EdgeInsets.symmetric(vertical: AppSpace.m),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.l),
                      ),
                    ),
                    onPressed: _goToAuthGate,
                    child: Text(
                      l10n.iConfirmedMyEmail,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpace.l),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
