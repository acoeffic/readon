import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../widgets/back_header.dart';
import '../books/widgets/progress_bar.dart';

class StartReadingPage extends StatelessWidget {
  const StartReadingPage({super.key});

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
              const BackHeader(title: 'Démarrer une lecture'),
              const SizedBox(height: AppSpace.xl),

              Text('Livre sélectionné', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppSpace.s),

              Container(
                padding: const EdgeInsets.all(AppSpace.m),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(AppRadius.l),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 65,
                      height: 95,
                      decoration: BoxDecoration(
                        color: AppColors.accentLight,
                        borderRadius: BorderRadius.circular(AppRadius.m),
                      ),
                    ),
                    const SizedBox(width: AppSpace.m),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Sapiens', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 17)),
                          const SizedBox(height: AppSpace.xs),
                          Text('Yuval Noah Harari', style: Theme.of(context).textTheme.bodyMedium),
                          const SizedBox(height: AppSpace.m),
                          OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              side: const BorderSide(color: AppColors.primary),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.s)),
                            ),
                            onPressed: () {},
                            child: const Text('Changer de livre'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpace.l),
              Text('Progression actuelle', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppSpace.s),

              Container(
                padding: const EdgeInsets.all(AppSpace.m),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(AppRadius.l),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const ProgressBar(value: 0.3),
                    const SizedBox(height: AppSpace.s),
                    Row(
                      children: [
                        Text('124 / 412 pages', style: Theme.of(context).textTheme.titleMedium),
                        const Spacer(),
                        Text('Dernière session : hier, 42 pages', style: Theme.of(context).textTheme.bodyMedium),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpace.l),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: AppSpace.xl, horizontal: AppSpace.xl),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(AppRadius.l),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppSpace.l),
                      decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.primary),
                      child: const Icon(Icons.play_arrow, color: AppColors.white, size: 42),
                    ),
                    const SizedBox(height: AppSpace.m),
                    Text('Démarrer la lecture', style: Theme.of(context).textTheme.titleMedium),
                  ],
                ),
              ),

              const SizedBox(height: AppSpace.s),

              Row(children: [
                const Icon(Icons.timer_outlined, size: 18),
                const SizedBox(width: AppSpace.s),
                Text('Mode chronométré', style: Theme.of(context).textTheme.bodyMedium),
              ]),

              const SizedBox(height: AppSpace.xs),

              Row(children: [
                const Icon(Icons.menu_book, size: 18, color: AppColors.primary),
                const SizedBox(width: AppSpace.s),
                Text('Ajouter les pages manuellement', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: AppColors.primary, fontSize: 14)),
              ]),

              const SizedBox(height: AppSpace.l),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpace.l),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(AppRadius.l),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Temps aujourd’hui : 45 min', style: Theme.of(context).textTheme.bodyMedium),
                    const SizedBox(height: AppSpace.xs),
                    Row(children: [
                      Text('Pages cette semaine : 124', style: Theme.of(context).textTheme.bodyMedium),
                      const Spacer(),
                      Row(children: [
                        const Text('🔥  '),
                        Text('Série : 6 jours', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.primary)),
                      ]),
                    ]),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}