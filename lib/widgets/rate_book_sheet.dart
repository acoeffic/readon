// lib/widgets/rate_book_sheet.dart
//
// Bottom sheet de notation d'un livre.
// Couche 1 : étoiles 0.5 à 5 (obligatoire pour enregistrer).
// Couches 2-3 (repliées, optionnelles) : critères à 3 niveaux, tags
// émotionnels, avis texte, "je recommande" / "je relirais", partage amis.
// Retourne le BookRating enregistré, ou null si l'utilisateur passe.
//
// Usage :
//   final rating = await showRateBookSheet(
//     context,
//     bookId: book.id,
//     bookTitle: book.title,
//     existing: myRating, // pour l'édition
//   );

import 'package:flutter/material.dart';
import 'package:lexday/features/badges/services/badges_service.dart';
import 'package:lexday/features/badges/widgets/badge_unlocked_dialog.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_localizations.dart';
import '../models/book_rating.dart';
import '../services/book_ratings_service.dart';
import '../theme/app_theme.dart';
import 'star_rating.dart';

/// Clés neutres stockées en base (voir NOTATION_LIVRES_SPEC.md §5).
const List<String> kEmotionTagKeys = [
  'moving',
  'funny',
  'instructive',
  'comforting',
  'disturbing',
  'gripping',
  'inspiring',
  'dark',
  'poetic',
  'mind_blowing',
];

const int _kMaxEmotionTags = 5;
const String _kIsPublicPrefKey = 'book_rating_is_public_default';

/// Libellé localisé d'un tag émotionnel (clé neutre stockée en base).
/// Réutilisé par le sheet de notation et la carte feed book_rated.
String emotionTagLabel(AppLocalizations l, String key) {
  switch (key) {
    case 'moving':
      return l.emotionMoving;
    case 'funny':
      return l.emotionFunny;
    case 'instructive':
      return l.emotionInstructive;
    case 'comforting':
      return l.emotionComforting;
    case 'disturbing':
      return l.emotionDisturbing;
    case 'gripping':
      return l.emotionGripping;
    case 'inspiring':
      return l.emotionInspiring;
    case 'dark':
      return l.emotionDark;
    case 'poetic':
      return l.emotionPoetic;
    case 'mind_blowing':
      return l.emotionMindBlowing;
    default:
      return key;
  }
}

Future<BookRating?> showRateBookSheet(
  BuildContext context, {
  required int bookId,
  String? bookTitle,
  BookRating? existing,
  bool abandonMode = false,
  int? abandonedAtPercent,
}) async {
  final result = await showModalBottomSheet<BookRating>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => _RateBookSheet(
      bookId: bookId,
      bookTitle: bookTitle,
      existing: existing,
      abandonMode: abandonMode,
      abandonedAtPercent: abandonedAtPercent,
    ),
  );

  // Vérifier les badges de notation (first_rating, ratings_10, reviews_10,
  // eclectic_5) après un enregistrement réussi — non bloquant.
  if (result != null && context.mounted) {
    try {
      final newBadges = await BadgesService().checkAndAwardBadges();
      for (final badge in newBadges) {
        if (!context.mounted) break;
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => BadgeUnlockedDialog(badge: badge),
        );
      }
    } catch (e) {
      debugPrint('Erreur checkAndAwardBadges (non bloquante): $e');
    }
  }

  return result;
}

class _RateBookSheet extends StatefulWidget {
  final int bookId;
  final String? bookTitle;
  final BookRating? existing;
  final bool abandonMode;
  final int? abandonedAtPercent;

  const _RateBookSheet({
    required this.bookId,
    this.bookTitle,
    this.existing,
    this.abandonMode = false,
    this.abandonedAtPercent,
  });

  @override
  State<_RateBookSheet> createState() => _RateBookSheetState();
}

class _RateBookSheetState extends State<_RateBookSheet> {
  final BookRatingsService _ratingsService = BookRatingsService();
  final TextEditingController _reviewController = TextEditingController();

  double _rating = 0;
  bool _submitting = false;
  bool _expanded = false;

  // Couche 2 : critères (null = non renseigné, sinon 1..3)
  int? _writing;
  int? _story;
  int? _pace;
  int? _difficulty;

  // Couche 3
  final Set<String> _selectedTags = {};
  bool? _wouldRecommend;
  bool? _wouldReread;
  bool _isPublic = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _rating = e.rating;
      _writing = e.criteria?['writing'] as int?;
      _story = e.criteria?['story'] as int?;
      _pace = e.criteria?['pace'] as int?;
      _difficulty = e.criteria?['difficulty'] as int?;
      _selectedTags.addAll(e.emotionTags);
      _reviewController.text = e.reviewText ?? '';
      _wouldRecommend = e.wouldRecommend;
      _wouldReread = e.wouldReread;
      _isPublic = e.isPublic;
      _expanded = e.criteria != null ||
          e.emotionTags.isNotEmpty ||
          (e.reviewText?.isNotEmpty ?? false) ||
          e.wouldRecommend != null ||
          e.wouldReread != null;
    } else {
      _loadIsPublicDefault();
    }
  }

  Future<void> _loadIsPublicDefault() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final value = prefs.getBool(_kIsPublicPrefKey);
      if (value != null && mounted) {
        setState(() => _isPublic = value);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _reviewController.dispose();
    super.dispose();
  }

  Map<String, dynamic>? get _criteria {
    final map = <String, dynamic>{
      if (_writing != null) 'writing': _writing,
      if (_story != null) 'story': _story,
      if (_pace != null) 'pace': _pace,
      if (_difficulty != null) 'difficulty': _difficulty,
    };
    return map.isEmpty ? null : map;
  }

  Future<void> _submit() async {
    if (_rating < 0.5 || _submitting) return;
    setState(() => _submitting = true);

    try {
      final reviewText = _reviewController.text.trim();
      final saved = await _ratingsService.upsertRating(
        bookId: widget.bookId,
        rating: _rating,
        criteria: _criteria,
        emotionTags: _selectedTags.toList(),
        reviewText: reviewText.isEmpty ? null : reviewText,
        wouldRecommend: _wouldRecommend,
        wouldReread: _wouldReread,
        isPublic: widget.abandonMode ? false : _isPublic,
        abandoned: widget.abandonMode,
        abandonedAtPercent: widget.abandonedAtPercent,
      );

      // Mémoriser le choix de partage pour la prochaine fois
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_kIsPublicPrefKey, _isPublic);
      } catch (_) {}

      if (!mounted) return;
      final l = AppLocalizations.of(context);
      Navigator.of(context).pop(saved);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l.bookRatingSaved),
          backgroundColor: AppColors.primary,
        ),
      );
    } catch (e) {
      debugPrint('Erreur enregistrement note: $e');
      if (!mounted) return;
      setState(() => _submitting = false);
      final l = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l.bookRatingError),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  Widget _buildCriterionRow({
    required String label,
    required List<String> levelLabels,
    required int? value,
    required ValueChanged<int?> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(label, style: const TextStyle(fontSize: 13)),
          ),
          Expanded(
            child: Row(
              children: [
                for (var level = 1; level <= 3; level++) ...[
                  if (level > 1) const SizedBox(width: 6),
                  Expanded(
                    child: _LevelPill(
                      label: levelLabels[level - 1],
                      selected: value == level,
                      enabled: !_submitting,
                      onTap: () =>
                          onChanged(value == level ? null : level),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleChip({
    required String label,
    required bool? value,
    required ValueChanged<bool?> onChanged,
  }) {
    final selected = value == true;
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected:
          _submitting ? null : (sel) => onChanged(sel ? true : null),
      selectedColor: AppColors.primary.withValues(alpha: 0.15),
      checkmarkColor: AppColors.primary,
    );
  }

  Widget _buildDetailsSection(AppLocalizations l) {
    final mutedColor =
        Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        // Critères à 3 niveaux
        _buildCriterionRow(
          label: l.criteriaWriting,
          levelLabels: [
            l.criteriaLevelWeak,
            l.criteriaLevelGood,
            l.criteriaLevelExcellent
          ],
          value: _writing,
          onChanged: (v) => setState(() => _writing = v),
        ),
        _buildCriterionRow(
          label: l.criteriaStory,
          levelLabels: [
            l.criteriaLevelWeak,
            l.criteriaLevelGood,
            l.criteriaLevelExcellent
          ],
          value: _story,
          onChanged: (v) => setState(() => _story = v),
        ),
        _buildCriterionRow(
          label: l.criteriaPace,
          levelLabels: [l.paceSlow, l.paceBalanced, l.paceFast],
          value: _pace,
          onChanged: (v) => setState(() => _pace = v),
        ),
        _buildCriterionRow(
          label: l.criteriaDifficulty,
          levelLabels: [
            l.difficultyEasy,
            l.difficultyMedium,
            l.difficultyHard
          ],
          value: _difficulty,
          onChanged: (v) => setState(() => _difficulty = v),
        ),
        const SizedBox(height: 8),
        // Tags émotionnels
        Text(
          l.emotionTagsLabel,
          style: TextStyle(fontSize: 13, color: mutedColor),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: kEmotionTagKeys.map((key) {
            final selected = _selectedTags.contains(key);
            final maxReached =
                !selected && _selectedTags.length >= _kMaxEmotionTags;
            return FilterChip(
              label: Text(emotionTagLabel(l, key)),
              selected: selected,
              onSelected: _submitting || maxReached
                  ? null
                  : (sel) => setState(() {
                        if (sel) {
                          _selectedTags.add(key);
                        } else {
                          _selectedTags.remove(key);
                        }
                      }),
              selectedColor: AppColors.primary.withValues(alpha: 0.15),
              checkmarkColor: AppColors.primary,
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        // Avis texte
        TextField(
          controller: _reviewController,
          enabled: !_submitting,
          maxLines: 3,
          maxLength: 500,
          decoration: InputDecoration(
            hintText: l.reviewHint,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        const SizedBox(height: 4),
        // Recommande / relirais
        Wrap(
          spacing: 8,
          children: [
            _buildToggleChip(
              label: l.wouldRecommendLabel,
              value: _wouldRecommend,
              onChanged: (v) => setState(() => _wouldRecommend = v),
            ),
            _buildToggleChip(
              label: l.wouldRereadLabel,
              value: _wouldReread,
              onChanged: (v) => setState(() => _wouldReread = v),
            ),
          ],
        ),
        if (!widget.abandonMode) ...[
          const SizedBox(height: 8),
          // Partage amis (les notes d'abandon ne sont jamais publiées)
          Row(
            children: [
              Expanded(
                child: Text(
                  l.shareWithFriends,
                  style: const TextStyle(fontSize: 14),
                ),
              ),
              Switch(
                value: _isPublic,
                activeThumbColor: AppColors.primary,
                onChanged: _submitting
                    ? null
                    : (v) => setState(() => _isPublic = v),
              ),
            ],
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final viewInsets = MediaQuery.of(context).viewInsets;

    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).dividerColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                widget.abandonMode
                    ? l.abandonSheetTitle
                    : widget.bookTitle != null
                        ? l.rateBookSheetTitleWithBook(widget.bookTitle!)
                        : l.rateBookSheetTitle,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                widget.abandonMode
                    ? l.abandonSheetSubtitle
                    : l.rateBookSheetSubtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 24),
              Center(
                child: StarRating(
                  rating: _rating,
                  size: 44,
                  onChanged: _submitting
                      ? null
                      : (value) => setState(() => _rating = value),
                ),
              ),
              const SizedBox(height: 16),
              // Couches 2-3, repliées par défaut
              if (_rating >= 0.5) ...[
                if (!_expanded)
                  TextButton.icon(
                    onPressed: _submitting
                        ? null
                        : () => setState(() => _expanded = true),
                    icon: const Icon(Icons.expand_more, size: 18),
                    label: Text(l.rateBookRefine),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primary,
                    ),
                  )
                else
                  _buildDetailsSection(l),
                const SizedBox(height: 8),
              ],
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _rating < 0.5 || _submitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _submitting
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(Colors.white),
                          ),
                        )
                      : Text(l.save),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed:
                    _submitting ? null : () => Navigator.of(context).pop(),
                child: Text(l.later),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LevelPill extends StatelessWidget {
  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  const _LevelPill({
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected
                ? AppColors.primary
                : Theme.of(context).dividerColor,
          ),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected
                ? AppColors.primary
                : Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}
