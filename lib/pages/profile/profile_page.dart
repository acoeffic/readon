import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/back_header.dart';
import '../../widgets/progress_bar.dart';
import '../../widgets/badge.dart';
import '../../friends/friends_page.dart';
import '../../books/user_books_page.dart';
import '../../integrations/kindle/kindle_connect_page.dart';
import 'settings_page.dart';

class ProfilePage extends StatelessWidget {
  final bool showBack;
  const ProfilePage({super.key, this.showBack = false});

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
              // --- HEADER ---
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  showBack
                      ? IconButton(
                          icon: const Icon(Icons.arrow_back),
                          onPressed: () => Navigator.of(context).pop(),
                        )
                      : const SizedBox(width: 48),

                  Column(
                    children: [
                      Container(
                        width: 82,
                        height: 82,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.accentLight,
                        ),
                      ),
                      const SizedBox(height: AppSpace.s),
                      Text(
                        'Adrien C.',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: AppSpace.xs),
                      Text(
                        'Lecteur motivé depuis 2025',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),

                  IconButton(
                    icon: const Icon(Icons.settings_outlined),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const SettingsPage()),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: AppSpace.l),

              // --- STATISTIQUES ---
              Container(
                padding: const EdgeInsets.all(AppSpace.l),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(AppRadius.l),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Statistiques', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: AppSpace.s),

                    Row(
                      children: const [
                        Text('📚 12 Livres terminés'),
                        SizedBox(width: AppSpace.m),
                        Text('⏱️ 48 Heures'),
                        SizedBox(width: AppSpace.m),
                        Text('🔥 6 J'),
                      ],
                    ),
                    const SizedBox(height: AppSpace.m),

                    Row(
                      children: List.generate(
                        5,
                        (i) => Padding(
                          padding: EdgeInsets.only(right: i == 4 ? 0 : AppSpace.s),
                          child: Container(
                            width: 12 + (i % 2 == 0 ? 4 : 0),
                            height: 28 + (i % 2 == 0 ? 6 : 0),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(AppRadius.s),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpace.l),

              // --- NAVIGATION ---
              _navButton(
                context,
                label: 'Mes amis',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const FriendsPage()),
                ),
              ),

              const SizedBox(height: AppSpace.m),

              _navButton(
                context,
                label: 'Ma bibliothèque',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const UserBooksPage()),
                ),
              ),

              const SizedBox(height: AppSpace.m),

              _navButton(
                context,
                label: 'Synchroniser mon compte Kindle',
                icon: Icons.cloud_sync_outlined,
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const KindleConnectPage()),
                ),
              ),

              const SizedBox(height: AppSpace.l),

              // --- OBJECTIF ---
              Text('Ton objectif 2025', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 22)),
              const SizedBox(height: AppSpace.s),

              Container(
                padding: const EdgeInsets.all(AppSpace.m),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(AppRadius.l),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text('340 / 500 pages'),
                          SizedBox(height: AppSpace.s),
                          ProgressBar(value: 0.68),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpace.m),

                    OutlinedButton(
                      onPressed: () {},
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                      ),
                      child: const Text('Modifier'),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpace.l),

              // --- BADGES ---
              Text('Mes badges', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 22)),
              const SizedBox(height: AppSpace.s),

              Container(
                padding: const EdgeInsets.all(AppSpace.l),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(AppRadius.l),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: const [
                        BadgeWidget(color: AppColors.primary, label: '🌱 Débutant'),
                        BadgeWidget(color: Color(0xFF6A5AE0), label: '🔥 Série 7j'),
                        BadgeWidget(color: AppColors.accentLight, label: '📘 1er livre'),
                      ],
                    ),
                    const SizedBox(height: AppSpace.s),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text('Voir tout →', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navButton(BuildContext context, {required String label, IconData? icon, required VoidCallback onPressed}) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        icon: icon != null ? Icon(icon, color: AppColors.primary) : const SizedBox(),
        label: Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary),
          padding: const EdgeInsets.symmetric(vertical: AppSpace.m),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.l)),
        ),
        onPressed: onPressed,
      ),
    );
  }
}