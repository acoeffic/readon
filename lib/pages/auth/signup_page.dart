// pages/auth/signup_page.dart
// Page d'inscription extraite et structurée

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/app_theme.dart';
import '../../widgets/back_header.dart';
import '../auth/confirm_email_page.dart';
import '../auth/login_page.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

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
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Erreur inconnue')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                  onPressed: signUp,
                  child: const Text('Créer un compte',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),

              const SizedBox(height: AppSpace.m),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const LoginPage()),
                  ),
                  child: const Text('Déjà un compte ? Se connecter',
                      style: TextStyle(color: AppColors.primary)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
