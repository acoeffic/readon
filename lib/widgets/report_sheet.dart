// lib/widgets/report_sheet.dart
//
// Bottom sheet réutilisable pour signaler du contenu ou un utilisateur.
// L'appelant fournit le type de cible, l'ID et (optionnellement) l'ID de
// l'auteur du contenu. Le sheet gère la sélection de raison, l'envoi via
// ModerationService et l'affichage du feedback.
//
// Usage :
//   await showReportSheet(
//     context,
//     targetType: ReportTargetType.comment,
//     targetId: '$commentId',
//     targetUserId: comment.authorId,
//   );

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/moderation_service.dart';
import '../theme/app_theme.dart';

Future<void> showReportSheet(
  BuildContext context, {
  required ReportTargetType targetType,
  required String targetId,
  String? targetUserId,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => _ReportSheet(
      targetType: targetType,
      targetId: targetId,
      targetUserId: targetUserId,
    ),
  );
}

class _ReportSheet extends StatefulWidget {
  final ReportTargetType targetType;
  final String targetId;
  final String? targetUserId;

  const _ReportSheet({
    required this.targetType,
    required this.targetId,
    this.targetUserId,
  });

  @override
  State<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<_ReportSheet> {
  ReportReason? _selected;
  final _detailsController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  String _reasonLabel(BuildContext context, ReportReason r) {
    final l = AppLocalizations.of(context);
    switch (r) {
      case ReportReason.spam:
        return l.reportReasonSpam;
      case ReportReason.harassment:
        return l.reportReasonHarassment;
      case ReportReason.hateSpeech:
        return l.reportReasonHateSpeech;
      case ReportReason.sexualContent:
        return l.reportReasonSexualContent;
      case ReportReason.violence:
        return l.reportReasonViolence;
      case ReportReason.selfHarm:
        return l.reportReasonSelfHarm;
      case ReportReason.misinformation:
        return l.reportReasonMisinformation;
      case ReportReason.impersonation:
        return l.reportReasonImpersonation;
      case ReportReason.illegal:
        return l.reportReasonIllegal;
      case ReportReason.other:
        return l.reportReasonOther;
    }
  }

  Future<void> _submit() async {
    if (_selected == null || _submitting) return;
    setState(() => _submitting = true);

    final result = await ModerationService().reportContent(
      targetType: widget.targetType,
      targetId: widget.targetId,
      targetUserId: widget.targetUserId,
      reason: _selected!,
      details: _detailsController.text,
    );

    if (!mounted) return;
    final l = AppLocalizations.of(context);
    Navigator.of(context).pop();

    final msg = switch (result) {
      ReportResult.success => l.reportSubmittedMessage,
      ReportResult.alreadyReported => l.reportAlreadySubmittedMessage,
      ReportResult.notAuthenticated => l.reportNotAuthenticatedMessage,
      ReportResult.error => l.reportErrorMessage,
    };
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: result == ReportResult.success
            ? AppColors.primary
            : Colors.red.shade700,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final viewInsets = MediaQuery.of(context).viewInsets;

    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets.bottom),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).dividerColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                l.reportSheetTitle,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                l.reportSheetSubtitle,
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 16),
              ...ReportReason.values.map((r) {
                final selected = _selected == r;
                return InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: _submitting ? null : () => setState(() => _selected = r),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    margin: const EdgeInsets.only(bottom: 6),
                    decoration: BoxDecoration(
                      color: selected
                          ? AppColors.primary.withValues(alpha: 0.08)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: selected
                            ? AppColors.primary
                            : Theme.of(context).dividerColor,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          selected
                              ? Icons.radio_button_checked
                              : Icons.radio_button_off,
                          color: selected
                              ? AppColors.primary
                              : Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.4),
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _reasonLabel(context, r),
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
              const SizedBox(height: 12),
              TextField(
                controller: _detailsController,
                enabled: !_submitting,
                maxLines: 3,
                maxLength: 500,
                decoration: InputDecoration(
                  labelText: l.reportDetailsLabel,
                  hintText: l.reportDetailsHint,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed:
                      _selected == null || _submitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade700,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _submitting
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(Colors.white),
                          ),
                        )
                      : Text(l.reportSubmitButton),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed:
                    _submitting ? null : () => Navigator.of(context).pop(),
                child: Text(l.cancel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
