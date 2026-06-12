// lib/pages/feed/widgets/discover_readers_section.dart
//
// Section "Lecteurs à découvrir" affichée dans le feed. Carrousel horizontal
// de profils suggérés avec mini-stats, badge amis-en-commun et bouton suivre.
// Tap sur la carte → friend profile, tap sur le bouton → envoie demande.

import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../services/contacts_service.dart';
import '../../../services/mutual_friends_service.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/cached_profile_avatar.dart';
import '../../../widgets/mutual_friends_badge.dart';
import '../../friends/friend_profile_page.dart';

class DiscoverReadersSection extends StatefulWidget {
  final List<Map<String, dynamic>> readers;
  final Map<String, MutualFriendsSummary> mutuals;
  final VoidCallback? onSeeAll;

  const DiscoverReadersSection({
    super.key,
    required this.readers,
    required this.mutuals,
    this.onSeeAll,
  });

  @override
  State<DiscoverReadersSection> createState() => _DiscoverReadersSectionState();
}

class _DiscoverReadersSectionState extends State<DiscoverReadersSection> {
  final _contactsService = ContactsService();
  final Set<String> _requested = {};
  final Set<String> _processing = {};

  @override
  void initState() {
    super.initState();
    _prefetchExistingRelations();
  }

  @override
  void didUpdateWidget(covariant DiscoverReadersSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.readers, widget.readers)) {
      _prefetchExistingRelations();
    }
  }

  Future<void> _prefetchExistingRelations() async {
    final ids = widget.readers
        .map((r) => r['user_id'] as String? ?? '')
        .where((id) => id.isNotEmpty);
    if (ids.isEmpty) return;
    final related = await _contactsService.getExistingRelationUserIds(ids);
    if (!mounted || related.isEmpty) return;
    setState(() => _requested.addAll(related));
  }

  Future<void> _follow(String userId) async {
    if (_requested.contains(userId) || _processing.contains(userId)) return;
    setState(() => _processing.add(userId));
    final result =
        await _contactsService.sendFriendRequestDetailed(userId);
    if (!mounted) return;
    setState(() {
      _processing.remove(userId);
      if (result != SendFriendRequestResult.error) _requested.add(userId);
    });
    final l = AppLocalizations.of(context);
    if (result == SendFriendRequestResult.sent) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l.invitationSentShort),
          duration: const Duration(seconds: 2),
        ),
      );
    } else if (result == SendFriendRequestResult.error) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l.cannotAddFriend),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.readers.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('✨', style: TextStyle(fontSize: 16)),
            const SizedBox(width: AppSpace.s),
            Expanded(
              child: Text(
                'Lecteurs à découvrir',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            if (widget.onSeeAll != null)
              TextButton(
                onPressed: widget.onSeeAll,
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
          height: 220,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.zero,
            itemCount: widget.readers.length,
            separatorBuilder: (_, __) => const SizedBox(width: AppSpace.m),
            itemBuilder: (_, i) {
              final r = widget.readers[i];
              final id = r['user_id'] as String? ?? '';
              return _ReaderCard(
                reader: r,
                mutual: widget.mutuals[id] ?? MutualFriendsSummary.empty,
                isRequested: _requested.contains(id),
                isProcessing: _processing.contains(id),
                onFollow: () => _follow(id),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => FriendProfilePage(
                        userId: id,
                        initialName: r['display_name'] as String?,
                        initialAvatar: r['avatar_url'] as String?,
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
        const SizedBox(height: AppSpace.l),
      ],
    );
  }
}

class _ReaderCard extends StatelessWidget {
  final Map<String, dynamic> reader;
  final MutualFriendsSummary mutual;
  final bool isRequested;
  final bool isProcessing;
  final VoidCallback onFollow;
  final VoidCallback onTap;

  const _ReaderCard({
    required this.reader,
    required this.mutual,
    required this.isRequested,
    required this.isProcessing,
    required this.onFollow,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final displayName = reader['display_name'] as String? ?? 'Un lecteur';
    final avatarUrl = reader['avatar_url'] as String?;
    final booksFinished = (reader['books_finished'] as num?)?.toInt() ?? 0;
    final currentFlow = (reader['current_flow'] as num?)?.toInt() ?? 0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 170,
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
              imageUrl: avatarUrl,
              userName: displayName,
              radius: 26,
              backgroundColor: AppColors.primary.withValues(alpha: 0.15),
              textColor: AppColors.primary,
              fontSize: 20,
            ),
            const SizedBox(height: 8),
            Text(
              displayName,
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
            Row(
              children: [
                if (booksFinished > 0) ...[
                  const Text('📖', style: TextStyle(fontSize: 11)),
                  const SizedBox(width: 3),
                  Text(
                    '$booksFinished',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.7),
                    ),
                  ),
                ],
                if (booksFinished > 0 && currentFlow > 0)
                  const SizedBox(width: 8),
                if (currentFlow > 0) ...[
                  const Text('🔥', style: TextStyle(fontSize: 11)),
                  const SizedBox(width: 3),
                  Text(
                    '${currentFlow}j',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ],
            ),
            // Amis communs (si présents) — sinon spacer pour aligner les boutons
            if (!mutual.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: MutualFriendsBadge(
                  summary: mutual,
                  fontSize: 10.5,
                  avatarRadius: 7.5,
                ),
              )
            else
              const SizedBox(height: 6),
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
