// lib/widgets/reactions_bar.dart
// Barre de réactions emoji affichée sous les activités du feed

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class ReactionsBar extends StatelessWidget {
  final Map<String, int> reactionCounts;
  final String? userEmoji;
  final VoidCallback onOpenPicker;
  final void Function(String emoji) onToggleReaction;

  const ReactionsBar({
    super.key,
    required this.reactionCounts,
    required this.userEmoji,
    required this.onOpenPicker,
    required this.onToggleReaction,
  });

  static const _pillBg = Color(0xFFF0EBE1);
  static const _pillBgDark = Color(0xFF2A2520);
  static const _activeBorder = Color(0xFF6B988D);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final activeReactions = reactionCounts.entries
        .where((e) => e.value > 0)
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        ...activeReactions.map((entry) {
          final isUserReaction = userEmoji == entry.key;
          return _ReactionPill(
            emoji: entry.key,
            count: entry.value,
            isActive: isUserReaction,
            isDark: isDark,
            onTap: () => onToggleReaction(entry.key),
          );
        }),
        // Bouton "+"
        GestureDetector(
          onTap: onOpenPicker,
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: isDark ? _pillBgDark : _pillBg,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.add,
              size: 16,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.5),
            ),
          ),
        ),
      ],
    );
  }
}

class _ReactionPill extends StatefulWidget {
  final String emoji;
  final int count;
  final bool isActive;
  final bool isDark;
  final VoidCallback onTap;

  const _ReactionPill({
    required this.emoji,
    required this.count,
    required this.isActive,
    required this.isDark,
    required this.onTap,
  });

  @override
  State<_ReactionPill> createState() => _ReactionPillState();
}

class _ReactionPillState extends State<_ReactionPill>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.2), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.2, end: 1.0), weight: 50),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    _controller.forward(from: 0);
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: widget.isDark
                ? ReactionsBar._pillBgDark
                : ReactionsBar._pillBg,
            borderRadius: BorderRadius.circular(AppRadius.pill),
            border: widget.isActive
                ? Border.all(color: ReactionsBar._activeBorder, width: 1.5)
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(widget.emoji, style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 4),
              Text(
                '${widget.count}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: widget.isActive
                      ? ReactionsBar._activeBorder
                      : Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
