// lib/widgets/reaction_picker.dart
// Bottom sheet de sélection de réaction emoji

import 'package:flutter/material.dart';
import '../services/reaction_service.dart';
import '../pages/profile/upgrade_page.dart';
import '../theme/app_theme.dart';

class ReactionPicker {
  static const _sheetBg = Color(0xFFFAF3E8);
  static const _sheetBgDark = Color(0xFF1E1A15);

  /// Affiche le picker en bottom sheet et retourne l'emoji sélectionné (ou null)
  static Future<String?> show({
    required BuildContext context,
    required String? currentEmoji,
    required bool isPremium,
  }) async {
    return showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? _sheetBgDark
          : _sheetBg,
      builder: (ctx) => _PickerSheet(
        currentEmoji: currentEmoji,
        isPremium: isPremium,
      ),
    );
  }
}

class _PickerSheet extends StatelessWidget {
  final String? currentEmoji;
  final bool isPremium;

  const _PickerSheet({
    required this.currentEmoji,
    required this.isPremium,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpace.l,
          AppSpace.m,
          AppSpace.l,
          AppSpace.l,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Emojis row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: ReactionService.allEmojis.map((emoji) {
                final isSelected = currentEmoji == emoji;
                final isPremiumEmoji = ReactionService.isPremiumEmoji(emoji);
                final isLocked = isPremiumEmoji && !isPremium;

                return _EmojiButton(
                  emoji: emoji,
                  isSelected: isSelected,
                  showCrown: isLocked,
                  onTap: () {
                    if (isLocked) {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const UpgradePage(),
                        ),
                      );
                    } else {
                      Navigator.pop(context, emoji);
                    }
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _EmojiButton extends StatefulWidget {
  final String emoji;
  final bool isSelected;
  final bool showCrown;
  final VoidCallback onTap;

  const _EmojiButton({
    required this.emoji,
    required this.isSelected,
    required this.showCrown,
    required this.onTap,
  });

  @override
  State<_EmojiButton> createState() => _EmojiButtonState();
}

class _EmojiButtonState extends State<_EmojiButton>
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
    ]).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: _handleTap,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: widget.isSelected
                    ? AppColors.primary.withValues(alpha: isDark ? 0.3 : 0.15)
                    : Colors.transparent,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  widget.emoji,
                  style: TextStyle(
                    fontSize: widget.isSelected ? 30 : 26,
                  ),
                ),
              ),
            ),
            // Crown badge for locked premium emojis
            if (widget.showCrown)
              const Positioned(
                top: -2,
                right: -2,
                child: Text('👑', style: TextStyle(fontSize: 12)),
              ),
          ],
        ),
      ),
    );
  }
}
