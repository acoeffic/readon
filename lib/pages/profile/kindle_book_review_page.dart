import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../services/kindle_webview_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/cached_book_cover.dart';
import '../../widgets/constrained_content.dart';

/// Page de validation manuelle des livres détectés sur Kindle avant import.
///
/// L'utilisateur voit la liste des nouveaux livres trouvés (ceux pas encore
/// dans sa bibliothèque LexDay) et peut décocher ceux qu'il ne veut pas.
/// Tous les livres sont cochés par défaut.
///
/// Renvoie via [Navigator.pop] :
/// - `Set<String>` des titres de livres acceptés (peut être vide si l'user a
///   tout décoché et validé quand même)
/// - `null` si l'user a quitté sans valider (cancel)
class KindleBookReviewPage extends StatefulWidget {
  final List<KindleBookProgress> newBooks;
  final bool isFirstSync;

  const KindleBookReviewPage({
    super.key,
    required this.newBooks,
    required this.isFirstSync,
  });

  @override
  State<KindleBookReviewPage> createState() => _KindleBookReviewPageState();
}

class _KindleBookReviewPageState extends State<KindleBookReviewPage> {
  late final Set<String> _selectedTitles;

  @override
  void initState() {
    super.initState();
    _selectedTitles = widget.newBooks.map((b) => b.title).toSet();
  }

  void _toggle(String title) {
    setState(() {
      if (_selectedTitles.contains(title)) {
        _selectedTitles.remove(title);
      } else {
        _selectedTitles.add(title);
      }
    });
  }

  void _toggleAll() {
    setState(() {
      if (_selectedTitles.length == widget.newBooks.length) {
        _selectedTitles.clear();
      } else {
        _selectedTitles
          ..clear()
          ..addAll(widget.newBooks.map((b) => b.title));
      }
    });
  }

  /// Détermine le statut affiché pour chaque livre selon la même logique
  /// que [BooksService.importKindleBooks].
  String _statusFor(int index, KindleBookProgress book) {
    if (widget.isFirstSync) {
      return index < 2 ? 'reading' : 'finished';
    }
    if (book.percentComplete == 100) return 'finished';
    if (book.percentComplete != null && book.percentComplete! > 0) {
      return 'reading';
    }
    return 'to_read';
  }

  String _statusLabel(AppLocalizations l10n, String status) {
    switch (status) {
      case 'reading':
        return l10n.kindleReviewStatusReading;
      case 'finished':
        return l10n.kindleReviewStatusFinished;
      default:
        return l10n.kindleReviewStatusToRead;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'reading':
        return AppColors.primary;
      case 'finished':
        return AppColors.sageGreen;
      default:
        return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final allSelected = _selectedTitles.length == widget.newBooks.length;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.kindleReviewTitle),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ConstrainedContent(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.l,
                AppSpace.m,
                AppSpace.l,
                AppSpace.s,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.kindleReviewSubtitle,
                    style: TextStyle(
                      fontSize: 14,
                      color: context.appColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: AppSpace.m),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        l10n.kindleReviewSelectedCount(
                          _selectedTitles.length,
                          widget.newBooks.length,
                        ),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: context.appColors.textPrimary,
                        ),
                      ),
                      TextButton(
                        onPressed: _toggleAll,
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpace.s,
                            vertical: AppSpace.xs,
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          allSelected
                              ? l10n.kindleReviewDeselectAll
                              : l10n.kindleReviewSelectAll,
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(
                  AppSpace.l,
                  AppSpace.s,
                  AppSpace.l,
                  AppSpace.l,
                ),
                itemCount: widget.newBooks.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(height: AppSpace.s),
                itemBuilder: (context, index) {
                  final book = widget.newBooks[index];
                  final selected = _selectedTitles.contains(book.title);
                  final status = _statusFor(index, book);
                  return _BookRow(
                    book: book,
                    selected: selected,
                    statusLabel: _statusLabel(l10n, status),
                    statusColor: _statusColor(status),
                    onTap: () => _toggle(book.title),
                  );
                },
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpace.l,
                  AppSpace.s,
                  AppSpace.l,
                  AppSpace.m,
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor:
                          AppColors.primary.withValues(alpha: 0.3),
                      padding:
                          const EdgeInsets.symmetric(vertical: AppSpace.m + 2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      textStyle: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onPressed: _selectedTitles.isEmpty
                        ? null
                        : () => Navigator.pop(context, _selectedTitles),
                    child: Text(
                      l10n.kindleReviewImportButton(_selectedTitles.length),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BookRow extends StatelessWidget {
  final KindleBookProgress book;
  final bool selected;
  final String statusLabel;
  final Color statusColor;
  final VoidCallback onTap;

  const _BookRow({
    required this.book,
    required this.selected,
    required this.statusLabel,
    required this.statusColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.appColors.cardBg,
      borderRadius: BorderRadius.circular(AppRadius.m),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.m),
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.s + 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Checkbox(
                value: selected,
                onChanged: (_) => onTap(),
                activeColor: AppColors.primary,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ),
              const SizedBox(width: AppSpace.xs),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.s),
                child: CachedBookCover(
                  imageUrl: book.coverUrl,
                  title: book.title,
                  author: book.author,
                  width: 44,
                  height: 64,
                ),
              ),
              const SizedBox(width: AppSpace.m),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      book.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: context.appColors.textPrimary,
                      ),
                    ),
                    if (book.author != null && book.author!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        book.author!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: context.appColors.textSecondary,
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpace.s,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(AppRadius.pill),
                      ),
                      child: Text(
                        statusLabel,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: statusColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
