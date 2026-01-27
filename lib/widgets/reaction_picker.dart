// lib/widgets/reaction_picker.dart
// Popup flottant de sélection de réactions avancées (premium)

import 'package:flutter/material.dart';
import '../services/reactions_service.dart';
import '../theme/app_theme.dart';

class ReactionPicker extends StatelessWidget {
  final List<String> selectedReactions;
  final void Function(String reactionType) onReactionSelected;

  const ReactionPicker({
    super.key,
    required this.selectedReactions,
    required this.onReactionSelected,
  });

  /// Affiche le picker en overlay au-dessus du widget source
  static void show({
    required BuildContext context,
    required RenderBox anchorBox,
    required List<String> selectedReactions,
    required void Function(String reactionType) onReactionSelected,
  }) {
    final overlay = Overlay.of(context);
    final anchorPos = anchorBox.localToGlobal(Offset.zero);

    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (ctx) {
        // Positionner au-dessus du bouton like
        final top = anchorPos.dy - 60;
        final left = anchorPos.dx - 20;

        return Stack(
          children: [
            // Fond transparent pour dismiss
            Positioned.fill(
              child: GestureDetector(
                onTap: () => entry.remove(),
                behavior: HitTestBehavior.opaque,
                child: const SizedBox.expand(),
              ),
            ),
            // Picker
            Positioned(
              top: top,
              left: left,
              child: _AnimatedPicker(
                selectedReactions: selectedReactions,
                onReactionSelected: (type) {
                  onReactionSelected(type);
                  entry.remove();
                },
              ),
            ),
          ],
        );
      },
    );

    overlay.insert(entry);
  }

  @override
  Widget build(BuildContext context) {
    return _PickerBar(
      selectedReactions: selectedReactions,
      onReactionSelected: onReactionSelected,
    );
  }
}

class _AnimatedPicker extends StatefulWidget {
  final List<String> selectedReactions;
  final void Function(String reactionType) onReactionSelected;

  const _AnimatedPicker({
    required this.selectedReactions,
    required this.onReactionSelected,
  });

  @override
  State<_AnimatedPicker> createState() => _AnimatedPickerState();
}

class _AnimatedPickerState extends State<_AnimatedPicker>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: ScaleTransition(
        scale: _scaleAnimation,
        alignment: Alignment.bottomLeft,
        child: _PickerBar(
          selectedReactions: widget.selectedReactions,
          onReactionSelected: widget.onReactionSelected,
        ),
      ),
    );
  }
}

class _PickerBar extends StatelessWidget {
  final List<String> selectedReactions;
  final void Function(String reactionType) onReactionSelected;

  const _PickerBar({
    required this.selectedReactions,
    required this.onReactionSelected,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(AppRadius.pill),
      color: isDark ? AppColors.surfaceDark : Colors.white,
      shadowColor: Colors.black26,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: ReactionType.all.map((type) {
            final isSelected = selectedReactions.contains(type);
            return GestureDetector(
              onTap: () => onReactionSelected(type),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.symmetric(horizontal: 2),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primary.withValues(alpha: 0.2)
                      : Colors.transparent,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  ReactionType.emoji(type),
                  style: TextStyle(
                    fontSize: isSelected ? 26 : 22,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
