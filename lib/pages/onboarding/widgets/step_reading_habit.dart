import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';

class StepReadingHabit extends StatelessWidget {
  final String? selectedHabit;
  final ValueChanged<String> onSelected;
  final VoidCallback onNext;

  const StepReadingHabit({
    super.key,
    required this.selectedHabit,
    required this.onSelected,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpace.l),
      child: Column(
        children: [
          const Spacer(),
          Text(
            'Comment lis-tu\nle plus souvent ?',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                ),
          ),
          const SizedBox(height: 32),
          _HabitCard(
            icon: Icons.tablet_android,
            label: 'Liseuse',
            subtitle: 'Kindle, Kobo...',
            value: 'liseuse',
            selected: selectedHabit == 'liseuse',
            onTap: () => onSelected('liseuse'),
          ),
          const SizedBox(height: AppSpace.m),
          _HabitCard(
            icon: Icons.auto_stories,
            label: 'Papier',
            subtitle: 'Livres physiques',
            value: 'papier',
            selected: selectedHabit == 'papier',
            onTap: () => onSelected('papier'),
          ),
          const SizedBox(height: AppSpace.m),
          _HabitCard(
            icon: Icons.sync_alt,
            label: 'Un mix',
            subtitle: 'Les deux !',
            value: 'mix',
            selected: selectedHabit == 'mix',
            onTap: () => onSelected('mix'),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    selectedHabit != null ? AppColors.primary : Colors.grey.shade400,
                foregroundColor: AppColors.white,
                padding: const EdgeInsets.symmetric(vertical: AppSpace.m),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
              ),
              onPressed: selectedHabit != null ? onNext : null,
              child: const Text(
                'Suivant',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HabitCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final String value;
  final bool selected;
  final VoidCallback onTap;

  const _HabitCard({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.value,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.l,
          vertical: 16,
        ),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.1)
              : Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.l),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.primary, size: 32),
            const SizedBox(width: AppSpace.m),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
            const Spacer(),
            if (selected)
              const Icon(Icons.check_circle, color: AppColors.primary, size: 24),
          ],
        ),
      ),
    );
  }
}
