// lib/pages/feed/widgets/first_session_banner.dart
//
// Bandeau « Commence ta première session » du feed.
//
// Analyse PostHog du 10/11/2026 : 36 inscrits ont un livre mais zéro session,
// et le feed ne leur montre aucun appel à lire — la carte « Continuer la
// lecture » ne naît qu'avec la première session. Ce bandeau comble ce trou
// pour les inscrits qui n'ont encore JAMAIS lu.
//
// Il se base sur les sessions réelles (reading_sessions), pas sur
// profiles.has_completed_first_session, qui reste faux chez des lecteurs
// pourtant actifs. Autonome : se charge seul, ne s'affiche que s'il y a un
// livre et aucune session, et disparaît dès qu'une session existe.

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../l10n/app_localizations.dart';
import '../../../models/book.dart';
import '../../../services/analytics_service.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/cached_book_cover.dart';
import '../../reading/active_reading_session_page.dart';
import '../../reading/start_reading_session_page_unified.dart';

class FirstSessionBanner extends StatefulWidget {
  /// Appelé au retour de l'écran de lecture, pour rafraîchir le feed.
  final VoidCallback? onReturn;

  const FirstSessionBanner({super.key, this.onReturn});

  @override
  State<FirstSessionBanner> createState() => _FirstSessionBannerState();
}

class _FirstSessionBannerState extends State<FirstSessionBanner> {
  Book? _book;
  bool _shownTracked = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id;
      if (userId == null) return;

      final sessions = await client
          .from('reading_sessions')
          .select('id')
          .eq('user_id', userId)
          .limit(1);
      if ((sessions as List).isNotEmpty) {
        if (mounted && _book != null) setState(() => _book = null);
        return;
      }

      // « reading » d'abord (c'est le livre choisi à l'onboarding), sinon le
      // dernier ajouté. Les livres terminés ou masqués ne comptent pas.
      final rows = await client
          .from('user_books')
          .select('status, books(*)')
          .eq('user_id', userId)
          .eq('is_hidden', false)
          .neq('status', 'finished')
          .order('updated_at', ascending: false)
          .limit(10);
      Map<String, dynamic>? pick;
      for (final r in (rows as List)) {
        final m = Map<String, dynamic>.from(r as Map);
        if (m['books'] == null) continue;
        if (m['status'] == 'reading') {
          pick = m;
          break;
        }
        pick ??= m;
      }
      if (pick == null || !mounted) return;
      final book =
          Book.fromJson(Map<String, dynamic>.from(pick['books'] as Map));
      setState(() => _book = book);
      if (!_shownTracked) {
        _shownTracked = true;
        AnalyticsService().track(
          AnalyticsEvent.firstSessionBannerShown,
          properties: {'status': (pick['status'] as String?) ?? 'unknown'},
        );
      }
    } catch (e) {
      // Best-effort : sans bandeau, le feed reste exactement comme avant.
      debugPrint('FirstSessionBanner load error: $e');
    }
  }

  Future<void> _start() async {
    final book = _book;
    if (book == null) return;
    AnalyticsService().track(AnalyticsEvent.firstSessionBannerTapped);
    final session = await Navigator.push<dynamic>(
      context,
      MaterialPageRoute(
        builder: (_) => StartReadingSessionPageUnified(book: book),
      ),
    );
    if (session != null && mounted) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              ActiveReadingSessionPage(activeSession: session, book: book),
        ),
      );
    }
    widget.onReturn?.call();
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final book = _book;
    if (book == null) return const SizedBox.shrink();
    final l = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryText = isDark ? Colors.white : Colors.black87;
    final secondary = isDark ? Colors.white70 : Colors.black54;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.l),
      child: Material(
        color: AppColors.primary.withValues(alpha: isDark ? 0.14 : 0.08),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: _start,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border:
                  Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
            ),
            child: Row(
              children: [
                CachedBookCover(
                  imageUrl: book.coverUrl,
                  isbn: book.isbn,
                  googleId: book.googleId,
                  title: book.title,
                  author: book.author,
                  width: 56,
                  height: 84,
                  borderRadius: BorderRadius.circular(AppRadius.s),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.firstSessionBannerTitle,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: primaryText,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        l.firstSessionBannerSubtitle(book.title),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style:
                            TextStyle(fontSize: 13, color: secondary, height: 1.3),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.play_arrow_rounded,
                                size: 20, color: Colors.white),
                            const SizedBox(width: 4),
                            Text(
                              l.firstSessionBannerCta,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
