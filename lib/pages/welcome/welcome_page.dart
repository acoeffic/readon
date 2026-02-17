// pages/welcome/welcome_page.dart
// Écran d'accueil extrait depuis le fichier monolithique

import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../auth/login_page.dart';
import '../auth/signup_page.dart';

class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

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
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              Image.network(
                'https://nzbhmshkcwudzydeahrq.supabase.co/storage/v1/object/public/asset/Image/LogoReadOn.png',
                width: 200,
                fit: BoxFit.contain,
              ),
              const Spacer(),

              // Bouton Connexion
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
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const LoginPage()),
                  ),
                  child: const Text(
                    'Déjà un compte ? Se connecter',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: AppSpace.s),

              // Bouton inscription
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    padding: const EdgeInsets.symmetric(vertical: AppSpace.m),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.l),
                    ),
                  ),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SignUpPage()),
                  ),
                  child: const Text(
                    'Pas encore de compte ? Créer un compte',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),

              const SizedBox(height: AppSpace.m),
            ],
          ),
        ),
      ),
    ),
    );
  }
}