import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../../l10n/app_localizations.dart';
import '../../models/feature_flags.dart';
import '../../models/user_custom_list.dart';
import '../../providers/subscription_provider.dart';
import '../../services/user_custom_lists_service.dart';
import '../../widgets/premium_gate.dart';
import 'create_custom_list_dialog.dart';

/// Bottom sheet « Ajouter à une liste » pour un livre déjà en base.
/// Les listes sont cochables ; « Créer une nouvelle liste » crée la liste
/// (avec la limite gratuite) et y ajoute directement le livre.
Future<void> showAddToListSheet(
  BuildContext context, {
  required int bookId,
}) async {
  final service = UserCustomListsService();
  final results = await Future.wait([
    service.getUserLists(),
    service.getListIdsContainingBook(bookId),
  ]);
  if (!context.mounted) return;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => AddToListSheet(
      lists: results[0] as List<UserCustomList>,
      containingIds: results[1] as Set<int>,
      bookId: bookId,
      service: service,
    ),
  );
}

class AddToListSheet extends StatefulWidget {
  final List<UserCustomList> lists;
  final Set<int> containingIds;
  final int bookId;
  final UserCustomListsService service;

  const AddToListSheet({
    super.key,
    required this.lists,
    required this.containingIds,
    required this.bookId,
    required this.service,
  });

  @override
  State<AddToListSheet> createState() => _AddToListSheetState();
}

class _AddToListSheetState extends State<AddToListSheet> {
  late List<UserCustomList> _lists;
  late Set<int> _containingIds;

  static const _accent = Color(0xFFFF6B35);

  @override
  void initState() {
    super.initState();
    _lists = List<UserCustomList>.from(widget.lists);
    _containingIds = Set<int>.from(widget.containingIds);
  }

  void _showError(Object e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context).errorGeneric(e.toString())),
        backgroundColor: Colors.red,
      ),
    );
  }

  Future<void> _toggleList(UserCustomList list) async {
    final wasInList = _containingIds.contains(list.id);
    setState(() {
      if (wasInList) {
        _containingIds.remove(list.id);
      } else {
        _containingIds.add(list.id);
      }
    });

    try {
      if (wasInList) {
        await widget.service.removeBookFromList(list.id, widget.bookId);
      } else {
        await widget.service.addBookToList(list.id, widget.bookId);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        if (wasInList) {
          _containingIds.add(list.id);
        } else {
          _containingIds.remove(list.id);
        }
      });
      _showError(e);
    }
  }

  Future<void> _createNewList() async {
    final isPremium = context.read<SubscriptionProvider>().isPremium;
    if (!isPremium && _lists.length >= FeatureFlags.maxFreeCustomLists) {
      showPremiumUpsellSheet(
        context,
        feature: Feature.customLists,
        customMessage: AppLocalizations.of(context)
            .listLimitMessage(FeatureFlags.maxFreeCustomLists),
      );
      return;
    }

    // Le sheet reste ouvert : la nouvelle liste apparaît cochée juste après.
    final result = await showCreateCustomListSheet(context);
    if (result == null || !mounted) return;

    setState(() => _lists.insert(0, result));
    try {
      await widget.service.addBookToList(result.id, widget.bookId);
      if (!mounted) return;
      setState(() => _containingIds.add(result.id));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(AppLocalizations.of(context).addedToListNamed(result.title)),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      debugPrint('Erreur ajout à nouvelle liste: $e');
      _showError(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: onSurface.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                l10n.addToList,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            // « Nouvelle liste » en tête : toujours visible, même avec beaucoup de listes
            ListTile(
              leading: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: _accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(LucideIcons.plus, size: 18, color: _accent),
              ),
              title: Text(
                l10n.createNewList,
                style: const TextStyle(color: _accent),
              ),
              onTap: _createNewList,
            ),
            if (_lists.isEmpty)
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Text(
                  l10n.noPersonalList,
                  style: TextStyle(color: onSurface.withValues(alpha: 0.5)),
                ),
              )
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _lists.length,
                  itemBuilder: (context, index) {
                    final list = _lists[index];
                    final isInList = _containingIds.contains(list.id);
                    return ListTile(
                      leading: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          gradient:
                              LinearGradient(colors: list.gradientColors),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(list.icon, size: 18, color: Colors.white),
                      ),
                      title: Text(list.title),
                      trailing: Icon(
                        isInList
                            ? Icons.check_circle
                            : Icons.circle_outlined,
                        color: isInList ? _accent : null,
                      ),
                      onTap: () => _toggleList(list),
                    );
                  },
                ),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
