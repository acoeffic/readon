// lib/pages/reading/my_passages_tab.dart
//
// Les passages gardés, groupés par livre.
//
// Le mur plat d'origine s'écroulait dès que le volume montait : avec les
// surlignages Kindle importés par centaines, les captures photo se noyaient
// dans le flux. L'onglet montre donc la BIBLIOTHÈQUE des livres annotés
// (grille de couvertures, badge du nombre de passages), et un tap sur un
// livre ouvre la page de tous ses passages.
//
// Le chargement est en deux niveaux, sans plafond caché :
// - la grille ne charge qu'un AGRÉGAT par livre (RPC
//   get_annotation_book_groups : compte + date du dernier passage) — l'ancien
//   chargement de toutes les annotations (limit 500) faisait silencieusement
//   disparaître les passages anciens dès que la limite était dépassée ;
// - la page d'un livre charge ses passages à la demande
//   (getAnnotationsForBook).

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/app_localizations.dart';
import '../../models/annotation_model.dart';
import '../../services/analytics_service.dart';
import '../../services/annotation_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/cached_book_cover.dart';
import '../../widgets/constrained_content.dart';
import 'capture_passage_flow.dart';

class MyPassagesTab extends StatefulWidget {
  const MyPassagesTab({super.key});

  @override
  State<MyPassagesTab> createState() => _MyPassagesTabState();
}

class _MyPassagesTabState extends State<MyPassagesTab>
    with AutomaticKeepAliveClientMixin {
  final _service = AnnotationService();

  List<AnnotationBookGroup> _groups = const [];
  bool _loading = true;
  String _query = '';

  /// Livres dont AU MOINS un passage contient la recherche (résultat de la
  /// RPC, côté serveur). `null` = pas de recherche de contenu en cours ; la
  /// recherche titre/auteur, elle, est locale et instantanée.
  Set<String>? _contentMatchIds;
  Timer? _searchDebounce;
  int _searchSeq = 0;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
    // L'import Kindle atterrit en arrière-plan, souvent APRÈS la première
    // construction de cet onglet (keep-alive) : sans ce listener, les
    // surlignages fraîchement importés restaient invisibles jusqu'à un
    // pull-to-refresh ou un redémarrage.
    AnnotationService.version.addListener(_onAnnotationsChanged);
    unawaited(AnalyticsService().track(AnalyticsEvent.passagesWallOpened));
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    AnnotationService.version.removeListener(_onAnnotationsChanged);
    super.dispose();
  }

  void _onAnnotationsChanged() {
    if (mounted) _load();
  }

  Future<void> _load() async {
    final groups = await _service.getAnnotationBookGroups();
    if (!mounted) return;
    setState(() {
      _groups = groups;
      _loading = false;
    });
  }

  /// La saisie filtre immédiatement par titre/auteur (local), et déclenche —
  /// débouncée — la recherche de contenu côté serveur, dont le résultat vient
  /// élargir la sélection. On cherche autant « ce livre » que « cette phrase
  /// dont je me souviens ».
  void _onQueryChanged(String value) {
    setState(() => _query = value);
    _searchDebounce?.cancel();

    final q = value.trim();
    if (q.isEmpty) {
      setState(() => _contentMatchIds = null);
      return;
    }

    _searchDebounce = Timer(const Duration(milliseconds: 350), () async {
      final seq = ++_searchSeq;
      final matches = await _service.getAnnotationBookGroups(query: q);
      // Réponse obsolète (l'utilisateur a continué à taper) : on la jette.
      if (!mounted || seq != _searchSeq) return;
      setState(() {
        _contentMatchIds = matches.map((g) => g.bookId).toSet();
      });
    });
  }

  List<AnnotationBookGroup> get _filteredGroups {
    if (_query.trim().isEmpty) return _groups;
    final q = _query.toLowerCase();
    return _groups.where((g) {
      if ((g.bookTitle ?? '').toLowerCase().contains(q)) return true;
      if ((g.bookAuthor ?? '').toLowerCase().contains(q)) return true;
      return _contentMatchIds?.contains(g.bookId) ?? false;
    }).toList();
  }

  Future<void> _capture() async {
    final saved = await capturePassage(context, source: 'passages_wall');
    if (saved && mounted) {
      setState(() => _loading = true);
      await _load();
    }
  }

  Future<void> _openBook(AnnotationBookGroup group) async {
    unawaited(AnalyticsService().track(
      AnalyticsEvent.passagesBookOpened,
      properties: {'passage_count': group.passageCount},
    ));
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BookPassagesPage(
          bookId: group.bookId,
          book: group.book,
          passageCount: group.passageCount,
        ),
      ),
    );
    // Des passages ont pu être supprimés dans la page : on recharge au retour.
    if (mounted) await _load();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final l = AppLocalizations.of(context);

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_groups.isEmpty) {
      return _buildEmptyState(l);
    }

    final groups = _filteredGroups;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: l.myPassagesSearchHint,
                    prefixIcon: const Icon(Icons.search, size: 20),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onChanged: _onQueryChanged,
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: _capture,
                style: IconButton.styleFrom(backgroundColor: AppColors.primary),
                icon: const Icon(Icons.add_a_photo_outlined, size: 20),
                tooltip: l.capturePassageFab,
              ),
            ],
          ),
        ),
        Expanded(
          child: groups.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      l.myPassagesNoResult,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade500),
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: GridView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 14,
                      mainAxisSpacing: 16,
                      // Couverture 2:3 + deux lignes de titre dessous.
                      childAspectRatio: 0.52,
                    ),
                    itemCount: groups.length,
                    itemBuilder: (context, i) =>
                        _buildBookCell(groups[i], l),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildBookCell(AnnotationBookGroup group, AppLocalizations l) {
    final title = group.bookTitle ?? l.myPassagesUnknownBook;

    return GestureDetector(
      onTap: () => _openBook(group),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) => Stack(
                clipBehavior: Clip.none,
                children: [
                  CachedBookCover(
                    imageUrl: group.bookCoverUrl,
                    isbn: group.bookIsbn,
                    googleId: group.bookGoogleId,
                    title: title,
                    author: group.bookAuthor,
                    width: constraints.maxWidth,
                    height: constraints.maxHeight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  // Badge du nombre de passages : l'information qui justifie
                  // la présence du livre dans cette grille.
                  Positioned(
                    top: -6,
                    right: -6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: Theme.of(context).scaffoldBackgroundColor,
                          width: 2,
                        ),
                      ),
                      child: Text(
                        '${group.passageCount}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(AppLocalizations l) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.format_quote_rounded,
              size: 56,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 12),
            Text(
              l.myPassagesEmptyTitle,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              l.myPassagesEmptyBody,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
            ),
            const SizedBox(height: 20),
            // Un état vide sans porte de sortie est une impasse : ici le CTA
            // lance directement la capture.
            FilledButton.icon(
              onPressed: _capture,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
              ),
              icon: const Icon(Icons.add_a_photo_outlined, size: 18),
              label: Text(l.capturePassageFab),
            ),
          ],
        ),
      ),
    );
  }
}

/// Tous les passages d'un livre, chargés À LA DEMANDE (getAnnotationsForBook) :
/// la grille ne transporte plus les contenus, seulement l'agrégat. C'est ici
/// que vivent la suppression (swipe) et la feuille de détail.
class BookPassagesPage extends StatefulWidget {
  final String bookId;
  final Map<String, dynamic>? book;

  /// Compte affiché en attendant le chargement (celui du badge de la grille).
  final int passageCount;

  const BookPassagesPage({
    super.key,
    required this.bookId,
    required this.book,
    required this.passageCount,
  });

  @override
  State<BookPassagesPage> createState() => _BookPassagesPageState();
}

class _BookPassagesPageState extends State<BookPassagesPage> {
  final _service = AnnotationService();

  /// `null` tant que le chargement n'a pas abouti.
  List<AnnotationWithBook>? _items;

  String? get _title => widget.book?['title'] as String?;
  String? get _author => widget.book?['author'] as String?;

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    final annotations = await _service.getAnnotationsForBook(widget.bookId);
    if (!mounted) return;
    setState(() {
      _items = [
        for (final a in annotations)
          AnnotationWithBook(annotation: a, book: widget.book),
      ];
    });
  }

  Future<void> _delete(AnnotationWithBook item) async {
    final items = _items;
    if (items == null) return;
    final index = items.indexOf(item);
    setState(() => _items = List.of(items)..remove(item));
    try {
      await _service.deleteAnnotation(item.annotation.id);
    } catch (e) {
      if (!mounted) return;
      setState(() => _items = List.of(_items!)..insert(index, item));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context).errorGeneric(e.toString())),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    // Dernier passage supprimé : la page n'a plus de raison d'être, le livre
    // disparaîtra de la grille au retour.
    if (mounted && (_items?.isEmpty ?? false)) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final items = _items;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _title ?? l.myPassagesUnknownBook,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: ConstrainedContent(
        child: Column(
          children: [
            // En-tête : auteur + compte, le contexte qui manquait au mur plat.
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _author != null
                          ? '$_author · ${l.myPassagesCount(items?.length ?? widget.passageCount)}'
                          : l.myPassagesCount(
                              items?.length ?? widget.passageCount),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: items == null
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      onRefresh: _loadItems,
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        itemCount: items.length,
                        itemBuilder: (context, i) => _buildCard(items[i], l),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(AnnotationWithBook item, AppLocalizations l) {
    final a = item.annotation;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dismissible(
      key: Key(a.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.red.shade100,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(Icons.delete, color: Colors.red.shade400),
      ),
      confirmDismiss: (_) async {
        return await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: Text(l.myPassagesDeleteTitle),
                content: Text(l.myPassagesDeleteBody),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: Text(l.cancel),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: Text(
                      l.myPassagesDeleteConfirm,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                ],
              ),
            ) ??
            false;
      },
      onDismissed: (_) => _delete(item),
      child: GestureDetector(
        onTap: () => _openDetail(item, l),
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                a.content,
                maxLines: 5,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14.5,
                  height: 1.45,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  if (a.pageNumber != null)
                    Text(
                      l.myPassagesPage(a.pageNumber!),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  const Spacer(),
                  // Badge de provenance : un surlignage Kindle n'a pas de
                  // photo source, le distinguer évite de chercher une image
                  // qui n'existe pas.
                  if (a.type == AnnotationType.kindle)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.auto_stories_outlined,
                          size: 14,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          l.myPassagesSourceKindle,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    )
                  else if (a.imagePath != null)
                    Icon(
                      Icons.photo_outlined,
                      size: 14,
                      color: Colors.grey.shade400,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openDetail(AnnotationWithBook item, AppLocalizations l) {
    final a = item.annotation;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.35,
        maxChildSize: 0.95,
        expand: false,
        builder: (_, controller) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: ListView(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
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
              SelectableText(
                a.content,
                style: const TextStyle(fontSize: 16, height: 1.55),
              ),
              const SizedBox(height: 16),
              if (item.bookTitle != null)
                Text(
                  a.pageNumber != null
                      ? '${item.bookTitle} · ${l.myPassagesPage(a.pageNumber!)}'
                      : item.bookTitle!,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
              // La note personnelle attachée au surlignage (import Kindle).
              if (a.note != null && a.note!.trim().isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.myPassagesNoteLabel,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      SelectableText(
                        a.note!,
                        style: const TextStyle(fontSize: 14, height: 1.5),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              // La photo source : le recours quand l'OCR s'est trompé.
              if (a.imagePath != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    _service.getImageUrl(a.imagePath!),
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: a.content));
                  Navigator.pop(sheetContext);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(l.myPassagesCopied)),
                  );
                },
                icon: const Icon(Icons.copy_rounded, size: 18),
                label: Text(l.myPassagesCopy),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
