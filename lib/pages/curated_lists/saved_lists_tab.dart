import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../../data/curated_lists_data.dart';
import '../../models/curated_list.dart';
import '../../models/feature_flags.dart';
import '../../models/user_custom_list.dart';
import '../../pages/feed/widgets/curated_lists_carousel.dart';
import '../../pages/profile/upgrade_page.dart';
import '../../providers/subscription_provider.dart';
import '../../services/curated_lists_service.dart';
import '../../services/user_custom_lists_service.dart';
import '../../theme/app_theme.dart';
import 'all_curated_lists_page.dart';
import 'create_custom_list_dialog.dart';
import 'curated_list_detail_page.dart';
import 'custom_list_detail_page.dart';

class SavedListsTab extends StatefulWidget {
  const SavedListsTab({super.key});

  @override
  State<SavedListsTab> createState() => SavedListsTabState();
}

class SavedListsTabState extends State<SavedListsTab> {
  final _curatedService = CuratedListsService();
  final _customService = UserCustomListsService();

  bool _isLoading = true;
  Set<int> _savedListIds = {};
  Map<int, int> _readCounts = {};
  Map<int, int> _readerCounts = {};
  List<UserCustomList> _customLists = [];
  Map<int, int> _customBookCounts = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  /// Recharge les données (appelable depuis l'extérieur via GlobalKey)
  Future<void> refresh() => _loadData();

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        _curatedService.getSavedListIds(),
        _customService.getUserLists(),
      ]);

      final savedIds = results[0] as Set<int>;
      final customLists = results[1] as List<UserCustomList>;

      // Charger les compteurs en parallèle
      final countResults = await Future.wait([
        savedIds.isNotEmpty
            ? _curatedService.getReadCountsPerList(savedIds)
            : Future.value(<int, int>{}),
        customLists.isNotEmpty
            ? _customService
                .getBookCountsPerList(customLists.map((l) => l.id).toList())
            : Future.value(<int, int>{}),
        _curatedService.getReaderCounts(
            kCuratedLists.map((l) => l.id).toList()),
      ]);

      if (!mounted) return;
      setState(() {
        _savedListIds = savedIds;
        _readCounts = countResults[0];
        _customLists = customLists;
        _customBookCounts = countResults[1];
        _readerCounts = countResults[2];
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Erreur _loadData SavedListsTab: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<CuratedList> get _savedLists {
    return kCuratedLists
        .where((list) => _savedListIds.contains(list.id))
        .toList();
  }

  Future<void> _createList() async {
    final isPremium = context.read<SubscriptionProvider>().isPremium;
    if (!isPremium &&
        _customLists.length >= FeatureFlags.maxFreeCustomLists) {
      _showListLimitDialog();
      return;
    }
    final result = await showCreateCustomListSheet(context);
    if (result != null) {
      _loadData();
    }
  }

  void _showListLimitDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Limite atteinte'),
        content: Text(
          'Tu as atteint la limite de ${FeatureFlags.maxFreeCustomLists} listes de lecture. '
          'Passe à Premium pour en créer autant que tu veux !',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const UpgradePage()),
              );
            },
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFFF6B35),
            ),
            child: const Text('Passer Premium'),
          ),
        ],
      ),
    );
  }

  void _toggleCuratedListSave(int listId, bool save) async {
    setState(() {
      if (save) {
        _savedListIds.add(listId);
      } else {
        _savedListIds.remove(listId);
      }
    });

    try {
      if (save) {
        await _curatedService.saveList(listId);
      } else {
        await _curatedService.unsaveList(listId);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          if (save) {
            _savedListIds.remove(listId);
          } else {
            _savedListIds.add(listId);
          }
        });
      }
    }
  }

  void _navigateToCuratedListDetail(CuratedList list) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CuratedListDetailPage(list: list),
      ),
    );
    _loadData();
  }

  void _navigateToAllCuratedLists() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AllCuratedListsPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final savedLists = _savedLists;
    final hasAnyList = _customLists.isNotEmpty || savedLists.isNotEmpty;

    if (!hasAnyList) {
      return _buildEmptyState(context);
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          padding: const EdgeInsets.all(AppSpace.l),
          children: [
            // Listes personnelles
            if (_customLists.isNotEmpty) ...[
              _buildSectionHeader(
                context,
                'Mes listes',
                LucideIcons.user,
              ),
              const SizedBox(height: AppSpace.s),
              ..._customLists.map((list) {
                final bookCount = _customBookCounts[list.id] ?? 0;
                return _CustomListCard(
                  list: list,
                  bookCount: bookCount,
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CustomListDetailPage(list: list),
                      ),
                    );
                    _loadData();
                  },
                );
              }),
              const SizedBox(height: AppSpace.l),
            ],

            // Listes curated sauvegardées
            if (savedLists.isNotEmpty) ...[
              _buildSectionHeader(
                context,
                'Listes sauvegardées',
                LucideIcons.bookmark,
              ),
              const SizedBox(height: AppSpace.s),
              ...savedLists.map((list) {
                final readCount = _readCounts[list.id] ?? 0;
                return _SavedListCard(
                  list: list,
                  readCount: readCount,
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CuratedListDetailPage(list: list),
                      ),
                    );
                    _loadData();
                  },
                );
              }),
              const SizedBox(height: AppSpace.l),
            ],

            // Carousel de suggestions de listes curatées
            CuratedListsCarousel(
              lists: kCuratedLists,
              readerCounts: _readerCounts,
              savedListIds: _savedListIds,
              onToggleSave: _toggleCuratedListSave,
              onSeeAll: _navigateToAllCuratedLists,
              onListTap: _navigateToCuratedListDetail,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createList,
        backgroundColor: const Color(0xFFFF6B35),
        foregroundColor: Colors.white,
        child: const Icon(LucideIcons.plus),
      ),
    );
  }

  Widget _buildSectionHeader(
      BuildContext context, String title, IconData icon) {
    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: Theme.of(context)
              .colorScheme
              .onSurface
              .withValues(alpha: 0.5),
        ),
        const SizedBox(width: 6),
        Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Theme.of(context)
                .colorScheme
                .onSurface
                .withValues(alpha: 0.5),
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ListView(
        padding: const EdgeInsets.all(AppSpace.l),
        children: [
          const SizedBox(height: 24),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  LucideIcons.bookOpen,
                  size: 48,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.3),
                ),
                const SizedBox(height: 16),
                Text(
                  'Aucune liste',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.6),
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Crée ta propre liste de lecture ou découvre nos sélections curatées.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.4),
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: _createList,
                  icon: const Icon(LucideIcons.plus),
                  label: const Text('Créer une liste'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFFF6B35),
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Carousel de suggestions de listes curatées
          CuratedListsCarousel(
            lists: kCuratedLists,
            readerCounts: _readerCounts,
            savedListIds: _savedListIds,
            onToggleSave: _toggleCuratedListSave,
            onSeeAll: _navigateToAllCuratedLists,
            onListTap: _navigateToCuratedListDetail,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createList,
        backgroundColor: const Color(0xFFFF6B35),
        foregroundColor: Colors.white,
        child: const Icon(LucideIcons.plus),
      ),
    );
  }
}

class _CustomListCard extends StatelessWidget {
  final UserCustomList list;
  final int bookCount;
  final VoidCallback onTap;

  const _CustomListCard({
    required this.list,
    required this.bookCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final gradientColors = list.gradientColors;

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpace.m),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.m),
        side: BorderSide(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.black.withValues(alpha: 0.06),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.m),
        child: Row(
          children: [
            // Gradient strip
            Container(
              width: 6,
              height: 70,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: gradientColors,
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(AppRadius.m),
                  bottomLeft: Radius.circular(AppRadius.m),
                ),
              ),
            ),

            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Icon(
                      list.icon,
                      size: 18,
                      color: gradientColors.last,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        list.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '$bookCount livre${bookCount > 1 ? 's' : ''}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.5),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Icon(
                Icons.chevron_right,
                size: 20,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.3),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SavedListCard extends StatelessWidget {
  final CuratedList list;
  final int readCount;
  final VoidCallback onTap;

  const _SavedListCard({
    required this.list,
    required this.readCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final progress =
        list.bookCount > 0 ? readCount / list.bookCount : 0.0;

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpace.m),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.m),
        side: BorderSide(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.black.withValues(alpha: 0.06),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.m),
        child: Row(
          children: [
            // Gradient strip
            Container(
              width: 6,
              height: 80,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: list.gradientColors,
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(AppRadius.m),
                  bottomLeft: Radius.circular(AppRadius.m),
                ),
              ),
            ),

            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          list.icon,
                          size: 18,
                          color: list.gradientColors.last,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            list.title,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          '$readCount/${list.bookCount} lus',
                          style: TextStyle(
                            fontSize: 12,
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: progress,
                        backgroundColor: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.08),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          list.gradientColors.last,
                        ),
                        minHeight: 4,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Icon(
                Icons.chevron_right,
                size: 20,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.3),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
