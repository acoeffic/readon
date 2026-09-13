// lib/widgets/reading_for_picker.dart
//
// Sélecteur « Je lis pour » partagé : utilisé au démarrage d'une session
// (start_reading_session_page_unified) et pour la modification rétrospective
// (page résumé de fin de session, page détail d'une session).
//
// La clé 'myself' est l'état « pas de lecture partagée » : elle correspond à
// `reading_for = NULL` en base (convention posée au démarrage de session).

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../l10n/app_localizations.dart';
import '../theme/app_theme.dart';

const List<String> readingForKeys = [
  'myself', 'daughter', 'son', 'partner', 'friend',
  'mother', 'father', 'grandmother', 'grandfather', 'other',
];

String readingForEmoji(String key) {
  switch (key) {
    case 'myself': return '📖';
    case 'daughter': return '👧';
    case 'son': return '👦';
    case 'friend': return '🧑‍🤝‍🧑';
    case 'grandmother': return '👵';
    case 'grandfather': return '👴';
    case 'father': return '👨';
    case 'mother': return '👩';
    case 'partner': return '❤️';
    default: return '✨';
  }
}

String readingForLabel(AppLocalizations l, String key) {
  switch (key) {
    case 'myself': return l.readingForJustMe;
    case 'daughter': return l.readingForDaughter;
    case 'son': return l.readingForSon;
    case 'friend': return l.readingForFriend;
    case 'grandmother': return l.readingForGrandmother;
    case 'grandfather': return l.readingForGrandfather;
    case 'father': return l.readingForFather;
    case 'mother': return l.readingForMother;
    case 'partner': return l.readingForPartner;
    default: return l.readingForOther;
  }
}

/// Ouvre le bottom sheet de sélection et retourne la clé choisie,
/// ou `null` si l'utilisateur a fermé sans choisir.
///
/// [current] : clé actuellement sélectionnée ('myself' si aucune).
/// [accentColor] / [backgroundColor] : permettent à la page Démarrer de
/// conserver son thème fixe ; par défaut le sheet s'adapte au thème clair/sombre.
Future<String?> showReadingForPicker(
  BuildContext context, {
  String current = 'myself',
  Color? accentColor,
  Color? backgroundColor,
}) {
  final l = AppLocalizations.of(context);
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final bg = backgroundColor ??
      (isDark ? AppColors.surfaceDark : AppColors.libraryBg);
  final accent = accentColor ?? AppColors.sageGreen;
  final itemBg = isDark ? Colors.white.withValues(alpha: 0.06) : Colors.white;
  final itemBorder =
      isDark ? Colors.white.withValues(alpha: 0.12) : const Color(0xFFE2DDD5);
  final textColor = isDark ? AppColors.textPrimaryDark : const Color(0xFF1A1A1A);

  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) {
      return Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: EdgeInsets.only(
          top: 12,
          left: 16,
          right: 16,
          bottom: MediaQuery.of(ctx).padding.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFBDB5A8),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                l.readingForLabel,
                style: GoogleFonts.dmSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.5,
                  color: accent,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  children: readingForKeys.map((key) {
                    final isSelected = key == current;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => Navigator.of(ctx).pop(key),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? accent.withValues(alpha: 0.12)
                                  : itemBg,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSelected ? accent : itemBorder,
                                width: isSelected ? 1.5 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Text(
                                  readingForEmoji(key),
                                  style: const TextStyle(fontSize: 22),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Text(
                                    readingForLabel(l, key),
                                    style: GoogleFonts.dmSans(
                                      fontSize: 15,
                                      fontWeight: isSelected
                                          ? FontWeight.w600
                                          : FontWeight.w500,
                                      color: textColor,
                                    ),
                                  ),
                                ),
                                if (isSelected)
                                  Icon(
                                    Icons.check_rounded,
                                    color: accent,
                                    size: 20,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}
