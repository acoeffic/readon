// lib/widgets/remote_badge_image.dart
//
// Widget générique pour afficher l'image PNG d'un badge depuis le storage
// Supabase. L'URL est résolue à partir de l'ID :
//   1. Si le badgeId est mappé dans `_lastFolderFiles`, on pointe vers
//      `Image/badge/Last/<filename>` (visuels finalisés).
//   2. Sinon, fallback sur `Image/badge/Nouveau/<id>.png` (anciens visuels
//      en cours de migration).
// Si le badge est verrouillé, un filtre greyscale + opacité réduite est
// appliqué. En cas d'échec de chargement, fallback sur l'emoji du badge
// entouré d'un cercle thématique.

import 'package:flutter/material.dart';

import '../config/env.dart';
import '../features/badges/widgets/first_book_badge_painter.dart'
    show ComebackBadge;
import '../models/user_search_result.dart';
import '../services/badges_service.dart';

class RemoteBadgeImage extends StatelessWidget {
  final String badgeId;
  final String? badgeCategory;
  final bool isUnlocked;
  final String? fallbackEmoji;
  final String? fallbackColorHex;
  final double size;

  const RemoteBadgeImage({
    super.key,
    required this.badgeId,
    this.badgeCategory,
    this.isUnlocked = true,
    this.fallbackEmoji,
    this.fallbackColorHex,
    this.size = 100,
  });

  RemoteBadgeImage.fromBadge(
    UserBadge badge, {
    super.key,
    this.size = 100,
  })  : badgeId = badge.id,
        badgeCategory = badge.category,
        isUnlocked = badge.isUnlocked,
        fallbackEmoji = badge.icon,
        fallbackColorHex = badge.color;

  RemoteBadgeImage.fromSimple(
    UserBadgeSimple badge, {
    super.key,
    this.size = 100,
  })  : badgeId = badge.id,
        badgeCategory = null,
        isUnlocked = true,
        fallbackEmoji = badge.icon,
        fallbackColorHex = badge.color;

  static const ColorFilter _greyscale = ColorFilter.matrix(<double>[
    0.2126, 0.7152, 0.0722, 0, 0,
    0.2126, 0.7152, 0.0722, 0, 0,
    0.2126, 0.7152, 0.0722, 0, 0,
    0,      0,      0,      1, 0,
  ]);

  /// Mapping badgeId → nom de fichier dans `Image/badge/Last/`.
  /// Visuels finalisés. Tout badge absent retombe sur l'ancien dossier
  /// `Nouveau/` via le pattern `<badgeId>.png`.
  static const Map<String, String> _lastFolderFiles = {
    // Livres terminés
    'books_1': 'badge-01-premier-chapitre.png',
    'books_5': 'badge-02-apprenti-lecteur.png',
    'books_10': 'badge-03-lecteur-confirme.png',
    'books_25': 'badge-04-bibliophile.png',
    'books_50': 'badge-05-devoreur-de-pages.png',
    'books_100': 'badge-06-centenaire.png',
    'books_200': 'badge-07-legende-litteraire.png',
    'books_500': 'badge-08-bibliotheque-vivante.png',
    // Temps de lecture
    'time_first': 'badge-09-premiere-session.png',
    'time_1h': 'badge-10-une-heure-de-magie.png',
    'time_10h': 'badge-11-lecteur-du-dimanche.png',
    'time_50h': 'badge-12-passionne.png',
    'time_100h': 'badge-13-centurion.png',
    'time_250h': 'badge-14-marathonien.png',
    'time_500h': 'badge-15-demi-millenaire.png',
    'time_1000h': 'badge-16-millenaire.png',
    // Streaks
    'streak_3_days': 'badge-17-premier-pas.png',
    'streak_7_days': 'badge-18-une-semaine.png',
    'streak_14_days': 'badge-19-deux-semaines.png',
    'streak_30_days': 'badge-20-un-mois.png',
    'streak_60_days': 'badge-21-incassable.png',
    'streak_90_days': 'badge-22-trimestre-parfait.png',
    'streak_180_days': 'badge-23-semi-annuel.png',
    'streak_365_days': 'badge-24-annee-complete.png',
    'streak_500_days': 'badge-25-streak-legendaire.png',
    // Objectifs
    'goal_created': 'badge-26-objectif-fixe.png',
    'goal_achieved_1': 'badge-27-mission-accomplie.png',
    'goal_achieved_5': 'badge-28-performeur.png',
    // Social — abonnements / amis
    'social_follow_5': 'badge-29-sociable.png',
    'social_follow_20': 'badge-30-networker.png',
    // Social — interactions
    'social_first_like': 'badge-31-premiere-reaction.png',
    'social_comments_10': 'badge-32-bavard.png',
    // Social — followers
    'social_followers_10': 'badge-33-influenceur.png',
    'social_followers_100': 'badge-34-influenceur-pro.png',
    'social_followers_500': 'badge-35-star.png',
    'social_followers_1k': 'badge-36-celebrite.png',
    // Social — reviews / parrainage / clubs
    'social_reviews_50': 'badge-37-critique-litteraire.png',
    'social_invite_10': 'badge-38-parrain-d-or.png',
    'social_invite_25': 'badge-39-parrain-platine.png',
    'social_club_founder': 'badge-40-fondateur-de-club.png',
    'social_club_leader': 'badge-41-leader.png',
    // Genres — exploration
    'genre_explorer_3': 'badge-42-explorateur.png',
    'genre_explorer_5': 'badge-43-eclectique.png',
    'genre_fiction_5': 'badge-44-amateur-de-fiction.png',
    'genre_nonfiction_5': 'badge-45-esprit-curieux.png',
    // Genres — maîtrise
    'genre_thriller_maitre': 'badge-46-maitre-du-thriller.png',
    'genre_romance_maitre': 'badge-47-maitre-de-la-romance.png',
    'genre_sf_maitre': 'badge-48-maitre-de-la-sf.png',
    'genre_fantasy_maitre': 'badge-49-maitre-de-la-fantasy.png',
    'genre_polar_maitre': 'badge-50-maitre-du-polar.png',
  };

  String get _imageUrl {
    final lastFile = _lastFolderFiles[badgeId];
    if (lastFile != null) {
      return '${Env.supabaseStorageUrl}/asset/Image/badge/Last/$lastFile';
    }
    return '${Env.supabaseStorageUrl}/asset/Image/badge/Nouveau/$badgeId.png';
  }

  bool get _isComeback => badgeCategory == 'comeback';

  @override
  Widget build(BuildContext context) {
    if (_isComeback) {
      return ComebackBadge(
        badgeId: badgeId,
        size: size,
        isLocked: !isUnlocked,
        fallbackEmoji: fallbackEmoji,
        fallbackColorHex: fallbackColorHex,
      );
    }

    Widget image = Image.network(
      _imageUrl,
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => _emojiFallback(context),
    );

    if (!isUnlocked) {
      image = ColorFiltered(
        colorFilter: _greyscale,
        child: Opacity(opacity: 0.45, child: image),
      );
    }

    return SizedBox(width: size, height: size, child: image);
  }

  Widget _emojiFallback(BuildContext context) {
    final color = _hexToColor(fallbackColorHex);
    final emoji = fallbackEmoji ?? '🏅';
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: isUnlocked
            ? color.withValues(alpha: 0.2)
            : Theme.of(context).colorScheme.surfaceContainerHighest,
        shape: BoxShape.circle,
        border: Border.all(
          color: isUnlocked
              ? color
              : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
          width: 3,
        ),
      ),
      child: Center(
        child: Text(
          emoji,
          style: TextStyle(
            fontSize: size * 0.44,
            color: isUnlocked
                ? null
                : Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.4),
          ),
        ),
      ),
    );
  }

  static Color _hexToColor(String? hex) {
    if (hex == null) return Colors.grey;
    final cleaned = hex.replaceAll('#', '');
    if (cleaned.length == 6) {
      return Color(int.parse('FF$cleaned', radix: 16));
    }
    if (cleaned.length == 8) {
      return Color(int.parse(cleaned, radix: 16));
    }
    return Colors.grey;
  }
}
