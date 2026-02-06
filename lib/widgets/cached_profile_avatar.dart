// lib/widgets/cached_profile_avatar.dart
// Widget réutilisable pour afficher les avatars de profil avec cache

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme/app_theme.dart';

/// Widget optimisé pour afficher les avatars de profil avec cache disque.
/// Évite de re-télécharger les images à chaque affichage et gère les erreurs.
class CachedProfileAvatar extends StatelessWidget {
  final String? imageUrl;
  final String? userName;
  final double radius;
  final Color? backgroundColor;
  final Color? textColor;
  final double? fontSize;
  final BoxDecoration? decoration;

  const CachedProfileAvatar({
    super.key,
    required this.imageUrl,
    this.userName,
    this.radius = 20,
    this.backgroundColor,
    this.textColor,
    this.fontSize,
    this.decoration,
  });

  String get _initial {
    if (userName == null || userName!.isEmpty) return '?';
    return userName![0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = backgroundColor ??
        (Theme.of(context).brightness == Brightness.dark
            ? AppColors.primary.withValues(alpha: 0.3)
            : AppColors.primary.withValues(alpha: 0.2));

    final txtColor = textColor ??
        (Theme.of(context).brightness == Brightness.dark
            ? AppColors.primary.withValues(alpha: 0.9)
            : AppColors.primary.withValues(alpha: 0.9));

    final fSize = fontSize ?? (radius * 0.8);

    final fallbackWidget = Center(
      child: Text(
        _initial,
        style: TextStyle(
          color: txtColor,
          fontWeight: FontWeight.bold,
          fontSize: fSize,
        ),
      ),
    );

    // Si pas d'URL valide, afficher l'initiale
    if (imageUrl == null || imageUrl!.isEmpty) {
      if (decoration != null) {
        return Container(
          width: radius * 2,
          height: radius * 2,
          decoration: decoration!.copyWith(
            color: decoration!.color ?? bgColor,
          ),
          child: fallbackWidget,
        );
      }
      return CircleAvatar(
        radius: radius,
        backgroundColor: bgColor,
        child: fallbackWidget,
      );
    }

    // Avec URL, utiliser CachedNetworkImage
    if (decoration != null) {
      return Container(
        width: radius * 2,
        height: radius * 2,
        decoration: decoration,
        child: ClipRRect(
          borderRadius: decoration!.borderRadius as BorderRadius? ??
              BorderRadius.circular(radius),
          child: CachedNetworkImage(
            imageUrl: imageUrl!,
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(
              color: bgColor,
              child: fallbackWidget,
            ),
            errorWidget: (context, url, error) => Container(
              color: bgColor,
              child: fallbackWidget,
            ),
            fadeInDuration: const Duration(milliseconds: 200),
            fadeOutDuration: const Duration(milliseconds: 200),
          ),
        ),
      );
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: bgColor,
      child: ClipOval(
        child: SizedBox(
          width: radius * 2,
          height: radius * 2,
          child: CachedNetworkImage(
            imageUrl: imageUrl!,
            fit: BoxFit.cover,
            placeholder: (context, url) => fallbackWidget,
            errorWidget: (context, url, error) => fallbackWidget,
            fadeInDuration: const Duration(milliseconds: 200),
            fadeOutDuration: const Duration(milliseconds: 200),
          ),
        ),
      ),
    );
  }
}
