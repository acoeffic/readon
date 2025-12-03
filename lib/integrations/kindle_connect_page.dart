import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../widgets/back_header.dart';
import '../../services/kindle_api_service.dart';

class KindleConnectPage extends StatefulWidget {
  const KindleConnectPage({super.key});

  @override
  State<KindleConnectPage> createState() => _KindleConnectPageState();
}

class _KindleConnectPageState extends State<KindleConnectPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final kindleService = KindleApiService();

  bool loading = false;
  bool healthOk = false;

  @override
  void initState() {
    super.initState();
    _checkHealth();
  }

  Future<void> _checkHealth() async {
    final ok = await kindleService.checkHealth();
    setState(() => healthOk = ok);
  }

  Future<void> _sync() async {
    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Email et mot de passe requis')),
      );
      return;
    }

    setState(() => loading = true);

    try {
      final result = await kindleService.syncKindle(email, password);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Synchronisation réussie: ${result['message'] ?? 'OK'}')),
      );

    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur synchronisation: $e')),
      );
    } finally {
      if (mounted) setState(() => loading = false);
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
              const BackHeader(title: 'Connexion Kindle'),
              const SizedBox(height: AppSpace.l),

              // Health check
              Row(
                children: [
                  Icon(
                    healthOk ? Icons.check_circle : Icons.error,
                    color: healthOk ? Colors.green : Colors.red,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    healthOk ? 'Serveur Kindle en ligne' : 'Serveur hors-ligne',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),

              const SizedBox(height: AppSpace.l * 1.2),

              Text('Email Amazon', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppSpace.xs),
              TextField(
                controller: emailController,
                decoration: const InputDecoration(hintText: 'ton.email@amazon.com'),
              ),

              const SizedBox(height: AppSpace.m),

              Text('Mot de passe Amazon', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppSpace.xs),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(hintText: '••••••••'),
              ),

              const SizedBox(height: AppSpace.xl),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.white,
                    padding: const EdgeInsets.symmetric(vertical: AppSpace.m),
                  ),
                  onPressed: loading ? null : _sync,
                  child: loading
                      ? const CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(AppColors.white),
                        )
                      : const Text(
                          'Synchroniser Kindle',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
