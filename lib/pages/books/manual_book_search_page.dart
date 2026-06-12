// lib/pages/books/manual_book_search_page.dart

import 'dart:async';

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../services/google_books_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/cached_book_cover.dart';
import '../../widgets/constrained_content.dart';

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
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  Timer? _debounce;
  int _searchSeq = 0;

  bool _isSearching = false;
  String? _errorMessage;
  List<GoogleBook> _results = [];
  String _lastSubmittedQuery = '';

  @override
  void initState() {
    super.initState();
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

  void _onChanged(String value) {
    _debounce?.cancel();
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _results = [];
        _errorMessage = null;
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
        results = await _service.searchBooks(query, langRestrict: true);
        if (results.isEmpty) {
          results = await _service.searchBooks(query);
        }
      }

      if (!mounted || seq != _searchSeq) return;
      setState(() {
        _results = results;
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
        ],
      ),
    );
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

  Widget _buildResults() {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.l,
        AppSpace.s,
        AppSpace.l,
        AppSpace.xl,
      ),
      itemCount: _results.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpace.s),
      itemBuilder: (context, index) => _BookResultCard(
        book: _results[index],
        onTap: () => Navigator.of(context).pop(_results[index]),
      ),
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
