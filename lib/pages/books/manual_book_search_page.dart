// lib/pages/books/manual_book_search_page.dart

import 'dart:async';

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../services/google_books_service.dart';
import '../../services/trending_books_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/author_result_card.dart';
import '../../widgets/cached_book_cover.dart';
import '../../widgets/constrained_content.dart';
import 'author_books_page.dart';

/// Page de recherche manuelle de livre (titre, auteur, ISBN).
/// Pop renvoie un [GoogleBook] sélectionné, ou null si annulée.
class ManualBookSearchPage extends StatefulWidget {
  const ManualBookSearchPage({super.key, this.initialQuery});

  final String? initialQuery;

  @override
  State<ManualBookSearchPage> createState() => _ManualBookSearchPageState();
}

class _ManualBookSearchPageState extends State<ManualBookSearchPage> {
  final GoogleBooksService _service = GoogleBooksService();
  final TrendingBooksService _trendingService = TrendingBooksService();
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  Timer? _debounce;
  int _searchSeq = 0;

  bool _isSearching = false;
  String? _errorMessage;
  String? _detectedAuthor;
  List<GoogleBook> _results = [];
  String _lastSubmittedQuery = '';

  List<TrendingBook> _trending = [];
  int? _resolvingTrendingIndex;

  @override
  void initState() {
    super.initState();
    _loadTrending();
    if (widget.initialQuery != null && widget.initialQuery!.isNotEmpty) {
      _controller.text = widget.initialQuery!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _runSearch(widget.initialQuery!, immediate: true);
      });
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _focusNode.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _loadTrending() async {
    final trending = await _trendingService.getTrendingBooks();
    if (!mounted || trending.isEmpty) return;
    setState(() => _trending = trending);
  }

  Future<void> _onTrendingTap(int index) async {
    if (_resolvingTrendingIndex != null) return;
    final book = _trending[index];

    // google_id connu : conversion directe, aucun appel réseau.
    if (book.googleId != null && book.googleId!.isNotEmpty) {
      Navigator.of(context).pop(book.toGoogleBook());
      return;
    }

    // Sinon : résolution via Google Books (ISBN puis titre+auteur).
    setState(() => _resolvingTrendingIndex = index);
    final resolved = await _trendingService.resolve(book);
    if (!mounted) return;
    setState(() => _resolvingTrendingIndex = null);
    if (resolved != null) {
      Navigator.of(context).pop(resolved);
    } else {
      // Dernier recours : pré-remplir la recherche classique.
      _controller.text = '${book.title} ${book.author}';
      _runSearch(_controller.text, immediate: true);
    }
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _results = [];
        _errorMessage = null;
        _detectedAuthor = null;
        _isSearching = false;
        _lastSubmittedQuery = '';
      });
      return;
    }
    if (trimmed.length < 3) {
      setState(() {
        _isSearching = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () {
      _runSearch(trimmed);
    });
  }

  bool _looksLikeIsbn(String query) {
    final clean = query.replaceAll(RegExp(r'[\s\-]'), '');
    if (clean.length == 13 &&
        (clean.startsWith('978') || clean.startsWith('979'))) {
      return true;
    }
    if (clean.length == 10 && RegExp(r'^\d{9}[\dXx]$').hasMatch(clean)) {
      return true;
    }
    return false;
  }

  Future<void> _runSearch(String rawQuery, {bool immediate = false}) async {
    final query = rawQuery.trim();
    if (query.isEmpty) return;

    final seq = ++_searchSeq;
    setState(() {
      _isSearching = true;
      _errorMessage = null;
      _lastSubmittedQuery = query;
    });

    try {
      List<GoogleBook> results;
      if (_looksLikeIsbn(query)) {
        final clean = query.replaceAll(RegExp(r'[\s\-]'), '');
        final book = await _service.searchByISBN(clean);
        results = book != null ? [book] : await _service.searchBooks(clean);
      } else {
        // Recherche optimisée : 2 requêtes en parallèle (FR + toutes
        // langues), fusion + tri par pertinence, cache — GoogleBooksService.
        results = await _service.searchBooksRanked(query);
        // Boost communautaire : les livres déjà lus par des membres LexDay
        // remontent en premier (best-effort, tri stable sinon).
        if (results.length > 1) {
          final popularity = await _trendingService.getPopularity(results);
          if (seq == _searchSeq) {
            results =
                TrendingBooksService.boostByPopularity(results, popularity);
          }
        }
      }

      if (!mounted || seq != _searchSeq) return;
      setState(() {
        _results = results;
        // La requête ressemble-t-elle à un nom d'auteur ?
        _detectedAuthor = _looksLikeIsbn(query)
            ? null
            : GoogleBooksService.detectAuthorQuery(query, results);
        _isSearching = false;
      });
    } catch (e) {
      if (!mounted || seq != _searchSeq) return;
      final l10n = AppLocalizations.of(context);
      setState(() {
        _isSearching = false;
        _errorMessage = l10n.errorGoogleBooks;
      });
    }
  }

  void _submit() {
    _debounce?.cancel();
    final value = _controller.text.trim();
    if (value.isNotEmpty) {
      _runSearch(value, immediate: true);
    }
  }

  void _clear() {
    _debounce?.cancel();
    _controller.clear();
    setState(() {
      _results = [];
      _errorMessage = null;
      _isSearching = false;
      _lastSubmittedQuery = '';
    });
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.manualSearchTitle),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: ConstrainedContent(
        child: Column(
          children: [
            _buildSearchField(l10n),
            if (_isSearching) const LinearProgressIndicator(minHeight: 2),
            Expanded(child: _buildBody(l10n)),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchField(AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.l,
        AppSpace.l,
        AppSpace.l,
        AppSpace.m,
      ),
      child: TextField(
        textCapitalization: TextCapitalization.sentences,
        controller: _controller,
        focusNode: _focusNode,
        onChanged: _onChanged,
        onSubmitted: (_) => _submit(),
        textInputAction: TextInputAction.search,
        autocorrect: false,
        style: const TextStyle(fontSize: 18),
        decoration: InputDecoration(
          hintText: l10n.manualSearchHint,
          prefixIcon: const Icon(Icons.search, size: 26),
          suffixIcon: _controller.text.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: l10n.manualSearchClear,
                  onPressed: _clear,
                ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpace.l,
            vertical: AppSpace.m,
          ),
          filled: true,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            borderSide: BorderSide(
              color: AppColors.primary.withValues(alpha: 0.5),
              width: 1.5,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(AppLocalizations l10n) {
    if (_errorMessage != null) {
      return _buildError(l10n, _errorMessage!);
    }
    if (_controller.text.trim().isEmpty) {
      return _buildEmptyHint(l10n);
    }
    if (_results.isEmpty && !_isSearching && _lastSubmittedQuery.isNotEmpty) {
      return _buildNoResults(l10n);
    }
    if (_results.isEmpty) {
      return _buildEmptyHint(l10n);
    }
    return _buildResults();
  }

  Widget _buildEmptyHint(AppLocalizations l10n) {
    if (_trending.isNotEmpty) {
      return _buildTrendingSection(l10n);
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.l,
        AppSpace.l,
        AppSpace.l,
        AppSpace.xl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(
            Icons.menu_book_rounded,
            size: 72,
            color: AppColors.primary.withValues(alpha: 0.35),
          ),
          const SizedBox(height: AppSpace.m),
          Text(
            l10n.manualSearchEmptyTitle,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: AppSpace.xs),
          Text(
            l10n.manualSearchEmptyHint,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.65),
                ),
          ),
          const SizedBox(height: AppSpace.l),
          _buildTipChip(
            icon: Icons.title_rounded,
            label: l10n.manualSearchTipTitle,
          ),
          const SizedBox(height: AppSpace.s),
          _buildTipChip(
            icon: Icons.person_outline_rounded,
            label: l10n.manualSearchTipAuthor,
          ),
          const SizedBox(height: AppSpace.s),
          _buildTipChip(
            icon: Icons.qr_code_2_rounded,
            label: l10n.manualSearchTipIsbn,
          ),
        ],
      ),
    );
  }

  Widget _buildTrendingSection(AppLocalizations l10n) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.l,
        AppSpace.s,
        AppSpace.l,
        AppSpace.xl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.manualSearchEmptyHint,
            style: theme.textTheme.bodySmall?.copyWith(
                  color: onSurface.withValues(alpha: 0.55),
                ),
          ),
          const SizedBox(height: AppSpace.l),
          Row(
            children: [
              const Icon(
                Icons.local_fire_department_rounded,
                size: 20,
                color: AppColors.primary,
              ),
              const SizedBox(width: AppSpace.xs),
              Text(
                l10n.manualSearchTrendingTitle,
                style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.m),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 130,
              mainAxisSpacing: AppSpace.m,
              crossAxisSpacing: AppSpace.m,
              childAspectRatio: 0.52,
            ),
            itemCount: _trending.length,
            itemBuilder: (context, index) => _TrendingBookTile(
              book: _trending[index],
              isResolving: _resolvingTrendingIndex == index,
              onTap: () => _onTrendingTap(index),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTipChip({required IconData icon, required String label}) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.m,
        vertical: AppSpace.s + 2,
      ),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.m),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: AppSpace.s),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoResults(AppLocalizations l10n) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.l,
        AppSpace.xl,
        AppSpace.l,
        AppSpace.xl,
      ),
      child: Column(
        children: [
          Icon(
            Icons.search_off_rounded,
            size: 64,
            color: Theme.of(context)
                .colorScheme
                .onSurface
                .withValues(alpha: 0.35),
          ),
          const SizedBox(height: AppSpace.m),
          Text(
            l10n.manualSearchNoResults,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: AppSpace.xs),
          Text(
            l10n.manualSearchNoResultsHint,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.6),
                ),
          ),
          // Sortie de secours : un livre auto-édité, un vieux tirage ou une
          // langue rare n'est pas au catalogue Google Books. Sans ce bouton,
          // l'écran est un cul-de-sac et le livre est intraçable dans l'app.
          if (_lastSubmittedQuery.isNotEmpty) ...[
            const SizedBox(height: AppSpace.l),
            FilledButton.icon(
              onPressed: () => _openManualAdd(_lastSubmittedQuery),
              icon: const Icon(Icons.edit_note_rounded),
              label: Text(
                l10n.addBookManuallyCta(_lastSubmittedQuery),
                textAlign: TextAlign.center,
              ),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpace.l,
                  vertical: AppSpace.m,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Ajout manuel — dernier recours hors catalogue Google Books.
  /// On renvoie un [GoogleBook] synthétique **sans id** : côté service,
  /// `addBookFromGoogleBooks` détecte l'id vide et route vers
  /// `addBookManually` (dédup titre+auteur, source = 'manual'). Aucun appelant
  /// n'a donc à changer de type.
  Future<void> _openManualAdd(String initialTitle) async {
    final created = await showModalBottomSheet<GoogleBook>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.l)),
      ),
      builder: (_) => _ManualAddBookSheet(initialTitle: initialTitle),
    );
    if (!mounted || created == null) return;
    Navigator.of(context).pop(created);
  }

  Widget _buildError(AppLocalizations l10n, String message) {
    return Padding(
      padding: const EdgeInsets.all(AppSpace.l),
      child: Card(
        color: Colors.orange.shade50,
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.m),
          child: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700),
              const SizedBox(width: AppSpace.s),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(color: Colors.orange.shade900),
                ),
              ),
              TextButton(
                onPressed: _submit,
                child: Text(l10n.manualSearchRetry),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Ouvre la page « tous les livres de cet auteur » en mode sélection :
  /// le livre choisi remonte à l'appelant de cette page.
  Future<void> _openAuthorBooks(String author) async {
    final picked = await Navigator.push<GoogleBook>(
      context,
      MaterialPageRoute(
        builder: (_) => AuthorBooksPage(
          author: author,
          selectionMode: true,
        ),
      ),
    );
    if (picked != null && mounted) {
      Navigator.of(context).pop(picked);
    }
  }

  Widget _buildResults() {
    final hasAuthorCard = _detectedAuthor != null;
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.l,
        AppSpace.s,
        AppSpace.l,
        AppSpace.xl,
      ),
      itemCount: _results.length + (hasAuthorCard ? 1 : 0),
      separatorBuilder: (_, __) => const SizedBox(height: AppSpace.s),
      itemBuilder: (context, index) {
        // Carte auteur en tête quand la requête est un nom d'auteur
        if (hasAuthorCard && index == 0) {
          return AuthorResultCard(
            authorName: _detectedAuthor!,
            padding: EdgeInsets.zero,
            onTap: () => _openAuthorBooks(_detectedAuthor!),
          );
        }
        final book = _results[hasAuthorCard ? index - 1 : index];
        return _BookResultCard(
          book: book,
          onTap: () => Navigator.of(context).pop(book),
        );
      },
    );
  }
}

class _BookResultCard extends StatelessWidget {
  const _BookResultCard({required this.book, required this.onTap});

  final GoogleBook book;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    return Material(
      color: theme.cardColor,
      borderRadius: BorderRadius.circular(AppRadius.m),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.m),
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.m),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CachedBookCover(
                imageUrl: book.coverUrl,
                isbn: book.isbn13,
                googleId: book.id,
                title: book.title,
                author: book.authorsString,
                width: 60,
                height: 90,
                borderRadius: BorderRadius.circular(AppRadius.s),
              ),
              const SizedBox(width: AppSpace.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      book.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      book.authorsString,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                            color: onSurface.withValues(alpha: 0.75),
                          ),
                    ),
                    const SizedBox(height: AppSpace.xs),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (book.publishedDate != null)
                          _MetaChip(
                            icon: Icons.event_outlined,
                            label: book.publishedDate!.length >= 4
                                ? book.publishedDate!.substring(0, 4)
                                : book.publishedDate!,
                          ),
                        if (book.pageCount != null)
                          _MetaChip(
                            icon: Icons.menu_book_outlined,
                            label: '${book.pageCount} p.',
                          ),
                        if (book.isbn13 != null && book.isbn13!.isNotEmpty)
                          _MetaChip(
                            icon: Icons.qr_code_2_rounded,
                            label: book.isbn13!,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpace.s),
              Icon(
                Icons.chevron_right_rounded,
                color: onSurface.withValues(alpha: 0.4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrendingBookTile extends StatelessWidget {
  const _TrendingBookTile({
    required this.book,
    required this.isResolving,
    required this.onTap,
  });

  final TrendingBook book;
  final bool isResolving;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.m),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: CachedBookCover(
                    imageUrl: book.coverUrl,
                    isbn: book.isbn,
                    googleId: book.googleId,
                    title: book.title,
                    author: book.author,
                    width: 120,
                    height: 180,
                    borderRadius: BorderRadius.circular(AppRadius.s),
                  ),
                ),
                if (isResolving)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(AppRadius.s),
                      ),
                      child: const Center(
                        child: SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                if (book.isCommunity && book.readersCount > 0)
                  Positioned(
                    top: 4,
                    left: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.people_alt_rounded,
                            size: 11,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            '${book.readersCount}',
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.xs),
          Text(
            book.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  height: 1.15,
                ),
          ),
          const SizedBox(height: 1),
          Text(
            book.author,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 11,
                  color: onSurface.withValues(alpha: 0.6),
                ),
          ),
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: onSurface.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppRadius.s),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: onSurface.withValues(alpha: 0.65)),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: onSurface.withValues(alpha: 0.75),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// Saisie manuelle d'un livre absent de Google Books.
/// Ne fait aucun appel réseau : elle se contente de construire le
/// [GoogleBook] synthétique que le service transformera en ajout manuel.
class _ManualAddBookSheet extends StatefulWidget {
  const _ManualAddBookSheet({required this.initialTitle});

  final String initialTitle;

  @override
  State<_ManualAddBookSheet> createState() => _ManualAddBookSheetState();
}

class _ManualAddBookSheetState extends State<_ManualAddBookSheet> {
  late final TextEditingController _titleController =
      TextEditingController(text: widget.initialTitle);
  final TextEditingController _authorController = TextEditingController();
  final TextEditingController _pagesController = TextEditingController();

  String? _error;

  @override
  void dispose() {
    _titleController.dispose();
    _authorController.dispose();
    _pagesController.dispose();
    super.dispose();
  }

  void _submit() {
    final title = _titleController.text.trim();
    final author = _authorController.text.trim();
    if (title.isEmpty || author.isEmpty) {
      setState(() => _error = AppLocalizations.of(context).titleAuthorRequired);
      return;
    }
    // Le nombre de pages reste facultatif : l'exiger ici recréerait la
    // friction qu'on cherche justement à retirer du parcours.
    final pages = int.tryParse(_pagesController.text.trim());
    Navigator.of(context).pop(
      GoogleBook(
        id: '',
        title: title,
        authors: [author],
        isbns: const [],
        pageCount: pages,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpace.l,
        AppSpace.l,
        AppSpace.l,
        MediaQuery.of(context).viewInsets.bottom + AppSpace.l,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.addBookTitle,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpace.m),
          TextField(
            controller: _titleController,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: l10n.titleHint,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: AppSpace.s),
          TextField(
            controller: _authorController,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: l10n.authorHint,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: AppSpace.s),
          TextField(
            controller: _pagesController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: l10n.totalPages,
              border: const OutlineInputBorder(),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpace.s),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: AppSpace.m),
          FilledButton(
            onPressed: _submit,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: AppSpace.m),
            ),
            child: Text(l10n.addButton),
          ),
        ],
      ),
    );
  }
}
