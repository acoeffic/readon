// lib/widgets/feedback_sheet.dart
//
// Bottom sheet pour envoyer un feedback libre (idée, bug, remarque).
// Modelé sur report_sheet.dart : le sheet gère la saisie, l'envoi via
// FeedbackService et l'affichage du résultat en snackbar.
//
// Usage :
//   await showFeedbackSheet(context);

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/feedback_service.dart';
import '../theme/app_theme.dart';

Future<void> showFeedbackSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => const _FeedbackSheet(),
  );
}

class _FeedbackSheet extends StatefulWidget {
  const _FeedbackSheet();

  @override
  State<_FeedbackSheet> createState() => _FeedbackSheetState();
}

class _FeedbackSheetState extends State<_FeedbackSheet> {
  final _messageController = TextEditingController();
  bool _submitting = false;
  bool _canSubmit = false;

  @override
  void initState() {
    super.initState();
    _messageController.addListener(() {
      final canSubmit = _messageController.text.trim().isNotEmpty;
      if (canSubmit != _canSubmit) {
        setState(() => _canSubmit = canSubmit);
      }
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_canSubmit || _submitting) return;
    setState(() => _submitting = true);

    final result = await FeedbackService().submit(_messageController.text);

    if (!mounted) return;
    final l = AppLocalizations.of(context);
    Navigator.of(context).pop();

    final msg = switch (result) {
      FeedbackResult.success => l.feedbackSentMessage,
      FeedbackResult.notAuthenticated => l.feedbackErrorMessage,
      FeedbackResult.error => l.feedbackErrorMessage,
    };
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: result == FeedbackResult.success
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
                l.feedbackSheetTitle,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                l.feedbackSheetSubtitle,
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _messageController,
                enabled: !_submitting,
                autofocus: true,
                maxLines: 5,
                maxLength: 2000,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: l.feedbackMessageLabel,
                  hintText: l.feedbackMessageHint,
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: !_canSubmit || _submitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
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
                      : Text(l.feedbackSubmitButton),
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
