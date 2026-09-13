// lib/utils/image_ops.dart
//
// Opérations d'image en Dart pur (dart:ui) — aucune dépendance native ni
// package supplémentaire. Utilisé par l'OCR pour :
//   1. produire une copie contrastée/agrandie d'une photo quand la première
//      passe de reconnaissance rend peu de texte ;
//   2. découper la zone surlignée avant de l'envoyer au repli IA vision.

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:path_provider/path_provider.dart';

class ImageOps {
  const ImageOps._();

  /// Côté le plus long autorisé pour la copie « améliorée » envoyée à l'OCR.
  /// Au-delà, ML Kit n'y gagne rien et la mémoire explose sur vieux appareils.
  static const double _maxEnhancedSide = 3000;

  /// Taille en pixels d'un fichier image, sans décoder l'image entière.
  static Future<Size?> readSize(String path) async {
    ui.ImmutableBuffer? buffer;
    ui.ImageDescriptor? descriptor;
    try {
      buffer = await ui.ImmutableBuffer.fromFilePath(path);
      descriptor = await ui.ImageDescriptor.encoded(buffer);
      return Size(descriptor.width.toDouble(), descriptor.height.toDouble());
    } catch (e) {
      debugPrint('ImageOps.readSize: $e');
      return null;
    } finally {
      descriptor?.dispose();
      buffer?.dispose();
    }
  }

  /// Copie de l'image en niveaux de gris + contraste poussé, éventuellement
  /// agrandie si la photo est petite (les petits caractères passent mieux).
  ///
  /// Retourne le chemin du PNG temporaire et le facteur d'échelle appliqué :
  /// `coordonnées_copie = coordonnées_source × scale`.
  static Future<({String path, double scale})?> enhanceForOcr(
    String srcPath,
  ) async {
    final size = await readSize(srcPath);
    if (size == null || size.width < 2 || size.height < 2) return null;

    final longest = math.max(size.width, size.height);
    var scale = longest < 1500 ? 2.0 : 1.0;
    if (longest * scale > _maxEnhancedSide) scale = _maxEnhancedSide / longest;

    final targetW = math.max(1, (size.width * scale).round());
    final targetH = math.max(1, (size.height * scale).round());

    final image = await _decode(srcPath, targetW, targetH);
    if (image == null) return null;

    Uint8List? bytes;
    try {
      bytes = await _render(image, filter: contrastGrayscale(1.6));
    } finally {
      image.dispose();
    }
    if (bytes == null) return null;

    try {
      final dir = await getTemporaryDirectory();
      final file = File(
        '${dir.path}/ocr_enhanced_${DateTime.now().microsecondsSinceEpoch}.png',
      );
      await file.writeAsBytes(bytes, flush: true);
      return (path: file.path, scale: scale);
    } catch (e) {
      debugPrint('ImageOps.enhanceForOcr write: $e');
      return null;
    }
  }

  /// Découpe [rectInImage] (coordonnées pixels de l'image source) et retourne
  /// un PNG. Le rendu est passé en niveaux de gris contrastés : c'est plus
  /// lisible pour un modèle vision et ça divise le poids du PNG.
  static Future<Uint8List?> cropPng(
    String srcPath,
    Rect rectInImage, {
    int maxWidth = 1200,
    bool enhance = true,
  }) async {
    final size = await readSize(srcPath);
    if (size == null) return null;

    final rect = Rect.fromLTRB(
      rectInImage.left.clamp(0.0, size.width),
      rectInImage.top.clamp(0.0, size.height),
      rectInImage.right.clamp(0.0, size.width),
      rectInImage.bottom.clamp(0.0, size.height),
    );
    if (rect.width < 2 || rect.height < 2) return null;

    // On décode déjà à la bonne échelle pour éviter de charger une image
    // 12 Mpx en mémoire juste pour en garder trois lignes.
    var decodeScale = 1.0;
    if (rect.width > maxWidth) decodeScale = maxWidth / rect.width;
    final targetW = math.max(1, (size.width * decodeScale).round());
    final targetH = math.max(1, (size.height * decodeScale).round());

    final image = await _decode(srcPath, targetW, targetH);
    if (image == null) return null;

    try {
      final srcRect = Rect.fromLTRB(
        rect.left * decodeScale,
        rect.top * decodeScale,
        rect.right * decodeScale,
        rect.bottom * decodeScale,
      ).intersect(
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      );
      if (srcRect.width < 2 || srcRect.height < 2) return null;

      return await _render(
        image,
        srcRect: srcRect,
        filter: enhance ? contrastGrayscale(1.3) : null,
      );
    } finally {
      image.dispose();
    }
  }

  /// Matrice « niveaux de gris + contraste » autour du gris moyen.
  static ColorFilter contrastGrayscale(double contrast) {
    const lr = 0.2126, lg = 0.7152, lb = 0.0722;
    final t = 128 * (1 - contrast);
    final r = lr * contrast, g = lg * contrast, b = lb * contrast;
    return ColorFilter.matrix(<double>[
      r, g, b, 0, t, //
      r, g, b, 0, t, //
      r, g, b, 0, t, //
      0, 0, 0, 1, 0, //
    ]);
  }

  static Future<ui.Image?> _decode(
    String path,
    int targetWidth,
    int targetHeight,
  ) async {
    ui.ImmutableBuffer? buffer;
    ui.ImageDescriptor? descriptor;
    try {
      buffer = await ui.ImmutableBuffer.fromFilePath(path);
      descriptor = await ui.ImageDescriptor.encoded(buffer);
      final codec = await descriptor.instantiateCodec(
        targetWidth: targetWidth,
        targetHeight: targetHeight,
      );
      try {
        final frame = await codec.getNextFrame();
        return frame.image;
      } finally {
        codec.dispose();
      }
    } catch (e) {
      debugPrint('ImageOps._decode: $e');
      return null;
    } finally {
      descriptor?.dispose();
      buffer?.dispose();
    }
  }

  static Future<Uint8List?> _render(
    ui.Image image, {
    Rect? srcRect,
    ColorFilter? filter,
  }) async {
    try {
      final src = srcRect ??
          Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());
      final outW = math.max(1, src.width.round());
      final outH = math.max(1, src.height.round());

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final paint = Paint()..filterQuality = FilterQuality.high;
      if (filter != null) paint.colorFilter = filter;
      canvas.drawImageRect(
        image,
        src,
        Rect.fromLTWH(0, 0, outW.toDouble(), outH.toDouble()),
        paint,
      );

      // try/finally imbriqués : `toImage` peut lever (mémoire) sur une grande
      // image, il ne faut pas fuiter les handles natifs au passage.
      final picture = recorder.endRecording();
      final ui.Image rendered;
      try {
        rendered = await picture.toImage(outW, outH);
      } finally {
        picture.dispose();
      }
      try {
        final data = await rendered.toByteData(format: ui.ImageByteFormat.png);
        return data?.buffer.asUint8List();
      } finally {
        rendered.dispose();
      }
    } catch (e) {
      debugPrint('ImageOps._render: $e');
      return null;
    }
  }
}
