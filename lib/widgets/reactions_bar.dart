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

  static const _activeBorder = Color(0xFF6B988D);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final activeReactions = reactionCounts.entries
        .where((e) => e.value > 0)
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Le coeur est déjà affiché comme pill si il a des réactions
    final heartInPills = activeReactions.any((e) => e.key == '❤️');

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        // Bouton coeur par défaut (si pas déjà dans les pills)
        if (!heartInPills)
          _HeartButton(
            isActive: userEmoji == '❤️',
            isDark: isDark,
            onTap: () => onToggleReaction('❤️'),
            onLongPress: onOpenPicker,
          ),
        ...activeReactions.map((entry) {
          final isUserReaction = userEmoji == entry.key;
          return _ReactionPill(
            emoji: entry.key,
            count: entry.value,
            isActive: isUserReaction,
            isDark: isDark,
            onTap: () => onToggleReaction(entry.key),
            onLongPress: entry.key == '❤️' ? onOpenPicker : null,
          );
        }),
      ],
    );
  }
}

class _HeartButton extends StatefulWidget {
  final bool isActive;
  final bool isDark;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _HeartButton({
    required this.isActive,
    required this.isDark,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  State<_HeartButton> createState() => _HeartButtonState();
}

class _HeartButtonState extends State<_HeartButton>
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
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.3), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.3, end: 1.0), weight: 50),
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
      onLongPress: widget.onLongPress,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Icon(
          widget.isActive ? Icons.favorite : Icons.favorite_border,
          size: 22,
          color: widget.isActive
              ? Colors.red
              : Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.4),
        ),
      ),
    );
  }
}

class _ReactionPill extends StatefulWidget {
  final String emoji;
  final int count;
  final bool isActive;
  final bool isDark;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _ReactionPill({
    required this.emoji,
    required this.count,
    required this.isActive,
    required this.isDark,
    required this.onTap,
    this.onLongPress,
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
      onLongPress: widget.onLongPress,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: context.appColors.pillBg,
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
