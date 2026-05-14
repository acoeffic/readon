import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../l10n/app_localizations.dart';
import '../../models/reading_group.dart';
import '../../services/groups_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/constrained_content.dart';
import 'group_list_detail_page.dart';

const _kCard = Color(0xFFF0E8D8);
const _kSageGreen = Color(0xFF6B988D);

/// Page listant toutes les bibliothèques (listes de lecture) d'un club.
class GroupLibraryPage extends StatefulWidget {
  final String groupId;
  final String groupName;

  /// `true` si l'utilisateur est admin du club. Permet de supprimer
  /// n'importe quelle liste, même celle qu'il n'a pas créée.
  final bool isAdmin;

  /// Membre du club ? Sinon on désactive la création.
  final bool isMember;

  const GroupLibraryPage({
    super.key,
    required this.groupId,
    required this.groupName,
    required this.isAdmin,
    required this.isMember,
  });

  @override
  State<GroupLibraryPage> createState() => _GroupLibraryPageState();
}

class _GroupLibraryPageState extends State<GroupLibraryPage> {
  final GroupsService _service = GroupsService();
  bool _loading = true;
  List<GroupReadingList> _lists = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final lists = await _service.getGroupReadingLists(widget.groupId);
      if (!mounted) return;
      setState(() {
        _lists = lists;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
    }
  }

  Future<void> _onCreateList() async {
    final created = await showDialog<GroupReadingList?>(
      context: context,
      builder: (_) => _CreateListDialog(groupId: widget.groupId),
    );
    if (created != null && mounted) {
      _load();
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => GroupListDetailPage(
            groupId: widget.groupId,
            list: created,
            isAdmin: widget.isAdmin,
            isMember: widget.isMember,
          ),
        ),
      ).then((_) => _load());
    }
  }

  Future<void> _onDeleteList(GroupReadingList list) async {
    final l = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.groupLibraryDeleteList),
        content: Text(l.groupLibraryDeleteListConfirm(list.title)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(l.deleteButton),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _service.deleteGroupReadingList(list.id);
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? Theme.of(context).scaffoldBackgroundColor : AppColors.bgLight;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l.groupLibrary,
              style: GoogleFonts.cormorantGaramond(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            Text(
              widget.groupName,
              style: GoogleFonts.dmSans(
                fontSize: 12,
                color: (isDark ? Colors.white : Colors.black)
                    .withValues(alpha: 0.6),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        leading: const BackButton(),
      ),
      floatingActionButton: widget.isMember
          ? FloatingActionButton.extended(
              onPressed: _onCreateList,
              backgroundColor: _kSageGreen,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: Text(l.groupLibraryNewList),
            )
          : null,
      body: ConstrainedContent(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _lists.isEmpty
                ? _EmptyState(canCreate: widget.isMember, onCreate: _onCreateList)
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                      itemCount: _lists.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (_, i) {
                        final list = _lists[i];
                        final canDelete = widget.isAdmin; // simplification
                        return _ListCard(
                          list: list,
                          isDark: isDark,
                          canDelete: canDelete,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => GroupListDetailPage(
                                  groupId: widget.groupId,
                                  list: list,
                                  isAdmin: widget.isAdmin,
                                  isMember: widget.isMember,
                                ),
                              ),
                            ).then((_) => _load());
                          },
                          onDelete: canDelete ? () => _onDeleteList(list) : null,
                        );
                      },
                    ),
                  ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Sub-widgets
// ─────────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final bool canCreate;
  final VoidCallback onCreate;

  const _EmptyState({required this.canCreate, required this.onCreate});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.library_books_outlined,
                size: 64, color: Colors.black.withValues(alpha: 0.2)),
            const SizedBox(height: 16),
            Text(
              l.groupLibraryEmpty,
              textAlign: TextAlign.center,
              style: GoogleFonts.cormorantGaramond(
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l.groupLibraryEmptyHint,
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(
                fontSize: 14,
                color: Colors.black.withValues(alpha: 0.6),
              ),
            ),
            if (canCreate) ...[
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: onCreate,
                icon: const Icon(Icons.add),
                label: Text(l.groupLibraryNewList),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kSageGreen,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ListCard extends StatelessWidget {
  final GroupReadingList list;
  final bool isDark;
  final bool canDelete;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  const _ListCard({
    required this.list,
    required this.isDark,
    required this.canDelete,
    required this.onTap,
    this.onDelete,
  });

  Color _parseGradient() {
    try {
      final hex = list.gradientColor.replaceAll('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      return _kSageGreen;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final accent = _parseGradient();
    return Material(
      color: isDark ? AppColors.surfaceDark : _kCard,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Cover stack or icon
              SizedBox(
                width: 64,
                height: 64,
                child: list.coverUrls.isEmpty
                    ? _IconBadge(color: accent)
                    : _CoverStack(urls: list.coverUrls),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      list.title,
                      style: GoogleFonts.cormorantGaramond(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l.groupLibraryBookCount(list.bookCount),
                      style: GoogleFonts.dmSans(
                        fontSize: 13,
                        color: (isDark ? Colors.white : Colors.black)
                            .withValues(alpha: 0.6),
                      ),
                    ),
                    if (list.creatorName != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        l.groupLibraryCreatedBy(list.creatorName!),
                        style: GoogleFonts.dmSans(
                          fontSize: 11,
                          color: (isDark ? Colors.white : Colors.black)
                              .withValues(alpha: 0.4),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              if (canDelete && onDelete != null)
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20),
                  color: (isDark ? Colors.white : Colors.black)
                      .withValues(alpha: 0.5),
                  onPressed: onDelete,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IconBadge extends StatelessWidget {
  final Color color;
  const _IconBadge({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(Icons.menu_book_outlined, color: color, size: 28),
    );
  }
}

class _CoverStack extends StatelessWidget {
  final List<String> urls;
  const _CoverStack({required this.urls});

  @override
  Widget build(BuildContext context) {
    final visible = urls.take(3).toList();
    return Stack(
      children: List.generate(visible.length, (i) {
        return Positioned(
          left: i * 12.0,
          top: 0,
          bottom: 0,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Image.network(
              visible[i],
              width: 40,
              height: 64,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: 40,
                height: 64,
                color: Colors.grey.shade300,
              ),
            ),
          ),
        );
      }),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Create-list dialog
// ─────────────────────────────────────────────────────────────────────

class _CreateListDialog extends StatefulWidget {
  final String groupId;
  const _CreateListDialog({required this.groupId});

  @override
  State<_CreateListDialog> createState() => _CreateListDialogState();
}

class _CreateListDialogState extends State<_CreateListDialog> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) return;
    setState(() => _saving = true);
    try {
      final created = await GroupsService().createGroupReadingList(
        groupId: widget.groupId,
        title: title,
        description: _descCtrl.text.trim().isEmpty
            ? null
            : _descCtrl.text.trim(),
      );
      if (!mounted) return;
      Navigator.pop(context, created);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l.groupLibraryNewList),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _titleCtrl,
            autofocus: true,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: l.groupLibraryListTitle,
              hintText: l.groupLibraryListTitlePlaceholder,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descCtrl,
            textInputAction: TextInputAction.done,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: l.groupLibraryListDescription,
              hintText: l.groupLibraryListDescriptionPlaceholder,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, null),
          child: Text(l.cancel),
        ),
        FilledButton(
          onPressed: _saving ? null : _submit,
          style: FilledButton.styleFrom(backgroundColor: _kSageGreen),
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(l.groupLibraryCreateList),
        ),
      ],
    );
  }
}
