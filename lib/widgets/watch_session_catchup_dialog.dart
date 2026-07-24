// lib/widgets/watch_session_catchup_dialog.dart
// Rattrapage d'une session terminée depuis l'Apple Watch : la Watch ne permet
// pas de saisir la page de fin, on la complète ici (saisie manuelle ou
// photo/OCR). La page de départ est corrigeable au cas où la dernière page
// connue du livre était fausse.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../l10n/app_localizations.dart';
import '../services/ocr_service.dart';
import '../services/reading_session_service.dart';
import '../services/watch_session_draft_service.dart';
import '../theme/app_theme.dart';

class WatchSessionCatchupDialog extends StatefulWidget {
  final WatchSessionDraft draft;

  const WatchSessionCatchupDialog({super.key, required this.draft});

  @override
  State<WatchSessionCatchupDialog> createState() =>
      _WatchSessionCatchupDialogState();
}

class _WatchSessionCatchupDialogState extends State<WatchSessionCatchupDialog> {
  late final TextEditingController _startController;
  late final TextEditingController _endController;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _startController =
        TextEditingController(text: widget.draft.startPage.toString());
    // La page de fin auto (= page courante du livre) n'apporte rien si elle
    // n'a pas avancé : on laisse le champ vide pour inviter à la saisie.
    _endController = TextEditingController(
      text: widget.draft.endPage > widget.draft.startPage
          ? widget.draft.endPage.toString()
          : '',
    );
  }

  @override
  void dispose() {
    _startController.dispose();
    _endController.dispose();
    super.dispose();
  }

  /// Photo de la page + OCR pour remplir la page de fin, comme dans le flux
  /// normal de fin de session.
  Future<void> _scanEndPage() async {
    final l = AppLocalizations.of(context);
    try {
      final photo = await ImagePicker().pickImage(
        source: ImageSource.camera,
        maxWidth: 1500,
        imageQuality: 85,
      );
      if (photo == null || !mounted) return;
      setState(() {
        _busy = true;
        _error = null;
      });
      final page = await OCRService().extractPageNumber(photo.path);
      if (!mounted) return;
      setState(() {
        _busy = false;
        if (page != null) {
          _endController.text = page.toString();
        } else {
          _error = l.watchCatchupOcrFailed;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = l.watchCatchupOcrFailed;
      });
    }
  }

  Future<void> _save() async {
    final l = AppLocalizations.of(context);
    final startPage = int.tryParse(_startController.text.trim());
    final endPage = int.tryParse(_endController.text.trim());

    if (startPage == null || endPage == null) {
      setState(() => _error = l.watchCatchupEnterPages);
      return;
    }
    if (endPage < startPage) {
      setState(() => _error = l.endPageBeforeStartDetailed(endPage, startPage));
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ReadingSessionService().updateSessionPages(
        sessionId: widget.draft.sessionId,
        startPage: startPage,
        endPage: endPage,
      );
      await WatchSessionDraftService().clear();
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = l.watchCatchupError;
      });
    }
  }

  /// La session reste valide en "temps seul" : on abandonne juste le
  /// rattrapage des pages.
  Future<void> _skip() async {
    await WatchSessionDraftService().clear();
    if (mounted) Navigator.of(context).pop();
  }

  InputDecoration _pageFieldDecoration(String label, AppThemeColors colors) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: colors.textSecondary, fontSize: 13),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      isDense: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final colors = context.appColors;

    return AlertDialog(
      backgroundColor: colors.cardBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(Icons.watch, color: colors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              l.watchCatchupTitle,
              style: TextStyle(
                color: colors.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 17,
              ),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.watchCatchupBody(widget.draft.durationMinutes),
            style: TextStyle(color: colors.textSecondary, fontSize: 14),
          ),
          if (widget.draft.bookTitle != null &&
              widget.draft.bookTitle!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              widget.draft.bookTitle!,
              style: TextStyle(
                color: colors.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  key: const Key('watch_catchup_start_page'),
                  controller: _startController,
                  enabled: !_busy,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: TextStyle(color: colors.textPrimary),
                  decoration:
                      _pageFieldDecoration(l.watchCatchupStartPage, colors),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  key: const Key('watch_catchup_end_page'),
                  controller: _endController,
                  enabled: !_busy,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: TextStyle(color: colors.textPrimary),
                  decoration:
                      _pageFieldDecoration(l.watchCatchupEndPage, colors),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _busy ? null : _scanEndPage,
              icon: const Icon(Icons.camera_alt_outlined, size: 18),
              label: Text(l.watchCatchupScan),
              style: TextButton.styleFrom(
                foregroundColor: colors.primary,
                padding: EdgeInsets.zero,
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 4),
            Text(
              _error!,
              style: const TextStyle(color: AppColors.error, fontSize: 13),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : _skip,
          child: Text(
            l.watchCatchupSkip,
            style: TextStyle(color: colors.textSecondary),
          ),
        ),
        ElevatedButton(
          onPressed: _busy ? null : _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: colors.primary,
            foregroundColor: Colors.white,
          ),
          child: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(l.watchCatchupSave),
        ),
      ],
    );
  }
}
