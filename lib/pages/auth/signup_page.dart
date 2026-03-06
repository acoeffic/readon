// pages/auth/signup_page.dart
// Page d'inscription avec acceptation des CGU

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/env.dart';
import '../../l10n/app_localizations.dart';
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
          title: Text(
            AppLocalizations.of(context).emailAlreadyUsed,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 20,
            ),
          ),
          content: Text(
            AppLocalizations.of(context).emailAlreadyUsedMessage,
            style: const TextStyle(fontSize: 15),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text(
                AppLocalizations.of(context).back,
                style: const TextStyle(
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
              child: Text(
                AppLocalizations.of(context).reset,
                style: const TextStyle(
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
        redirectTo: Env.authCallbackUrl,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).resetEmailSent),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 4),
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
        SnackBar(
          content: Text(AppLocalizations.of(context).errorSendingEmail),
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
        SnackBar(content: Text(AppLocalizations.of(context).emailAndPasswordRequired)),
      );
      return;
    }

    if (password.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).passwordMin8Chars)),
      );
      return;
    }

    if (!RegExp(r'[A-Z]').hasMatch(password) ||
        !RegExp(r'[a-z]').hasMatch(password) ||
        !RegExp(r'[0-9]').hasMatch(password)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).passwordRequirements)),
      );
      return;
    }

    if (!_acceptedTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).mustAcceptTerms),
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
        emailRedirectTo: Env.authV1CallbackUrl,
        data: {'display_name': name},
      );

      final user = res.user;

      // Avec "Confirm email" activé, Supabase retourne un user
      // avec identities vide si l'email est déjà pris
      if (user != null &&
          user.identities != null &&
          user.identities!.isEmpty) {
        if (!mounted) return;
        _showEmailAlreadyExistsDialog();
        return;
      }

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
        SnackBar(content: Text(AppLocalizations.of(context).accountCreatedCheckEmail)),
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
          .showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).unknownError)));
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
              BackHeader(title: AppLocalizations.of(context).createAccountTitle),
              const SizedBox(height: AppSpace.l),

              // Logo LexDay
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: AppColors.accentLight.withValues(alpha:0.6),
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.menu_book_rounded,
                          color: AppColors.primary,
                          size: 52,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpace.s),
                    Text(
                      'LexDay',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            color: AppColors.primary,
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpace.l),

              Text(
                AppLocalizations.of(context).joinLexDay,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: AppSpace.s),
              Text(
                AppLocalizations.of(context).enterInfoToStart,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpace.xl),

              Text(AppLocalizations.of(context).name, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppSpace.xs),
              TextField(
                controller: nameController,
                decoration: InputDecoration(hintText: AppLocalizations.of(context).yourName),
              ),

              const SizedBox(height: AppSpace.m),
              Text(AppLocalizations.of(context).emailLower, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppSpace.xs),
              TextField(
                controller: emailController,
                decoration: InputDecoration(hintText: AppLocalizations.of(context).yourEmail),
                keyboardType: TextInputType.emailAddress,
              ),

              const SizedBox(height: AppSpace.m),
              Text(AppLocalizations.of(context).passwordLabel, style: Theme.of(context).textTheme.titleMedium),
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
                  child: Text(
                    AppLocalizations.of(context).createAccount,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),

              const SizedBox(height: AppSpace.m),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const LoginPage()),
                  ),
                  child: Text(
                    AppLocalizations.of(context).alreadyHaveAccount,
                    style: const TextStyle(color: AppColors.primary),
                  ),
                ),
              ),

              const SizedBox(height: AppSpace.s),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const LegalNoticePage()),
                  ),
                  child: Text(
                    AppLocalizations.of(context).legalNotices,
                    style: const TextStyle(
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