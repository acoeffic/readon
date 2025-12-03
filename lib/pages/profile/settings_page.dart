import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../widgets/back_header.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

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
              const BackHeader(title: 'Paramètres'),
              const SizedBox(height: AppSpace.l),

              // --- Section Profil ---
              _SettingsSection(
                title: 'Profil',
                items: const [
                  _SettingsItem(label: '✏️ Modifier le nom'),
                  _SettingsItem(label: '📸 Changer la photo de profil'),
                ],
              ),

              const SizedBox(height: AppSpace.m),

              // --- Section Lecture ---
              _SettingsSection(
                title: 'Lecture',
                items: const [
                  _SettingsItem(label: '🎯 Modifier l\'objectif de lecture'),
                  _SettingsItem(label: '🔔 Notifications de progression'),
                ],
              ),

              const SizedBox(height: AppSpace.m),

              // --- Section Apparence ---
              _SettingsSection(
                title: 'Apparence',
                items: const [
                  _SettingsItem(label: '🌞 Thème clair (actif)'),
                  _SettingsItem(label: '🌙 Thème sombre'),
                ],
              ),

              const SizedBox(height: AppSpace.m),

              // --- Section Compte ---
              _SettingsSection(
                title: 'Compte',
                items: const [
                  _SettingsItem(label: '🖥️ Gérer connexions & appareils'),
                ],
              ),

              const SizedBox(height: AppSpace.l),

              // --- Déconnexion ---
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpace.m),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(AppRadius.l),
                ),
                child: TextButton(
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.l),
                        ),
                        title: const Text('Se déconnecter ?'),
                        content: const Text('Tu vas être déconnecté. Continuer ?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(false),
                            child: const Text('Annuler'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(true),
                            child: const Text(
                              'Confirmer',
                              style: TextStyle(color: AppColors.error),
                            ),
                          ),
                        ],
                      ),
                    );

                    if (confirm == true) {
                      Navigator.of(context).pop();
                    }
                  },
                  child: const Text(
                    '❌ Se déconnecter',
                    style: TextStyle(
                      color: AppColors.error,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
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

class _SettingsSection extends StatelessWidget {
  final String title;
  final List<_SettingsItem> items;

  const _SettingsSection({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 20),
        ),
        const SizedBox(height: AppSpace.s),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpace.l),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(AppRadius.l),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: items
                .map(
                  (e) => Padding(
                    padding: EdgeInsets.only(bottom: e == items.last ? 0 : AppSpace.s),
                    child: e,
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }
}

class _SettingsItem extends StatelessWidget {
  final String label;

  const _SettingsItem({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(label, style: Theme.of(context).textTheme.titleMedium);
  }
}
