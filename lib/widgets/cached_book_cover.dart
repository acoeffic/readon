// lib/widgets/cached_book_cover.dart
// Widget réutilisable pour afficher les couvertures de livres avec cache

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// Widget optimisé pour afficher les couvertures de livres avec cache disque.
/// Évite de re-télécharger les images à chaque affichage.
class CachedBookCover extends StatelessWidget {
  final String? imageUrl;
  final double width;
  final double height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final Widget? placeholder;
  final Widget? errorWidget;

  const CachedBookCover({
    super.key,
    required this.imageUrl,
    this.width = 50,
    this.height = 70,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.placeholder,
    this.errorWidget,
  });

  @override
  Widget build(BuildContext context) {
    final defaultPlaceholder = Container(
      width: width,
      height: height,
      color: Colors.grey[200],
      child: Icon(
        Icons.book,
        size: width * 0.5,
        color: Colors.grey[400],
      ),
    );

    final defaultErrorWidget = Container(
      width: width,
      height: height,
      color: Colors.grey[200],
      child: Icon(
        Icons.book,
        size: width * 0.5,
        color: Colors.grey[400],
      ),
    );

    // Si pas d'URL, afficher le placeholder
    if (imageUrl == null || imageUrl!.isEmpty) {
      return borderRadius != null
          ? ClipRRect(
              borderRadius: borderRadius!,
              child: defaultPlaceholder,
            )
          : defaultPlaceholder;
    }

    final image = CachedNetworkImage(
      imageUrl: imageUrl!,
      width: width,
      height: height,
      fit: fit,
      placeholder: (context, url) => placeholder ?? defaultPlaceholder,
      errorWidget: (context, url, error) => errorWidget ?? defaultErrorWidget,
      fadeInDuration: const Duration(milliseconds: 200),
      fadeOutDuration: const Duration(milliseconds: 200),
    );

    if (borderRadius != null) {
      return ClipRRect(
        borderRadius: borderRadius!,
        child: image,
      );
    }

    return image;
  }
}
