// lib/pages/reading/capture_passage_flow.dart
//
// Capture d'un passage SANS session de lecture.
//
// Tout le moteur existait déjà (`HighlightPassagePage` ne dépend que d'un
// chemin d'image, `AnnotationService.createAnnotation` accepte un `sessionId`
// nul) — seule la porte d'entrée était enfermée dans la session active. Ce
// fichier est cette porte : photo → surlignage au doigt → sauvegarde.
//
// Le livre est pré-rempli avec le dernier livre lu et corrigeable en un tap :
// demander « quel livre ? » avant la photo réintroduirait exactement la
// friction qu'on cherche à supprimer.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../l10n/app_localizations.dart';
import '../../models/annotation_model.dart';
import '../../models/book.dart';
import '../../services/analytics_service.dart';
import '../../services/annotation_service.dart';
import '../../services/books_service.dart';
import '../../services/google_books_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/cached_book_cover.dart';
import '../../widgets/require_account_sheet.dart';
import '../books/scan_book_cover_page.dart';
import 'highlight_passage_page.dart';

/// Lance le parcours complet de capture. Renvoie `true` si un passage a été
/// enregistré.
Future<bool> capturePassage(
  BuildContext context, {
  String source = 'fab',
}) async {
  if (Supabase.instance.client.auth.currentUser == null) {
    await showRequireAccountSheet(context, source: 'capture_passage');
    return false;
  }

  unawaited(AnalyticsService().track(
    AnalyticsEvent.passageCaptureStarted,
    properties: {'source': source},
  ));

  // 1. La photo d'abord : c'est le geste que l'utilisateur a en tête.
  final picker = ImagePicker();
  XFile? image;
  try {
    image = await picker.pickImage(
      source: ImageSource.camera,
      // Haute résolution : premier levier de qualité pour l'OCR.
      maxWidth: 3000,
      maxHeight: 3000,
      imageQuality: 95,
    );
  } catch (e) {
    debugPrint('capturePassage: pickImage a échoué: $e');
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).capturePassageCameraError),
          backgroundColor: Colors.red,
        ),
      );
    }
    return false;
  }

  if (image == null || !context.mounted) {
    unawaited(AnalyticsService().track(
      AnalyticsEvent.passageCaptureAbandoned,
      properties: {'source': source, 'step': 'photo'},
    ));
    return false;
  }

  // 2. Surlignage au doigt.
  final result = await Navigator.of(context).push<HighlightPassageResult>(
    MaterialPageRoute(
      builder: (_) => HighlightPassagePage(imagePath: image!.path),
    ),
  );

  if (result == null || !context.mounted) {
    unawaited(AnalyticsService().track(
      AnalyticsEvent.passageCaptureAbandoned,
      properties: {'source': source, 'step': 'highlight'},
    ));
    return false;
  }

  // 3. Confirmation légère : texte corrigeable, livre pré-rempli, page.
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _SavePassageSheet(
      text: result.text,
      detectedPage: result.detectedPage,
      imagePath: image!.path,
      source: source,
    ),
  );

  return saved ?? false;
}

class _SavePassageSheet extends StatefulWidget {
  final String text;
  final int? detectedPage;
  final String imagePath;
  final String source;

  const _SavePassageSheet({
    required this.text,
    required this.detectedPage,
    required this.imagePath,
    required this.source,
  });

  @override
  State<_SavePassageSheet> createState() => _SavePassageSheetState();
}

class _SavePassageSheetState extends State<_SavePassageSheet> {
  final _annotationService = AnnotationService();
  final _booksService = BooksService();

  late final TextEditingController _textController;
  late final TextEditingController _pageController;

  List<Book> _books = const [];
  Book? _selectedBook;
  bool _loadingBooks = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.text);
    _pageController = TextEditingController(
      text: widget.detectedPage?.toString() ?? '',
    );
    _loadBooks();
  }

  @override
  void dispose() {
    _textController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadBooks() async {
    final books = await _booksService.getUserBooksByLastRead();
    if (!mounted) return;
    setState(() {
      _books = books;
      // Pré-rempli avec le dernier livre lu : juste dans la grande majorité
      // des cas, corrigeable en un tap sinon.
      _selectedBook = books.isNotEmpty ? books.first : null;
      _loadingBooks = false;
    });
  }

  Future<void> _changeBook() async {
    if (_books.isEmpty) {
      await _scanNewBook();
      return;
    }

    final picked = await showModalBottomSheet<Book>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _PassageBookPicker(books: _books),
    );

    if (picked == null || !mounted) return;
    if (picked.id == _kScanSentinelId) {
      await _scanNewBook();
      return;
    }
    setState(() => _selectedBook = picked);
  }

  /// Bibliothèque vide (ou livre absent) : on ne laisse pas l'utilisateur dans
  /// une impasse, on lui ouvre le scan de couverture.
  Future<void> _scanNewBook() async {
    final googleBook = await Navigator.of(context).push<GoogleBook>(
      MaterialPageRoute(builder: (_) => const ScanBookCoverPage()),
    );
    if (googleBook == null || !mounted) return;

    setState(() => _loadingBooks = true);
    try {
      final book = await _booksService.addBookFromGoogleBooks(googleBook);
      if (!mounted) return;
      setState(() {
        _books = [book, ..._books];
        _selectedBook = book;
        _loadingBooks = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingBooks = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).errorGeneric(e.toString())),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _save() async {
    final l = AppLocalizations.of(context);
    // Capturé avant le pop : une fois la feuille retirée de l'arbre, son
    // context est désactivé et `ScaffoldMessenger.of` lèverait.
    final messenger = ScaffoldMessenger.of(context);
    final content = _textController.text.trim();
    if (content.isEmpty) return;

    final book = _selectedBook;
    if (book == null) {
      messenger.showSnackBar(
        SnackBar(content: Text(l.capturePassageNeedBook)),
      );
      return;
    }

    setState(() => _saving = true);

    try {
      final annotation = await _annotationService.createAnnotation(
        bookId: book.id.toString(),
        content: content,
        pageNumber: int.tryParse(_pageController.text.trim()),
        type: AnnotationType.photo,
      );

      // La photo est la preuve : si l'OCR s'est trompé, c'est le seul recours
      // de l'utilisateur. Un échec d'upload ne doit pas pour autant faire
      // perdre le texte, déjà enregistré ci-dessus.
      var photoKept = false;
      try {
        final storagePath = await _annotationService.uploadAnnotationImage(
          annotation.id,
          widget.imagePath,
        );
        await _annotationService.setAnnotationImagePath(
          annotation.id,
          storagePath,
        );
        photoKept = true;
      } catch (e) {
        debugPrint('Upload de la photo du passage échoué: $e');
      }

      unawaited(AnalyticsService().track(
        AnalyticsEvent.passageSaved,
        properties: {
          'source': widget.source,
          'text_length': content.length,
          'has_page': _pageController.text.trim().isNotEmpty,
          'photo_kept': photoKept,
        },
      ));

      if (!mounted) return;
      Navigator.pop(context, true);
      messenger.showSnackBar(
        SnackBar(content: Text(l.capturePassageSaved)),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(
        SnackBar(
          content: Text(l.errorGeneric(e.toString())),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  l.capturePassageTitle,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),

                // Le texte reste corrigeable : l'OCR se trompe, et découvrir
                // une coquille trois semaines plus tard sans pouvoir la
                // rectifier serait pire que de ne rien avoir gardé.
                TextField(
                  controller: _textController,
                  maxLines: 8,
                  minLines: 3,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.all(12),
                  ),
                ),
                const SizedBox(height: 16),

                // Chip livre + page sur la même ligne.
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(child: _buildBookChip(isDark, l)),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 84,
                      child: TextField(
                        controller: _pageController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: l.capturePassagePageLabel,
                          isDense: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _saving ? null : _save,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            l.capturePassageSave,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBookChip(bool isDark, AppLocalizations l) {
    final book = _selectedBook;

    return InkWell(
      onTap: _loadingBooks ? null : _changeBook,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.2)
                : Colors.black.withValues(alpha: 0.15),
          ),
        ),
        child: Row(
          children: [
            if (_loadingBooks)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else if (book != null)
              CachedBookCover(
                imageUrl: book.coverUrl,
                isbn: book.isbn,
                googleId: book.googleId,
                title: book.title,
                author: book.author,
                width: 24,
                height: 34,
                borderRadius: BorderRadius.circular(3),
              )
            else
              const Icon(Icons.menu_book_rounded, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                book?.title ?? l.capturePassageNoBook,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: book == null ? Colors.grey : null,
                ),
              ),
            ),
            const Icon(Icons.unfold_more_rounded, size: 16, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}

/// Id factice renvoyé par le sélecteur pour dire « ce livre n'est pas dans ma
/// bibliothèque, ouvre-moi le scan ».
const int _kScanSentinelId = -1;

class _PassageBookPicker extends StatefulWidget {
  final List<Book> books;

  const _PassageBookPicker({required this.books});

  @override
  State<_PassageBookPicker> createState() => _PassageBookPickerState();
}

class _PassageBookPickerState extends State<_PassageBookPicker> {
  String _query = '';

  List<Book> get _filtered {
    if (_query.isEmpty) return widget.books;
    final q = _query.toLowerCase();
    return widget.books
        .where((b) =>
            b.title.toLowerCase().contains(q) ||
            (b.author?.toLowerCase().contains(q) ?? false))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                l.capturePassageChooseBook,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            decoration: InputDecoration(
              hintText: l.searchEllipsis,
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onChanged: (v) => setState(() => _query = v),
          ),
          const SizedBox(height: 8),
          // Toujours une porte de sortie : le livre peut ne pas être en
          // bibliothèque, et rester coincé ici tuerait la capture.
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.add_a_photo_outlined),
            title: Text(l.capturePassageScanCover),
            onTap: () => Navigator.pop(
              context,
              Book(id: _kScanSentinelId, title: ''),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _filtered.isEmpty
                ? Center(child: Text(l.noBookFound))
                : ListView.builder(
                    itemCount: _filtered.length,
                    itemBuilder: (context, index) {
                      final book = _filtered[index];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CachedBookCover(
                          imageUrl: book.coverUrl,
                          isbn: book.isbn,
                          googleId: book.googleId,
                          title: book.title,
                          author: book.author,
                          width: 34,
                          height: 50,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        title: Text(
                          book.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: book.author != null
                            ? Text(
                                book.author!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              )
                            : null,
                        onTap: () => Navigator.pop(context, book),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
