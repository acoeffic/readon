// lib/pages/reading/add_past_session_page.dart
// "Ajouter une lecture passée" : saisie manuelle a posteriori d'une session
// (chrono oublié). Pages début/fin + durée + date/heure. Une lecture d'un
// jour passé (antidatée) compte pour les stats/feed/défis mais pas pour la
// flamme (voir FlowService / ReadingSession.isBackdated).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lexday/features/badges/services/badges_service.dart';
import 'package:lexday/features/badges/widgets/badge_unlocked_dialog.dart';

import '../../l10n/app_localizations.dart';
import '../../models/book.dart';
import '../../services/flow_service.dart';
import '../../services/ocr_service.dart';
import '../../services/reading_session_service.dart';
import '../../services/widget_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/cached_book_cover.dart';
import '../../widgets/constrained_content.dart';

class AddPastSessionPage extends StatefulWidget {
  final Book book;

  /// Page de départ pré-remplie (dernière page connue du livre).
  final int? initialStartPage;

  const AddPastSessionPage({
    super.key,
    required this.book,
    this.initialStartPage,
  });

  @override
  State<AddPastSessionPage> createState() => _AddPastSessionPageState();
}

class _AddPastSessionPageState extends State<AddPastSessionPage> {
  static const List<int> _durationChips = [15, 30, 45, 60];

  final _sessionService = ReadingSessionService();
  late final TextEditingController _startController;
  final _endController = TextEditingController();
  final _durationController = TextEditingController();

  DateTime _date = DateTime.now();
  TimeOfDay _endTimeOfDay = TimeOfDay.now();
  int? _selectedChip;
  bool _saving = false;
  bool _hasActiveSessionOnBook = false;
  String? _error;

  bool get _isToday {
    final now = DateTime.now();
    return _date.year == now.year &&
        _date.month == now.month &&
        _date.day == now.day;
  }

  @override
  void initState() {
    super.initState();
    _startController = TextEditingController(
      text: widget.initialStartPage != null && widget.initialStartPage! > 0
          ? widget.initialStartPage.toString()
          : '',
    );
    _checkActiveSession();
  }

  @override
  void dispose() {
    _startController.dispose();
    _endController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  /// Bloquer la saisie si une session est déjà active sur ce livre : la page
  /// courante bougerait sous les pieds de la session en cours.
  Future<void> _checkActiveSession() async {
    final active =
        await _sessionService.getActiveSession(widget.book.id.toString());
    if (!mounted) return;
    setState(() => _hasActiveSessionOnBook = active != null);
  }

  int? get _durationMinutes {
    if (_selectedChip != null) return _selectedChip;
    return int.tryParse(_durationController.text.trim());
  }

  /// Avertissement non bloquant : sous les seuils de la flamme.
  bool get _tooShortForFlow {
    final pages = (int.tryParse(_endController.text.trim()) ?? 0) -
        (int.tryParse(_startController.text.trim()) ?? 0);
    final minutes = _durationMinutes ?? 0;
    if (_endController.text.trim().isEmpty || minutes == 0) return false;
    return pages < 1 || minutes < 2;
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now,
    );
    if (picked == null || !mounted) return;
    setState(() {
      _date = picked;
      // Pour un jour passé, "à l'instant" n'a pas de sens : défaut 21:00.
      if (!_isToday) {
        _endTimeOfDay = const TimeOfDay(hour: 21, minute: 0);
      } else {
        _endTimeOfDay = TimeOfDay.now();
      }
    });
  }

  Future<void> _pickTime() async {
    final picked =
        await showTimePicker(context: context, initialTime: _endTimeOfDay);
    if (picked == null || !mounted) return;
    setState(() => _endTimeOfDay = picked);
  }

  Future<void> _scanEndPage() async {
    final l = AppLocalizations.of(context);
    try {
      final photo = await ImagePicker().pickImage(
        source: ImageSource.camera,
        maxWidth: 1500,
        imageQuality: 85,
      );
      if (photo == null || !mounted) return;
      setState(() => _error = null);
      final page = await OCRService().extractPageNumber(photo.path);
      if (!mounted) return;
      setState(() {
        if (page != null) {
          _endController.text = page.toString();
        } else {
          _error = l.watchCatchupOcrFailed;
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = l.watchCatchupOcrFailed);
    }
  }

  Future<void> _save() async {
    final l = AppLocalizations.of(context);
    if (_hasActiveSessionOnBook) {
      setState(() => _error = l.addPastSessionActiveSessionError);
      return;
    }

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
    final minutes = _durationMinutes;
    if (minutes == null || minutes <= 0) {
      setState(() => _error = l.addPastSessionEnterDuration);
      return;
    }

    var endTime = DateTime(
      _date.year,
      _date.month,
      _date.day,
      _endTimeOfDay.hour,
      _endTimeOfDay.minute,
    );
    final now = DateTime.now();
    if (endTime.isAfter(now)) endTime = now;

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final session = await _sessionService.insertPastSession(
        bookId: widget.book.id.toString(),
        startPage: startPage,
        endPage: endPage,
        duration: Duration(minutes: minutes),
        endTime: endTime,
      );

      // Hooks post-session (comme la fin de session normale), non bloquants.
      WidgetService().updateWidget().catchError((_) {});

      List<dynamic> newBadges = [];
      List<dynamic> newSecretBadges = [];
      try {
        newBadges = await BadgesService().checkAndAwardBadges();
      } catch (e) {
        debugPrint('Erreur checkAndAwardBadges (non bloquante): $e');
      }
      try {
        newSecretBadges = await BadgesService()
            .checkSecretBadges(sessionId: session.id, bookFinished: false);
      } catch (e) {
        debugPrint('Erreur checkSecretBadges (non bloquante): $e');
      }
      // Badges de flow : attribution silencieuse (une lecture du jour peut
      // prolonger le streak) — pas de dialogue dédié ici.
      try {
        await FlowService().checkAndAwardFlowBadges();
      } catch (e) {
        debugPrint('Erreur checkAndAwardFlowBadges (non bloquante): $e');
      }

      if (!mounted) return;
      for (final badge in [...newBadges, ...newSecretBadges]) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => BadgeUnlockedDialog(badge: badge),
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.addPastSessionSaved)),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      debugPrint('Erreur enregistrement lecture passée: $e');
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = l.watchCatchupError;
      });
    }
  }

  InputDecoration _fieldDecoration(String label, AppThemeColors colors) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: colors.textSecondary, fontSize: 13),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      isDense: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final colors = context.appColors;
    final materialL10n = MaterialLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l.addPastSessionTitle)),
      body: ConstrainedContent(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Livre
              Row(
                children: [
                  CachedBookCover(
                    imageUrl: widget.book.coverUrl,
                    title: widget.book.title,
                    author: widget.book.author,
                    width: 50,
                    height: 70,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.book.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        if (widget.book.author != null)
                          Text(
                            widget.book.author!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: colors.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              if (_hasActiveSessionOnBook) ...[
                _infoBanner(
                  l.addPastSessionActiveSessionError,
                  Icons.timer_outlined,
                  AppColors.error,
                ),
                const SizedBox(height: 16),
              ],

              // Pages
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const Key('past_session_start_page'),
                      controller: _startController,
                      enabled: !_saving,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly
                      ],
                      style: TextStyle(color: colors.textPrimary),
                      onChanged: (_) => setState(() {}),
                      decoration:
                          _fieldDecoration(l.watchCatchupStartPage, colors),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      key: const Key('past_session_end_page'),
                      controller: _endController,
                      enabled: !_saving,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly
                      ],
                      style: TextStyle(color: colors.textPrimary),
                      onChanged: (_) => setState(() {}),
                      decoration:
                          _fieldDecoration(l.watchCatchupEndPage, colors),
                    ),
                  ),
                ],
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _saving ? null : _scanEndPage,
                  icon: const Icon(Icons.camera_alt_outlined, size: 18),
                  label: Text(l.watchCatchupScan),
                  style: TextButton.styleFrom(foregroundColor: colors.primary),
                ),
              ),
              const SizedBox(height: 16),

              // Durée
              Text(
                l.addPastSessionDuration,
                style: TextStyle(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (final m in _durationChips)
                    ChoiceChip(
                      label: Text('$m min'),
                      selected: _selectedChip == m,
                      onSelected: _saving
                          ? null
                          : (selected) => setState(() {
                                _selectedChip = selected ? m : null;
                                if (selected) _durationController.clear();
                              }),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                key: const Key('past_session_duration'),
                controller: _durationController,
                enabled: !_saving,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: TextStyle(color: colors.textPrimary),
                onChanged: (_) => setState(() => _selectedChip = null),
                decoration:
                    _fieldDecoration(l.addPastSessionCustomDuration, colors),
              ),
              const SizedBox(height: 16),

              // Date + heure de fin
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _saving ? null : _pickDate,
                      icon: const Icon(Icons.calendar_today_outlined,
                          size: 18),
                      label: Text(
                        _isToday
                            ? l.addPastSessionToday
                            : materialL10n.formatMediumDate(_date),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _saving ? null : _pickTime,
                      icon: const Icon(Icons.schedule_outlined, size: 18),
                      label: Text(_endTimeOfDay.format(context)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              if (!_isToday) ...[
                _infoBanner(
                  l.addPastSessionBackdatedInfo,
                  Icons.local_fire_department_outlined,
                  colors.textSecondary,
                ),
                const SizedBox(height: 12),
              ] else if (_tooShortForFlow) ...[
                _infoBanner(
                  l.addPastSessionTooShortWarning,
                  Icons.local_fire_department_outlined,
                  colors.textSecondary,
                ),
                const SizedBox(height: 12),
              ],

              if (_error != null) ...[
                Text(
                  _error!,
                  style:
                      const TextStyle(color: AppColors.error, fontSize: 13),
                ),
                const SizedBox(height: 12),
              ],

              ElevatedButton(
                onPressed: _saving || _hasActiveSessionOnBook ? null : _save,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                  backgroundColor: colors.primary,
                  foregroundColor: Colors.white,
                ),
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(l.addPastSessionSave),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoBanner(String text, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: color, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
