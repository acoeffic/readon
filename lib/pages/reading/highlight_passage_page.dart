// lib/pages/reading/highlight_passage_page.dart
//
// Prise de note par photo : on affiche la page photographiée, l'OCR positionne
// chaque mot, et le lecteur surligne au doigt le passage qu'il veut garder.
// Seul le texte surligné est renvoyé à l'annotation (la photo n'est pas
// conservée).

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show setEquals;
import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../models/feature_flags.dart';
import '../../services/ai_service.dart';
import '../../services/native_paywall_service.dart';
import '../../services/ocr_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/image_ops.dart';

/// Ce que la page de surlignage renvoie à l'appelant.
class HighlightPassageResult {
  final String text;

  /// Numéro de page lu en tête/pied de page, si détecté.
  final int? detectedPage;

  const HighlightPassageResult({required this.text, this.detectedPage});
}

class HighlightPassagePage extends StatefulWidget {
  final String imagePath;

  const HighlightPassagePage({super.key, required this.imagePath});

  @override
  State<HighlightPassagePage> createState() => _HighlightPassagePageState();
}

class _HighlightPassagePageState extends State<HighlightPassagePage> {
  final _ocrService = OCRService();
  final _aiService = AiService();

  OcrPageResult? _ocr;
  bool _loading = true;

  /// Index (dans `_ocr.words`) des mots surlignés.
  final Set<int> _selected = <int>{};

  /// État du geste en cours : base de départ, ancre et sens (ajout/retrait).
  Set<int> _dragBase = <int>{};
  int? _dragAnchor;
  bool _dragRemoving = false;

  /// Texte corrigé par l'IA (prioritaire sur l'assemblage OCR tant que la
  /// sélection ne change pas).
  String? _aiText;
  bool _enhancing = false;

  /// Mode « déplacer/zoomer » plutôt que « surligner ».
  bool _moveMode = false;

  final _transformationController = TransformationController();

  @override
  void initState() {
    super.initState();
    _runOcr();
  }

  @override
  void dispose() {
    _ocrService.dispose();
    _transformationController.dispose();
    super.dispose();
  }

  Future<void> _runOcr() async {
    setState(() => _loading = true);
    final result = await _ocrService.recognizePage(widget.imagePath);
    if (!mounted) return;
    setState(() {
      _ocr = result;
      _loading = false;
    });
  }

  // ── Sélection ──

  List<OcrWord> get _selectedWords {
    final ocr = _ocr;
    if (ocr == null) return const [];
    final indexes = _selected.toList()..sort();
    return [
      for (final i in indexes)
        if (i >= 0 && i < ocr.words.length) ocr.words[i],
    ];
  }

  String get _passageText => _aiText ?? OCRService.buildText(_selectedWords);

  /// Le repli IA a besoin d'une image exploitable : si on n'a même pas pu lire
  /// les dimensions de la photo, le bouton reste désactivé.
  bool get _canUseAi {
    final ocr = _ocr;
    return ocr != null && ocr.imageSize.width >= 2 && ocr.imageSize.height >= 2;
  }

  int? _wordAt(Offset pointInImage) {
    final ocr = _ocr;
    if (ocr == null || ocr.words.isEmpty) return null;

    // 1. Le doigt est directement sur un mot (bande verticale élargie pour
    //    pardonner les glissés approximatifs entre deux lignes).
    for (var i = 0; i < ocr.words.length; i++) {
      final rect = ocr.words[i].rect;
      final tolerant = Rect.fromLTRB(
        rect.left,
        rect.top - rect.height * 0.3,
        rect.right,
        rect.bottom + rect.height * 0.3,
      );
      if (tolerant.contains(pointInImage)) return i;
    }

    // 2. Sinon, le mot le plus proche dans un rayon raisonnable.
    var bestIndex = -1;
    var bestDistance = double.infinity;
    for (var i = 0; i < ocr.words.length; i++) {
      final distance = _distanceToRect(pointInImage, ocr.words[i].rect);
      if (distance < bestDistance) {
        bestDistance = distance;
        bestIndex = i;
      }
    }
    if (bestIndex < 0) return null;
    final maxDistance = ocr.words[bestIndex].rect.height * 1.2;
    return bestDistance <= maxDistance ? bestIndex : null;
  }

  static double _distanceToRect(Offset p, Rect r) {
    final dx = math.max(math.max(r.left - p.dx, 0), p.dx - r.right);
    final dy = math.max(math.max(r.top - p.dy, 0), p.dy - r.bottom);
    return math.sqrt(dx * dx + dy * dy);
  }

  void _startSelection(int index) {
    _dragBase = <int>{..._selected};
    _dragAnchor = index;
    _dragRemoving = _selected.contains(index);
    _applyRange(index);
  }

  void _applyRange(int index) {
    final anchor = _dragAnchor;
    if (anchor == null) return;
    final low = math.min(anchor, index);
    final high = math.max(anchor, index);
    final range = <int>{for (var i = low; i <= high; i++) i};

    setState(() {
      _aiText = null;
      _selected
        ..clear()
        ..addAll(
          _dragRemoving ? _dragBase.difference(range) : _dragBase.union(range),
        );
    });
  }

  void _selectAll() {
    final ocr = _ocr;
    if (ocr == null) return;
    setState(() {
      _aiText = null;
      _selected
        ..clear()
        ..addAll(List.generate(ocr.words.length, (i) => i));
    });
  }

  void _clearSelection() {
    setState(() {
      _aiText = null;
      _selected.clear();
    });
  }

  /// Boîte englobante de la sélection (coordonnées image), avec une marge.
  Rect? _selectionBounds() {
    final words = _selectedWords;
    if (words.isEmpty) return null;
    var rect = words.first.rect;
    for (final w in words.skip(1)) {
      rect = rect.expandToInclude(w.rect);
    }
    final margin = rect.height * 0.15 + 12;
    return rect.inflate(margin);
  }

  // ── Repli IA vision ──

  Future<void> _enhanceWithAi() async {
    final ocr = _ocr;
    if (ocr == null || _enhancing) return;

    final l = AppLocalizations.of(context);
    final rect = _selectionBounds() ??
        Rect.fromLTWH(0, 0, ocr.imageSize.width, ocr.imageSize.height);
    if (rect.width < 2 || rect.height < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.highlightImageError)),
      );
      return;
    }

    setState(() => _enhancing = true);
    try {
      final bytes = await ImageOps.cropPng(widget.imagePath, rect);
      if (bytes == null) throw Exception('crop');

      final result = await _aiService.enhanceOcr(
        imageBase64: base64Encode(bytes),
        hintText: OCRService.buildText(_selectedWords),
      );

      if (!mounted) return;
      final text = result.text.trim();
      if (text.isEmpty) {
        setState(() => _enhancing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.highlightNoText)),
        );
        return;
      }
      setState(() {
        _aiText = text;
        _enhancing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.highlightAiDone)),
      );
    } on AiPremiumRequiredException {
      if (!mounted) return;
      setState(() => _enhancing = false);
      NativePaywallService.present(context, highlightedFeature: Feature.aiSummary);
    } on AiSummaryLimitReachedException {
      if (!mounted) return;
      setState(() => _enhancing = false);
      NativePaywallService.present(context, highlightedFeature: Feature.aiSummary);
    } catch (e) {
      if (!mounted) return;
      setState(() => _enhancing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l.errorGeneric(e.toString())),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _validate() {
    final text = _passageText.trim();
    if (text.isEmpty) return;
    Navigator.pop(
      context,
      HighlightPassageResult(
        text: text,
        detectedPage: _ocr?.detectedPageNumber,
      ),
    );
  }

  // ── UI ──

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final ocr = _ocr;
    final hasWords = ocr != null && ocr.words.isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFF101010),
      appBar: AppBar(
        backgroundColor: const Color(0xFF101010),
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          l.highlightTitle,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
        actions: [
          if (hasWords) ...[
            IconButton(
              tooltip: _moveMode ? l.highlightModeSelect : l.highlightModeMove,
              onPressed: () => setState(() => _moveMode = !_moveMode),
              icon: Icon(
                _moveMode ? Icons.zoom_in_map : Icons.brush_outlined,
                color: _moveMode ? AppColors.primary : Colors.white,
              ),
            ),
            IconButton(
              tooltip: l.highlightSelectAll,
              onPressed: _selectAll,
              icon: const Icon(Icons.select_all),
            ),
          ],
        ],
      ),
      body: Column(
        children: [
          Expanded(child: _buildImageArea(l)),
          _buildBottomPanel(l, hasWords),
        ],
      ),
    );
  }

  Widget _buildImageArea(AppLocalizations l) {
    if (_loading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: Colors.white),
            const SizedBox(height: 16),
            Text(
              l.highlightAnalyzing,
              style: const TextStyle(color: Colors.white70),
            ),
          ],
        ),
      );
    }

    final ocr = _ocr;
    if (ocr == null || ocr.imageSize.width < 2 || ocr.imageSize.height < 2) {
      return _buildErrorState(l);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = math.min(
          constraints.maxWidth / ocr.imageSize.width,
          constraints.maxHeight / ocr.imageSize.height,
        );
        final displayWidth = ocr.imageSize.width * scale;
        final displayHeight = ocr.imageSize.height * scale;

        return Center(
          child: InteractiveViewer(
            transformationController: _transformationController,
            panEnabled: _moveMode,
            scaleEnabled: _moveMode,
            minScale: 1,
            maxScale: 5,
            child: SizedBox(
              width: displayWidth,
              height: displayHeight,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Image.file(
                      File(widget.imagePath),
                      fit: BoxFit.fill,
                      cacheWidth: (displayWidth *
                              MediaQuery.of(context).devicePixelRatio *
                              2)
                          .round()
                          .clamp(320, 3000),
                      errorBuilder: (_, __, ___) => _buildErrorState(l),
                    ),
                  ),
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _HighlightPainter(
                        words: ocr.words,
                        // Copie : le painter compare l'ancienne et la nouvelle
                        // sélection, il lui faut deux instances distinctes.
                        selected: <int>{..._selected},
                        scale: scale,
                      ),
                    ),
                  ),
                  if (!_moveMode)
                    Positioned.fill(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTapUp: (details) {
                          final index =
                              _wordAt(details.localPosition / scale);
                          if (index == null) return;
                          _startSelection(index);
                          _dragAnchor = null;
                        },
                        onPanStart: (details) {
                          final index =
                              _wordAt(details.localPosition / scale);
                          if (index == null) {
                            _dragBase = <int>{..._selected};
                            _dragAnchor = null;
                            _dragRemoving = false;
                            return;
                          }
                          _startSelection(index);
                        },
                        onPanUpdate: (details) {
                          final index =
                              _wordAt(details.localPosition / scale);
                          if (index == null) return;
                          // Le sens du geste (ajout ou retrait) a été figé au
                          // démarrage : ici on ne fait que poser l'ancre si le
                          // glissé avait commencé à côté du texte.
                          _dragAnchor ??= index;
                          _applyRange(index);
                        },
                        onPanEnd: (_) => _dragAnchor = null,
                        onPanCancel: () => _dragAnchor = null,
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildErrorState(AppLocalizations l) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.image_not_supported_outlined,
                color: Colors.white54, size: 40),
            const SizedBox(height: 12),
            Text(
              l.highlightImageError,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l.highlightRetakePhoto),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomPanel(AppLocalizations l, bool hasWords) {
    final count = _selected.length;
    final text = _passageText;

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppColors.bgLight,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    _aiText != null ? Icons.auto_awesome : Icons.brush_outlined,
                    size: 18,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _aiText != null
                          ? l.highlightAiLabel
                          : count == 0
                              ? l.highlightHint
                              : count == 1
                                  ? l.highlightOneWord
                                  : l.highlightWordCount(count),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2D2D2D),
                      ),
                    ),
                  ),
                  if (count > 0)
                    TextButton(
                      onPressed: _clearSelection,
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: const Size(0, 32),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(l.highlightClear),
                    ),
                ],
              ),
              if (text.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  constraints: const BoxConstraints(maxHeight: 108),
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: SingleChildScrollView(
                    child: Text(
                      text,
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.35,
                        color: Color(0xFF2D2D2D),
                      ),
                    ),
                  ),
                ),
              ] else if (!hasWords && !_loading) ...[
                const SizedBox(height: 8),
                Text(
                  l.highlightNoText,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _enhancing || _loading || !_canUseAi
                          ? null
                          : _enhanceWithAi,
                      icon: _enhancing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.auto_awesome, size: 18),
                      label: Text(
                        _enhancing
                            ? l.highlightEnhancing
                            : hasWords
                                ? l.highlightEnhanceAi
                                : l.highlightExtractAi,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: text.trim().isEmpty ? null : _validate,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: AppColors.border,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        l.highlightUse,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Dessine le surlignage : un liseré discret sur les mots détectés, un aplat
/// jaune sur la sélection (fusionné par suite de mots pour un rendu continu).
class _HighlightPainter extends CustomPainter {
  final List<OcrWord> words;
  final Set<int> selected;
  final double scale;

  _HighlightPainter({
    required this.words,
    required this.selected,
    required this.scale,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (words.isEmpty) return;

    final detected = Paint()..color = Colors.white.withValues(alpha: 0.10);
    for (var i = 0; i < words.length; i++) {
      if (selected.contains(i)) continue;
      canvas.drawRRect(
        RRect.fromRectAndRadius(_scaled(words[i].rect), const Radius.circular(2)),
        detected,
      );
    }

    final highlight = Paint()..color = const Color(0xFFFFD54F).withValues(alpha: 0.42);
    final outline = Paint()
      ..color = const Color(0xFFFFB300).withValues(alpha: 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    for (final rect in _mergedSelection()) {
      final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(3));
      canvas.drawRRect(rrect, highlight);
      canvas.drawRRect(rrect, outline);
    }
  }

  /// Fusionne les mots sélectionnés consécutifs d'une même ligne en un seul
  /// rectangle, pour éviter l'effet « mots en escalier ».
  List<Rect> _mergedSelection() {
    final indexes = selected.toList()..sort();
    final rects = <Rect>[];

    Rect? current;
    int? previousIndex;
    for (final index in indexes) {
      if (index < 0 || index >= words.length) continue;
      final word = words[index];
      final rect = _scaled(word.rect);

      final continues = current != null &&
          previousIndex != null &&
          index == previousIndex + 1 &&
          words[previousIndex].lineIndex == word.lineIndex;

      if (continues) {
        current = current!.expandToInclude(rect);
      } else {
        if (current != null) rects.add(current);
        current = rect;
      }
      previousIndex = index;
    }
    if (current != null) rects.add(current);
    return rects;
  }

  Rect _scaled(Rect rect) => Rect.fromLTRB(
        rect.left * scale,
        rect.top * scale,
        rect.right * scale,
        rect.bottom * scale,
      );

  @override
  bool shouldRepaint(covariant _HighlightPainter oldDelegate) {
    return oldDelegate.scale != scale ||
        oldDelegate.words != words ||
        !setEquals(oldDelegate.selected, selected);
  }
}
