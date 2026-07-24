// lib/services/watch_session_draft_service.dart
// Mémorise la dernière session terminée depuis l'Apple Watch dont les pages
// n'ont pas été confirmées par l'utilisateur. La Watch ne permet ni saisie
// confortable ni photo/OCR : à la prochaine ouverture de l'app iPhone, un
// dialogue de rattrapage propose de compléter/corriger les pages
// (voir WatchSessionCatchupDialog).

import 'package:shared_preferences/shared_preferences.dart';

/// Brouillon d'une session Watch en attente de confirmation des pages.
class WatchSessionDraft {
  final String sessionId;
  final int startPage;
  final int endPage;
  final int durationMinutes;
  final String? bookTitle;

  const WatchSessionDraft({
    required this.sessionId,
    required this.startPage,
    required this.endPage,
    required this.durationMinutes,
    this.bookTitle,
  });
}

class WatchSessionDraftService {
  static const _keySessionId = 'watch_draft_session_id';
  static const _keyStartPage = 'watch_draft_start_page';
  static const _keyEndPage = 'watch_draft_end_page';
  static const _keyMinutes = 'watch_draft_minutes';
  static const _keyBookTitle = 'watch_draft_book_title';

  /// Enregistre le brouillon (écrase le précédent : on ne rattrape que la
  /// dernière session Watch, les plus anciennes restent en "temps seul").
  Future<void> save(WatchSessionDraft draft) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keySessionId, draft.sessionId);
    await prefs.setInt(_keyStartPage, draft.startPage);
    await prefs.setInt(_keyEndPage, draft.endPage);
    await prefs.setInt(_keyMinutes, draft.durationMinutes);
    final title = draft.bookTitle;
    if (title != null && title.isNotEmpty) {
      await prefs.setString(_keyBookTitle, title);
    } else {
      await prefs.remove(_keyBookTitle);
    }
  }

  /// Brouillon en attente, ou null.
  Future<WatchSessionDraft?> getPending() async {
    final prefs = await SharedPreferences.getInstance();
    final sessionId = prefs.getString(_keySessionId);
    if (sessionId == null || sessionId.isEmpty) return null;
    return WatchSessionDraft(
      sessionId: sessionId,
      startPage: prefs.getInt(_keyStartPage) ?? 1,
      endPage: prefs.getInt(_keyEndPage) ?? 1,
      durationMinutes: prefs.getInt(_keyMinutes) ?? 0,
      bookTitle: prefs.getString(_keyBookTitle),
    );
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keySessionId);
    await prefs.remove(_keyStartPage);
    await prefs.remove(_keyEndPage);
    await prefs.remove(_keyMinutes);
    await prefs.remove(_keyBookTitle);
  }
}
