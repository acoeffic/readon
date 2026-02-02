// lib/pages/auth/login_page.dart

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../theme/app_theme.dart';
import '../../widgets/back_header.dart';
import 'auth_gate.dart';
import 'signup_page.dart';
import 'confirm_email_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  Future<void> sendResetPassword() async {
    final email = emailController.text.trim();

    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Entre ton email pour réinitialiser')),
      );
      return;
    }

    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(
        email,
        // À adapter avec ta vraie URL de redirection si besoin
        redirectTo: 'https://nzbhmshkcwudzydeahrq.supabase.co/auth/callback',
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Email envoyé, vérifie ta boîte.')),
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erreur lors de l’envoi de l’email')),
      );
    }
  }

  Future<void> login() async {
    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Email et mot de passe requis')),
      );
      return;
    }

    try {
      final res = await Supabase.instance.client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (res.session == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Connexion impossible')),
        );
        return;
      }

      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AuthGate()),
        (route) => false,
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Erreur inconnue')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Theme(
      data: AppTheme.light.copyWith(
        textTheme: AppTheme.light.textTheme.copyWith(
          bodyMedium: AppTheme.light.textTheme.bodyMedium?.copyWith(
            color: Colors.black,
          ),
          titleMedium: AppTheme.light.textTheme.titleMedium?.copyWith(
            color: Colors.black,
          ),
        ),
        inputDecorationTheme: AppTheme.light.inputDecorationTheme.copyWith(
          hintStyle: const TextStyle(color: Colors.black),
        ),
      ),
      child: Scaffold(
      backgroundColor: AppColors.bgLight,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpace.l),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const BackHeader(
                title: 'Se connecter',
                titleColor: AppColors.primary,
              ),
              const SizedBox(height: AppSpace.l),
              Text(
                'Bienvenue sur ReadOn',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.black : null,
                    ),
              ),
              const SizedBox(height: AppSpace.s),
              Text(
                'Connecte-toi pour continuer',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpace.xl),

              // Email
              Text(
                'Email',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpace.xs),
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  hintText: 'ton.email@mail.com',
                ),
              ),
              const SizedBox(height: AppSpace.m),

              // Mot de passe
              Text(
                'Mot de passe',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpace.xs),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  hintText: '••••••••',
                ),
              ),

              // Mot de passe oublié
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: sendResetPassword,
                  child: const Text(
                    'Mot de passe oublié ?',
                    style: TextStyle(color: AppColors.primary),
                  ),
                ),
              ),
              const SizedBox(height: AppSpace.l),

              // Bouton Se connecter
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
                  onPressed: login,
                  child: const Text(
                    'Se connecter',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpace.m),

              // Lien vers inscription
              Center(
                child: TextButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const SignUpPage(),
                      ),
                    );
                  },
                  child: const Text(
                    'Créer un compte',
                    style: TextStyle(color: AppColors.primary),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
    );
  }
}
