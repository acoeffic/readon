// lib/widgets/active_session_dialog.dart
// Dialog pour reprendre ou abandonner une session en cours

import 'package:flutter/material.dart';
import '../models/reading_session.dart';

class ActiveSessionDialog extends StatelessWidget {
  final ReadingSession activeSession;
  final VoidCallback onResume;
  final VoidCallback onCancel;

  const ActiveSessionDialog({
    super.key,
    required this.activeSession,
    required this.onResume,
    required this.onCancel,
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
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      title: Row(
        children: [
          Icon(Icons.info_outline, color: Colors.orange.shade700),
          const SizedBox(width: 12),
          const Text('Session en cours'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Une session de lecture est déjà en cours pour ce livre.',
            style: TextStyle(fontSize: 14),
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
                      'Page ${activeSession.startPage}',
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
          const SizedBox(height: 16),
          const Text(
            'Que voulez-vous faire ?',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            onCancel();
          },
          child: Text(
            'Abandonner',
            style: TextStyle(color: Colors.red.shade700),
          ),
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
          child: const Text('Reprendre'),
        ),
      ],
    );
  }
}