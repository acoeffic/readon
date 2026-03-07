import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../models/reading_session.dart';
import '../models/book.dart';
import '../theme/app_theme.dart';

class ActiveSessionBanner extends StatelessWidget {
  final ReadingSession session;
  final Book book;
  final Duration elapsed;
  final VoidCallback onTap;

  const ActiveSessionBanner({
    super.key,
    required this.session,
    required this.book,
    required this.elapsed,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final minutes = elapsed.inMinutes;
    final label = minutes < 1 ? 'À l\'instant' : '$minutes min';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: const BoxDecoration(
          color: AppColors.primary,
        ),
        child: SafeArea(
          bottom: false,
          child: Row(
            children: [
              const Text(
                '📖',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l.readingNow(label),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color: Colors.white,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
