import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import '../../../services/kindle_webview_service.dart';
import '../../profile/kindle_login_page.dart';

class StepKindleConnect extends StatelessWidget {
  final ValueChanged<KindleReadingData?> onKindleResult;
  final VoidCallback onSkip;

  const StepKindleConnect({
    super.key,
    required this.onKindleResult,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpace.l),
      child: Column(
        children: [
          const Spacer(),
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: AppColors.accentLight.withValues(alpha: 0.6),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Icon(
                Icons.tablet_android,
                color: AppColors.primary,
                size: 48,
              ),
            ),
          ),
          const SizedBox(height: AppSpace.l),
          Text(
            'Connecte ton Kindle',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                ),
          ),
          const SizedBox(height: AppSpace.m),
          const Text(
            'Importe automatiquement ta bibliothèque Kindle.\n'
            'Tes identifiants restent sur Amazon,\n'
            'nous n\'y avons jamais accès.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              color: Colors.black54,
              height: 1.5,
            ),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.white,
                padding: const EdgeInsets.symmetric(vertical: AppSpace.m),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
              ),
              onPressed: () => _openKindleLogin(context),
              icon: const Icon(Icons.link, size: 20),
              label: const Text(
                'Connecter mon Kindle',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(height: AppSpace.m),
          TextButton(
            onPressed: onSkip,
            child: const Text(
              'Passer cette étape',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openKindleLogin(BuildContext context) async {
    final result = await Navigator.push<KindleReadingData>(
      context,
      MaterialPageRoute(builder: (_) => const KindleLoginPage()),
    );
    onKindleResult(result);
  }
}
