import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../data/curated_lists_data.dart';
import '../../models/curated_list.dart';
import '../../services/curated_lists_service.dart';
import '../../theme/app_theme.dart';
import 'curated_list_detail_page.dart';

class AllCuratedListsPage extends StatefulWidget {
  const AllCuratedListsPage({super.key});

  @override
  State<AllCuratedListsPage> createState() => _AllCuratedListsPageState();
}

class _AllCuratedListsPageState extends State<AllCuratedListsPage> {
  final _service = CuratedListsService();

  bool _isLoading = true;
  Map<int, int> _readerCounts = {};
  Set<int> _savedListIds = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final results = await Future.wait([
        _service.getReaderCounts(
            kCuratedLists.map((l) => l.id).toList()),
        _service.getSavedListIds(),
      ]);

      if (!mounted) return;
      setState(() {
        _readerCounts = results[0] as Map<int, int>;
        _savedListIds = results[1] as Set<int>;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Erreur AllCuratedListsPage _loadData: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _toggleSave(int listId) async {
    final wasSaved = _savedListIds.contains(listId);
    setState(() {
      if (wasSaved) {
        _savedListIds.remove(listId);
      } else {
        _savedListIds.add(listId);
      }
    });

    try {
      if (!wasSaved) {
        await _service.saveList(listId);
      } else {
        await _service.unsaveList(listId);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          if (wasSaved) {
            _savedListIds.add(listId);
          } else {
            _savedListIds.remove(listId);
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Listes de lecture'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView.builder(
                padding: const EdgeInsets.all(AppSpace.l),
                itemCount: kCuratedLists.length,
                itemBuilder: (context, index) {
                  final list = kCuratedLists[index];
                  final isSaved = _savedListIds.contains(list.id);
                  final readerCount = _readerCounts[list.id] ?? 0;
                  return _AllListCard(
                    list: list,
                    isSaved: isSaved,
                    readerCount: readerCount,
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              CuratedListDetailPage(list: list),
                        ),
                      );
                      _loadData();
                    },
                    onToggleSave: () => _toggleSave(list.id),
                  );
                },
              ),
            ),
    );
  }
}

class _AllListCard extends StatelessWidget {
  final CuratedList list;
  final bool isSaved;
  final int readerCount;
  final VoidCallback onTap;
  final VoidCallback onToggleSave;

  const _AllListCard({
    required this.list,
    required this.isSaved,
    required this.readerCount,
    required this.onTap,
    required this.onToggleSave,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.m),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 160,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: list.gradientColors,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Stack(
            children: [
              // Watermark icon
              Positioned(
                top: -10,
                right: -10,
                child: Icon(
                  list.icon,
                  size: 120,
                  color: Colors.white.withValues(alpha: 0.1),
                ),
              ),

              // Content
              Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(list.icon, size: 22, color: Colors.white),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${list.bookCount} livres',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                        GestureDetector(
                          onTap: onToggleSave,
                          child: Icon(
                            isSaved
                                ? Icons.favorite
                                : Icons.favorite_border,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ],
                    ),

                    const Spacer(),

                    // Title
                    Text(
                      list.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      list.subtitle,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Reader count
                    Row(
                      children: [
                        Icon(Icons.people_outline,
                            size: 14,
                            color: Colors.white.withValues(alpha: 0.7)),
                        const SizedBox(width: 4),
                        Text(
                          '$readerCount lecteur${readerCount > 1 ? 's' : ''}',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 12,
                          ),
                        ),
                      ],
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
