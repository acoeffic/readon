// lib/pages/feed/widgets/people_you_may_know_section.dart
//
// Section "Tu pourrais connaître" du feed. Carrousel horizontal de profils
// suggérés avec breakdown des raisons (amis communs, livres communs, etc.)
// affiché sous le nom pour expliciter pourquoi le profil est suggéré.
//
// L'état des demandes envoyées / en cours est porté par le parent (FeedPage)
// pour que plusieurs instances du carrousel restent cohérentes entre elles.

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../services/people_you_may_know_service.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/cached_profile_avatar.dart';
import '../../../widgets/mutual_friends_badge.dart';
import '../../friends/friend_profile_page.dart';
import '../../friends/people_you_may_know_page.dart';

class PeopleYouMayKnowSection extends StatelessWidget {
  final List<PeopleYouMayKnow> suggestions;
  final Set<String> requestedIds;
  final Set<String> processingIds;
  final void Function(String userId) onFollow;
  final VoidCallback? onSeeAll;

  /// Si false, on cache le bouton "Voir tout". Sert à éviter une boucle
  /// d'auto-navigation quand cette section est rendue *à l'intérieur* de
  /// [PeopleYouMayKnowPage] (qui est la cible par défaut du bouton).
  final bool showSeeAll;

  const PeopleYouMayKnowSection({
    super.key,
    required this.suggestions,
    required this.requestedIds,
    required this.processingIds,
    required this.onFollow,
    this.onSeeAll,
    this.showSeeAll = true,
  });

  void _openSeeAll(BuildContext context) {
    if (onSeeAll != null) {
      onSeeAll!();
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const PeopleYouMayKnowPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (suggestions.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('🤝', style: TextStyle(fontSize: 16)),
            const SizedBox(width: AppSpace.s),
            const Expanded(
              child: Text(
                'Tu pourrais connaître',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (showSeeAll)
              TextButton(
                onPressed: () => _openSeeAll(context),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Voir tout'),
              ),
          ],
        ),
        const SizedBox(height: AppSpace.s),
        SizedBox(
          height: 240,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.zero,
            itemCount: suggestions.length,
            separatorBuilder: (_, __) => const SizedBox(width: AppSpace.m),
            itemBuilder: (_, i) {
              final s = suggestions[i];
              return _PymkCard(
                suggestion: s,
                isRequested: requestedIds.contains(s.userId),
                isProcessing: processingIds.contains(s.userId),
                onFollow: () => onFollow(s.userId),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => FriendProfilePage(
                      userId: s.userId,
                      initialName: s.displayName,
                      initialAvatar: s.avatarUrl,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: AppSpace.l),
      ],
    );
  }
}

class _PymkCard extends StatelessWidget {
  final PeopleYouMayKnow suggestion;
  final bool isRequested;
  final bool isProcessing;
  final VoidCallback onFollow;
  final VoidCallback onTap;

  const _PymkCard({
    required this.suggestion,
    required this.isRequested,
    required this.isProcessing,
    required this.onFollow,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final reason = suggestion.topReason;
    final mutual = suggestion.mutualSummary;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 180,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.l),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.12),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CachedProfileAvatar(
              imageUrl: suggestion.avatarUrl,
              userName: suggestion.displayName,
              radius: 28,
              backgroundColor: AppColors.primary.withValues(alpha: 0.15),
              textColor: AppColors.primary,
              fontSize: 22,
            ),
            const SizedBox(height: 8),
            Text(
              suggestion.displayName,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                height: 1.2,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            // Stats compactes
            _StatsRow(
              booksFinished: suggestion.booksFinished,
              currentFlow: suggestion.currentFlow,
            ),
            const SizedBox(height: 6),
            // Avatars d'amis communs si dispo, sinon simple texte de la raison
            if (!mutual.isEmpty)
              MutualFriendsBadge(
                summary: mutual,
                fontSize: 11,
                avatarRadius: 8,
              )
            else if (reason != null)
              Text(
                reason.label(),
                style: TextStyle(
                  fontSize: 11.5,
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                  height: 1.2,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            const Spacer(),
            // Bouton Suivre / En attente
            SizedBox(
              width: double.infinity,
              height: 32,
              child: isProcessing
                  ? const Center(
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : ElevatedButton(
                      onPressed: isRequested ? null : onFollow,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isRequested
                            ? Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest
                            : AppColors.primary,
                        foregroundColor:
                            isRequested ? Colors.grey.shade700 : Colors.white,
                        elevation: 0,
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                      ),
                      child: Text(
                        isRequested
                            ? 'En attente'
                            : '+ ${AppLocalizations.of(context).addButton}',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  final int booksFinished;
  final int currentFlow;

  const _StatsRow({required this.booksFinished, required this.currentFlow});

  @override
  Widget build(BuildContext context) {
    if (booksFinished == 0 && currentFlow == 0) {
      return const SizedBox(height: 14);
    }
    final color =
        Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.65);
    return Row(
      children: [
        if (booksFinished > 0) ...[
          const Text('📖', style: TextStyle(fontSize: 11)),
          const SizedBox(width: 3),
          Text('$booksFinished',
              style: TextStyle(
                  fontSize: 12, color: color, fontWeight: FontWeight.w600)),
        ],
        if (booksFinished > 0 && currentFlow > 0) const SizedBox(width: 8),
        if (currentFlow > 0) ...[
          const Text('🔥', style: TextStyle(fontSize: 11)),
          const SizedBox(width: 3),
          Text('${currentFlow}j',
              style: TextStyle(
                  fontSize: 12, color: color, fontWeight: FontWeight.w600)),
        ],
      ],
    );
  }
}
