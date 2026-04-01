import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/reading_statistics.dart';
import '../../../theme/app_theme.dart';

class ReadingForStatsCard extends StatelessWidget {
  final List<ReadingForStatEntry> data;

  const ReadingForStatsCard({super.key, required this.data});

  String _resolveLabel(AppLocalizations l, String key) {
    switch (key) {
      case 'daughter':
        return l.readingForDaughter;
      case 'son':
        return l.readingForSon;
      case 'friend':
        return l.readingForFriend;
      case 'grandmother':
        return l.readingForGrandmother;
      case 'grandfather':
        return l.readingForGrandfather;
      case 'father':
        return l.readingForFather;
      case 'mother':
        return l.readingForMother;
      case 'partner':
        return l.readingForPartner;
      case 'other':
        return l.readingForOther;
      default:
        return key;
    }
  }

  String _resolveEmoji(String key) {
    switch (key) {
      case 'daughter':
        return '\uD83D\uDC67';
      case 'son':
        return '\uD83D\uDC66';
      case 'friend':
        return '\uD83E\uDDD1\u200D\uD83E\uDD1D\u200D\uD83E\uDDD1';
      case 'grandmother':
        return '\uD83D\uDC75';
      case 'grandfather':
        return '\uD83D\uDC74';
      case 'father':
        return '\uD83D\uDC68';
      case 'mother':
        return '\uD83D\uDC69';
      case 'partner':
        return '\u2764\uFE0F';
      default:
        return '\uD83D\uDCD6';
    }
  }

  String _formatMinutes(int minutes) {
    if (minutes < 60) return '${minutes}min';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (m == 0) return '${h}h';
    return '${h}h${m}min';
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(AppSpace.l),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(AppRadius.l),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.readingForStatsTitle,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            l.readingForStatsSubtitle,
            style: TextStyle(
              fontSize: 13,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: AppSpace.l),
          ...data.map((entry) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpace.m),
                child: Container(
                  padding: const EdgeInsets.all(AppSpace.m),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : AppColors.primary.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(AppRadius.m),
                  ),
                  child: Row(
                    children: [
                      Text(
                        _resolveEmoji(entry.key),
                        style: const TextStyle(fontSize: 28),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _resolveLabel(l, entry.key),
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${_formatMinutes(entry.totalMinutes)}  ·  ${l.readingForPages(entry.totalPages)}  ·  ${l.readingForSessions(entry.totalSessions)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withValues(alpha: 0.6),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              )),
        ],
      ),
    );
  }
}
