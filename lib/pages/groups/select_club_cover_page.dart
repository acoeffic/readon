import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../services/club_covers_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/back_header.dart';
import '../../widgets/constrained_content.dart';

/// Picker plein-écran qui présente la bibliothèque curée de couvertures.
/// Renvoie l'URL choisie via Navigator.pop, ou null si annulé.
class SelectClubCoverPage extends StatefulWidget {
  final String? currentCoverUrl;

  const SelectClubCoverPage({super.key, this.currentCoverUrl});

  @override
  State<SelectClubCoverPage> createState() => _SelectClubCoverPageState();
}

class _SelectClubCoverPageState extends State<SelectClubCoverPage> {
  final _service = ClubCoversService();
  late Future<List<ClubCover>> _future;
  String? _selectedCategory;

  @override
  void initState() {
    super.initState();
    // Force refresh à chaque ouverture du picker pour voir les covers
    // ajoutées depuis le dernier launch (le trigger storage les pousse en
    // table dès l'upload côté dashboard).
    _future = _service.getAvailable(forceRefresh: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: ConstrainedContent(
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.l),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BackHeader(
                  title: 'Choisir une couverture',
                  titleColor: Theme.of(context).colorScheme.onSurface,
                ),
                const SizedBox(height: AppSpace.m),
                Expanded(
                  child: FutureBuilder<List<ClubCover>>(
                    future: _future,
                    builder: (context, snap) {
                      if (snap.connectionState != ConnectionState.done) {
                        return const Center(
                          child: CircularProgressIndicator(),
                        );
                      }
                      if (snap.hasError) {
                        return _buildError(context, snap.error.toString());
                      }
                      final all = snap.data ?? const <ClubCover>[];
                      if (all.isEmpty) {
                        return _buildEmpty(context);
                      }

                      // Catégories disponibles
                      final categories = <String>{
                        for (final c in all)
                          if (c.category != null && c.category!.isNotEmpty)
                            c.category!,
                      }.toList()
                        ..sort();

                      final filtered = _selectedCategory == null
                          ? all
                          : all
                              .where((c) => c.category == _selectedCategory)
                              .toList();

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (categories.isNotEmpty) ...[
                            _buildCategoryChips(categories),
                            const SizedBox(height: AppSpace.m),
                          ],
                          Expanded(
                            child: GridView.builder(
                              padding: EdgeInsets.zero,
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                mainAxisSpacing: AppSpace.m,
                                crossAxisSpacing: AppSpace.m,
                                childAspectRatio: 2 / 1.2,
                              ),
                              itemCount: filtered.length,
                              itemBuilder: (context, i) {
                                final c = filtered[i];
                                final isSelected =
                                    c.url == widget.currentCoverUrl;
                                return _CoverTile(
                                  cover: c,
                                  isSelected: isSelected,
                                  onTap: () =>
                                      Navigator.of(context).pop(c.url),
                                );
                              },
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryChips(List<String> categories) {
    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        itemCount: categories.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpace.s),
        itemBuilder: (context, i) {
          if (i == 0) {
            return _CategoryChip(
              label: 'Tout',
              selected: _selectedCategory == null,
              onTap: () => setState(() => _selectedCategory = null),
            );
          }
          final cat = categories[i - 1];
          return _CategoryChip(
            label: cat,
            selected: _selectedCategory == cat,
            onTap: () => setState(() => _selectedCategory = cat),
          );
        },
      ),
    );
  }

  Widget _buildError(BuildContext context, String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline,
                size: 48,
                color: Theme.of(context).colorScheme.error.withValues(alpha: 0.7)),
            const SizedBox(height: 12),
            Text(
              'Impossible de charger',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.55),
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () {
                setState(() {
                  _future = _service.getAvailable(forceRefresh: true);
                });
              },
              child: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.image_outlined,
              size: 56,
              color: AppColors.primary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 12),
            Text(
              'Aucune couverture disponible',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              'La bibliothèque sera bientôt enrichie.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.55),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CoverTile extends StatelessWidget {
  final ClubCover cover;
  final bool isSelected;
  final VoidCallback onTap;

  const _CoverTile({
    required this.cover,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.l),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08),
            width: isSelected ? 3 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            CachedNetworkImage(
              imageUrl: cover.url,
              fit: BoxFit.cover,
              memCacheWidth: 800,
              placeholder: (_, __) => Container(
                color: AppColors.primary.withValues(alpha: 0.1),
              ),
              errorWidget: (_, __, ___) => Container(
                color: AppColors.primary.withValues(alpha: 0.15),
                child: const Icon(Icons.broken_image_outlined),
              ),
            ),
            if (isSelected)
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check,
                    size: 16,
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    return Material(
      color: selected ? AppColors.primary : Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.m,
            vertical: AppSpace.s,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: selected
                ? null
                : Border.all(color: onSurface.withValues(alpha: 0.15)),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : onSurface.withValues(alpha: 0.75),
            ),
          ),
        ),
      ),
    );
  }
}
