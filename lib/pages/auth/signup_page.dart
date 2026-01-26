// pages/auth/signup_page.dart
// Page d'inscription avec acceptation des CGU

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/app_theme.dart';
import '../../widgets/back_header.dart';
import '../auth/confirm_email_page.dart';
import '../auth/login_page.dart';
import '../../widgets/terms_acceptance_checkbox.dart';
import '../auth/legal_notice_page.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool _acceptedTerms = false;

  void _showEmailAlreadyExistsDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.l),
          ),
          title: const Text(
            'Email déjà utilisé',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 20,
            ),
          ),
          content: const Text(
            'Cette adresse email est déjà associée à un compte existant. '
            'Souhaitez-vous réinitialiser votre mot de passe ?',
            style: TextStyle(fontSize: 15),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text(
                'Retour',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 16,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.m),
                ),
              ),
              onPressed: () async {
                Navigator.of(context).pop();
                await _sendPasswordResetEmail();
              },
              child: const Text(
                'Réinitialiser',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _sendPasswordResetEmail() async {
    final email = emailController.text.trim();

    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(
        email,
        redirectTo: 'https://nzbhmshkcwudzydeahrq.supabase.co/auth/callback',
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Email de réinitialisation envoyé. Vérifie ta boîte mail.'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 4),
        ),
      );

      // Optionnel : rediriger vers la page de login
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginPage()),
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: ${e.message}'),
          backgroundColor: Colors.red,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Erreur lors de l\'envoi de l\'email'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> signUp() async {
    final name = nameController.text.trim();
    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Email et mot de passe requis')),
      );
      return;
    }

    if (!_acceptedTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vous devez accepter les conditions d\'utilisation'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final supabase = Supabase.instance.client;

    try {
      final res = await supabase.auth.signUp(
        email: email,
        password: password,
        emailRedirectTo: 'https://nzbhmshkcwudzydeahrq.supabase.co/auth/v1/callback',
        data: {'display_name': name},
      );

      final user = res.user;

      if (user != null && res.session != null) {
        await supabase.from('profiles').upsert({
          'id': user.id,
          'email': email,
          'display_name': name,
          'created_at': DateTime.now().toIso8601String(),
        });
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Compte créé, vérifie tes emails.')),
      );

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const ConfirmEmailPage()),
      );
    } on AuthException catch (e) {
      if (!mounted) return;

      // Vérifier si l'email est déjà utilisé
      if (e.message.toLowerCase().contains('already registered') ||
          e.message.toLowerCase().contains('user already registered') ||
          e.message.toLowerCase().contains('email already exists')) {
        _showEmailAlreadyExistsDialog();
      } else {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Erreur inconnue')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.light,
      child: Scaffold(
      backgroundColor: AppColors.bgLight,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpace.l),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const BackHeader(title: 'Créer un compte'),
              const SizedBox(height: AppSpace.xl),

              Text(
                'Rejoins ReadOn',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: AppSpace.s),
              Text(
                'Entre tes informations pour commencer à lire',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpace.xl),

              Text('Nom', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppSpace.xs),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(hintText: 'Ton nom'),
              ),

              const SizedBox(height: AppSpace.m),
              Text('Email', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppSpace.xs),
              TextField(
                controller: emailController,
                decoration: const InputDecoration(hintText: 'ton.email@mail.com'),
                keyboardType: TextInputType.emailAddress,
              ),

              const SizedBox(height: AppSpace.m),
              Text('Mot de passe', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppSpace.xs),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(hintText: '••••••••'),
              ),

              const SizedBox(height: AppSpace.l),

              // Acceptation des CGU
              TermsAcceptanceCheckbox(
                value: _acceptedTerms,
                onChanged: (value) {
                  setState(() => _acceptedTerms = value ?? false);
                },
              ),

              const SizedBox(height: AppSpace.l),

              // Bouton créer compte (désactivé si CGU pas acceptées)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _acceptedTerms 
                        ? AppColors.primary 
                        : Colors.grey.shade400,
                    foregroundColor: AppColors.white,
                    padding: const EdgeInsets.symmetric(vertical: AppSpace.m),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.l),
                    ),
                  ),
                  onPressed: _acceptedTerms ? signUp : null,
                  child: const Text(
                    'Créer un compte',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),

              const SizedBox(height: AppSpace.m),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const LoginPage()),
                  ),
                  child: const Text(
                    'Déjà un compte ? Se connecter',
                    style: TextStyle(color: AppColors.primary),
                  ),
                ),
              ),

              const SizedBox(height: AppSpace.s),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const LegalNoticePage()),
                  ),
                  child: const Text(
                    'Mentions légales',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
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