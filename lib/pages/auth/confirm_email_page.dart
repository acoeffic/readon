// pages/auth/confirm_email_page.dart
// Écran de confirmation d'email (après inscription)

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/app_theme.dart';
import '../../widgets/back_header.dart';
import 'auth_gate.dart';

class ConfirmEmailPage extends StatefulWidget {
  const ConfirmEmailPage({super.key});

  @override
  State<ConfirmEmailPage> createState() => _ConfirmEmailPageState();
}

class _ConfirmEmailPageState extends State<ConfirmEmailPage> {
  StreamSubscription<AuthState>? _authSub;

  @override
  void initState() {
    super.initState();
    // Ecouter les changements d'auth (deep link apres confirmation)
    _authSub = Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.signedIn && mounted) {
        _goToAuthGate();
      }
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }

  void _goToAuthGate() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AuthGate()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.light,
      child: Scaffold(
      backgroundColor: AppColors.bgLight,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.l),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const BackHeader(title: 'Email envoyé'),
              const SizedBox(height: AppSpace.xl),

              Icon(Icons.mark_email_read,
                  size: 90, color: AppColors.primary.withValues(alpha:0.9)),

              const SizedBox(height: AppSpace.l),
              Text(
                'Vérifie ta boîte mail',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                    ),
              ),

              const SizedBox(height: AppSpace.s),
              Text(
                "Nous t'avons envoyé un lien pour confirmer ton adresse email.",
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),

              const Spacer(),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.white,
                    padding: const EdgeInsets.symmetric(vertical: AppSpace.m),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.l),
                    ),
                  ),
                  onPressed: _goToAuthGate,
                  child: const Text(
                    'J\'ai confirmé mon email',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
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
