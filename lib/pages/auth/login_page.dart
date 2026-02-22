// lib/pages/auth/login_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../config/env.dart';
import '../../theme/app_theme.dart';
import 'auth_gate.dart';
import 'signup_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  int _failedAttempts = 0;
  DateTime? _lockoutUntil;

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
        redirectTo: Env.authCallbackUrl,
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
        const SnackBar(content: Text("Erreur lors de l'envoi de l'email")),
      );
    }
  }

  Future<void> login() async {
    // Backoff exponentiel : bloquer si trop de tentatives
    if (_lockoutUntil != null && DateTime.now().isBefore(_lockoutUntil!)) {
      final remaining = _lockoutUntil!.difference(DateTime.now()).inSeconds;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Trop de tentatives. Réessaie dans ${remaining}s')),
      );
      return;
    }

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

      _failedAttempts = 0;
      _lockoutUntil = null;

      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AuthGate()),
        (route) => false,
      );
    } on AuthException catch (e) {
      _failedAttempts++;
      if (_failedAttempts >= 3) {
        // Backoff : 2^(attempts-3) secondes → 1s, 2s, 4s, 8s, 16s, max 30s
        final delay = Duration(seconds: (1 << (_failedAttempts - 3)).clamp(1, 30));
        _lockoutUntil = DateTime.now().add(delay);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Erreur inconnue')));
    }
  }

  Future<void> _signInWithApple() async {
    try {
      await Supabase.instance.client.auth.signInWithOAuth(
        OAuthProvider.apple,
        redirectTo: Env.authCallbackUrl,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erreur lors de la connexion avec Apple')),
      );
    }
  }

  Future<void> _signInWithGoogle() async {
    try {
      await Supabase.instance.client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: Env.authCallbackUrl,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erreur lors de la connexion avec Google')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
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
          hintStyle: const TextStyle(color: Colors.black38),
        ),
      ),
      child: Scaffold(
        backgroundColor: AppColors.bgLight,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: 32,
              vertical: AppSpace.xl,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: AppSpace.l),

                // Logo + titre
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SvgPicture.asset(
                      'assets/images/bookmark_icon.svg',
                      width: 44,
                      height: 44,
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        RichText(
                          text: const TextSpan(
                            children: [
                              TextSpan(
                                text: 'Lex',
                                style: TextStyle(
                                  fontSize: 30,
                                  fontWeight: FontWeight.w400,
                                  fontFamily: 'Poppins',
                                  height: 1.1,
                                  color: Color(0xFF3A3A3A),
                                ),
                              ),
                              TextSpan(
                                text: 'Day',
                                style: TextStyle(
                                  fontSize: 30,
                                  fontWeight: FontWeight.w400,
                                  fontFamily: 'Poppins',
                                  height: 1.1,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          'YOUR READING LIFE, TRACKED',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 2.0,
                            color: const Color(0xFF6A6A6A),
                            fontFamily: 'Poppins',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 40),

                // Welcome text
                Text(
                  'Welcome back,',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 28,
                    fontWeight: FontWeight.w400,
                    fontStyle: FontStyle.italic,
                    color: const Color(0xFF3A3A3A),
                  ),
                ),
                Text(
                  'reader.',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 28,
                    fontWeight: FontWeight.w400,
                    fontStyle: FontStyle.italic,
                    color: const Color(0xFF3A3A3A),
                  ),
                ),

                const SizedBox(height: 36),

                // Email
                const Text(
                  'EMAIL',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 2.0,
                    color: Color(0xFF4A4A4A),
                    fontFamily: 'Poppins',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    hintText: 'you@example.com',
                    hintStyle: TextStyle(
                      color: Colors.black26,
                      fontFamily: 'Poppins',
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 16,
                      horizontal: 18,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.primary, width: 2),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Password
                const Text(
                  'PASSWORD',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 2.0,
                    color: Color(0xFF4A4A4A),
                    fontFamily: 'Poppins',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    hintText: '••••••••',
                    hintStyle: TextStyle(
                      color: Colors.black26,
                      fontFamily: 'Poppins',
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 16,
                      horizontal: 18,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.primary, width: 2),
                    ),
                  ),
                ),

                // Forgot password
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: sendResetPassword,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    child: const Text(
                      'Forgot password?',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 14,
                        fontFamily: 'Poppins',
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Continue Reading button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    onPressed: login,
                    child: const Text(
                      'Continue Reading',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Poppins',
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Divider "or"
                Row(
                  children: [
                    Expanded(
                      child: Divider(
                        color: const Color(0xFFD0CBC4),
                        thickness: 1,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'or',
                        style: TextStyle(
                          color: const Color(0xFF9A9590),
                          fontSize: 14,
                          fontFamily: 'Poppins',
                        ),
                      ),
                    ),
                    Expanded(
                      child: Divider(
                        color: const Color(0xFFD0CBC4),
                        thickness: 1,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Apple & Google buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _signInWithApple,
                        icon: const Icon(
                          Icons.apple,
                          size: 22,
                          color: Color(0xFF3A3A3A),
                        ),
                        label: const Text(
                          'Apple',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF3A3A3A),
                            fontFamily: 'Poppins',
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          side: const BorderSide(color: AppColors.border),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _signInWithGoogle,
                        icon: const FaIcon(
                          FontAwesomeIcons.google,
                          size: 18,
                          color: Color(0xFF6A6A6A),
                        ),
                        label: const Text(
                          'Google',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF3A3A3A),
                            fontFamily: 'Poppins',
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          side: const BorderSide(color: AppColors.border),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 28),

                // Create account link
                Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'New to LexDay? ',
                        style: TextStyle(
                          color: Color(0xFF6A6A6A),
                          fontSize: 14,
                          fontFamily: 'Poppins',
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const SignUpPage(),
                            ),
                          );
                        },
                        child: const Text(
                          'Create an account',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            fontFamily: 'Poppins',
                          ),
                        ),
                      ),
                    ],
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
