// pages/onboarding/widgets/step_suggested_readers.dart
// Étape d'onboarding : suggérer des lecteurs actifs à suivre

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/cached_profile_avatar.dart';
import '../../../widgets/cached_book_cover.dart';
import '../../../services/contacts_service.dart';

class StepSuggestedReaders extends StatefulWidget {
  final String? readingHabit;
  final VoidCallback onNext;
  final VoidCallback onSkip;

  const StepSuggestedReaders({
    super.key,
    this.readingHabit,
    required this.onNext,
    required this.onSkip,
  });

  @override
  State<StepSuggestedReaders> createState() => _StepSuggestedReadersState();
}

class _StepSuggestedReadersState extends State<StepSuggestedReaders> {
  final _supabase = Supabase.instance.client;
  final _contactsService = ContactsService();

  List<Map<String, dynamic>> _readers = [];
  final Set<String> _followedIds = {};
  bool _loading = true;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _loadSuggestedReaders();
  }

  Future<void> _loadSuggestedReaders() async {
    try {
      final result = await _supabase.rpc(
        'get_suggested_readers',
        params: {
          'p_reading_habit': widget.readingHabit,
          'p_limit': 15,
        },
      );
      if (mounted) {
        setState(() {
          _readers = List<Map<String, dynamic>>.from(result ?? []);
          _loading = false;
        });
        // Si aucun lecteur trouvé, passer automatiquement
        if (_readers.isEmpty) {
          widget.onNext();
        }
      }
    } catch (e) {
      debugPrint('Erreur loadSuggestedReaders: $e');
      if (mounted) {
        setState(() => _loading = false);
        widget.onNext();
      }
    }
  }

  void _toggleFollow(String userId) {
    setState(() {
      if (_followedIds.contains(userId)) {
        _followedIds.remove(userId);
      } else {
        _followedIds.add(userId);
      }
    });
  }

  Future<void> _confirmAndContinue() async {
    if (_followedIds.isEmpty) {
      widget.onNext();
      return;
    }

    setState(() => _sending = true);

    // Envoyer les friend requests en parallèle
    await Future.wait(
      _followedIds.map((id) => _contactsService.sendFriendRequest(id)),
    );

    if (mounted) {
      setState(() => _sending = false);
      widget.onNext();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Padding(
      padding: const EdgeInsets.all(AppSpace.l),
      child: Column(
        children: [
          const SizedBox(height: AppSpace.l),

          // Header
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
              color: AppColors.accentLight,
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Icon(
                Icons.people_outline,
                color: AppColors.primary,
                size: 36,
              ),
            ),
          ),
          const SizedBox(height: AppSpace.l),
          Text(
            'Découvre des lecteurs',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                ),
          ),
          const SizedBox(height: AppSpace.s),
          Text(
            'Suis des lecteurs actifs pour remplir ton feed\ndès le premier jour',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15,
              color: Colors.black54,
              height: 1.4,
            ),
          ),

          // Counter
          if (_followedIds.isNotEmpty) ...[
            const SizedBox(height: AppSpace.m),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Text(
                '${_followedIds.length} lecteur${_followedIds.length > 1 ? 's' : ''} sélectionné${_followedIds.length > 1 ? 's' : ''}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],

          const SizedBox(height: AppSpace.l),

          // Liste de lecteurs
          Expanded(
            child: ListView.builder(
              itemCount: _readers.length,
              itemBuilder: (context, index) {
                final reader = _readers[index];
                final userId = reader['user_id'] as String;
                final isFollowed = _followedIds.contains(userId);
                return _ReaderCard(
                  reader: reader,
                  isFollowed: isFollowed,
                  onToggle: () => _toggleFollow(userId),
                );
              },
            ),
          ),

          const SizedBox(height: AppSpace.m),

          // Bouton continuer
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.white,
                padding: const EdgeInsets.symmetric(vertical: AppSpace.m),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
              ),
              onPressed: _sending ? null : _confirmAndContinue,
              child: _sending
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      _followedIds.isEmpty
                          ? 'Continuer'
                          : 'Suivre ${_followedIds.length} lecteur${_followedIds.length > 1 ? 's' : ''} et continuer',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600),
                    ),
            ),
          ),

          // Lien passer
          TextButton(
            onPressed: widget.onSkip,
            child: const Text(
              'Passer cette étape',
              style: TextStyle(
                fontSize: 14,
                color: Colors.black45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReaderCard extends StatelessWidget {
  final Map<String, dynamic> reader;
  final bool isFollowed;
  final VoidCallback onToggle;

  const _ReaderCard({
    required this.reader,
    required this.isFollowed,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final displayName = reader['display_name'] as String? ?? 'Un lecteur';
    final avatarUrl = reader['avatar_url'] as String?;
    final booksFinished = (reader['books_finished'] as num?)?.toInt() ?? 0;
    final currentFlow = (reader['current_flow'] as num?)?.toInt() ?? 0;
    final currentBookTitle = reader['current_book_title'] as String?;
    final currentBookCover = reader['current_book_cover'] as String?;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isFollowed
            ? AppColors.primary.withValues(alpha: 0.06)
            : Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.m),
        border: Border.all(
          color: isFollowed
              ? AppColors.primary.withValues(alpha: 0.3)
              : Colors.grey.shade200,
        ),
      ),
      child: Row(
        children: [
          // Avatar
          CachedProfileAvatar(
            imageUrl: avatarUrl,
            userName: displayName,
            radius: 22,
            backgroundColor: AppColors.primary.withValues(alpha: 0.15),
            textColor: AppColors.primary,
            fontSize: 16,
          ),
          const SizedBox(width: 12),

          // Infos
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    if (booksFinished > 0) ...[
                      Icon(Icons.book_outlined,
                          size: 13, color: Colors.grey.shade600),
                      const SizedBox(width: 3),
                      Text(
                        '$booksFinished livre${booksFinished > 1 ? 's' : ''}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                    if (booksFinished > 0 && currentFlow > 0)
                      Text(' · ',
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey.shade400)),
                    if (currentFlow > 0) ...[
                      Icon(Icons.local_fire_department,
                          size: 13, color: Colors.orange.shade400),
                      const SizedBox(width: 2),
                      Text(
                        '${currentFlow}j',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ],
                ),
                if (currentBookTitle != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (currentBookCover != null)
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: CachedBookCover(
                            imageUrl: currentBookCover,
                            width: 20,
                            height: 28,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      Expanded(
                        child: Text(
                          'Lit : $currentBookTitle',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.primary.withValues(alpha: 0.8),
                            fontStyle: FontStyle.italic,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(width: 8),

          // Bouton suivre
          GestureDetector(
            onTap: onToggle,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isFollowed ? AppColors.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(AppRadius.pill),
                border: Border.all(
                  color: isFollowed
                      ? AppColors.primary
                      : AppColors.primary.withValues(alpha: 0.5),
                ),
              ),
              child: Text(
                isFollowed ? 'Suivi' : 'Suivre',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isFollowed ? Colors.white : AppColors.primary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
