// pages/feed/widgets/friend_activity_card.dart
// Widget d'activité des amis, extrait et structuré

import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/progress_bar.dart';

class FriendActivityCard extends StatelessWidget {
  final Map<String, dynamic> activity;

  const FriendActivityCard({super.key, required this.activity});

  @override
  Widget build(BuildContext context) {
    final userName = activity['friend_name'] ?? 'Ami';
    final bookTitle = activity['book_title'] ?? 'Livre';
    final pages = activity['pages'] ?? 0;
    final progress = (activity['progress'] ?? 0) / 100;
    final timestamp = DateTime.tryParse(activity['created_at'] ?? '') ?? DateTime.now();

    return Container(
      padding: const EdgeInsets.all(AppSpace.m),
      margin: const EdgeInsets.only(bottom: AppSpace.m),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppRadius.l),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.primary,
                child: Icon(Icons.person, color: AppColors.white),
              ),
              const SizedBox(width: AppSpace.m),
              Expanded(
                child: Text(
                  userName,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSpace.m),
          Text('lit "$bookTitle"', style: Theme.of(context).textTheme.bodyMedium),
          Text('$pages pages lues', style: Theme.of(context).textTheme.bodyMedium),

          const SizedBox(height: AppSpace.s),
          ProgressBar(value: progress),

          const SizedBox(height: AppSpace.s),
          Text(
            _formatTimestamp(timestamp),
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppColors.textSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 1) return "À l'instant";
    if (diff.inMinutes < 60) return "${diff.inMinutes} min";
    if (diff.inHours < 24) return "${diff.inHours} h";
    if (diff.inDays < 7) return "${diff.inDays} jours";
    return "${time.day}/${time.month}/${time.year}";
  }
}