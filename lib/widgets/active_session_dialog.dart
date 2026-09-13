// lib/widgets/active_session_dialog.dart
// Dialog pour reprendre ou abandonner une session en cours

import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../models/reading_session.dart';

class ActiveSessionDialog extends StatelessWidget {
  final ReadingSession activeSession;
  final VoidCallback onResume;
  final VoidCallback onCancel;

  /// Terminer proprement la session en cours : c'est la sortie qui conserve
  /// le temps lu, là où `onCancel` le supprime définitivement.
  final VoidCallback? onEndSession;

  const ActiveSessionDialog({
    super.key,
    required this.activeSession,
    required this.onResume,
    required this.onCancel,
    this.onEndSession,
  });

  String _formatDuration() {
    final duration = DateTime.now().difference(activeSession.startTime);
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    
    if (hours > 0) {
      return '${hours}h ${minutes}min';
    }
    return '${minutes}min';
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      title: Row(
        children: [
          Icon(Icons.info_outline, color: Colors.orange.shade700),
          const SizedBox(width: 12),
          Text(l.activeSessionDialogTitle),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.activeSessionDialogMessage,
            style: const TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.bookmark, size: 16, color: Colors.blue.shade700),
                    const SizedBox(width: 8),
                    Text(
                      l.pageAtNumber(activeSession.startPage),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.schedule, size: 16, color: Colors.blue.shade700),
                    const SizedBox(width: 8),
                    Text(
                      'Durée: ${_formatDuration()}',
                      style: TextStyle(color: Colors.blue.shade700),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Dire ce qu'on perd : le bouton « Abandonner » déclenche un DELETE.
          Text(
            l.abandonDeletesTime,
            style: TextStyle(
              fontSize: 12.5,
              color: Colors.red.shade400,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            l.whatDoYouWant,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
      actionsOverflowDirection: VerticalDirection.down,
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            onCancel();
          },
          child: Text(
            l.abandonButton,
            style: TextStyle(color: Colors.red.shade700),
          ),
        ),
        if (onEndSession != null)
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              onEndSession!();
            },
            child: Text(l.abandonEndInstead),
          ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
            onResume();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
          ),
          child: Text(l.resume),
        ),
      ],
    );
  }
}