// lib/pages/reading/reading_session_summary_page.dart

import 'package:flutter/material.dart';
import '../../models/reading_session.dart';
import '../../models/trophy.dart';
import '../../widgets/trophy_card.dart';
import '../../theme/app_theme.dart';

class ReadingSessionSummaryPage extends StatelessWidget {
  final ReadingSession session;
  final Trophy? trophy;

  const ReadingSessionSummaryPage({
    super.key,
    required this.session,
    this.trophy,
  });

  String _formatDuration(int minutes) {
    if (minutes < 60) {
      return '$minutes min';
    }
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    return '${hours}h ${mins}min';
  }

  String _formatPace() {
    if (session.pagesRead == 0 || session.durationMinutes == 0) {
      return '-';
    }
    final pagesPerMinute = session.pagesRead / session.durationMinutes;
    final minutesPerPage = session.durationMinutes / session.pagesRead;
    
    if (pagesPerMinute >= 1) {
      return '${pagesPerMinute.toStringAsFixed(1)} pages/min';
    }
    return '${minutesPerPage.toStringAsFixed(1)} min/page';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Session terminée'),
        backgroundColor: Colors.green,
        automaticallyImplyLeading: false, // Pas de bouton retour
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Trophée ou icône succès par défaut
            if (trophy != null) ...[
              TrophyCard(trophy: trophy!),
            ] else ...[
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_circle,
                  size: 80,
                  color: Colors.green.shade700,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Bravo !',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Session de lecture terminée',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
            
            const SizedBox(height: 32),
            
            // Stats principales
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    icon: Icons.menu_book,
                    value: '${session.pagesRead}',
                    label: 'pages lues',
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    icon: Icons.schedule,
                    value: _formatDuration(session.durationMinutes),
                    label: 'de lecture',
                    color: Colors.orange,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    icon: Icons.speed,
                    value: _formatPace(),
                    label: 'rythme',
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    icon: Icons.bookmark,
                    value: '${session.startPage} → ${session.endPage}',
                    label: 'progression',
                    color: Colors.green,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 32),
            
            // Détails de la session
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Détails de la session',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _DetailRow(
                      icon: Icons.play_arrow,
                      label: 'Début',
                      value: 'Page ${session.startPage}',
                    ),
                    const SizedBox(height: 12),
                    _DetailRow(
                      icon: Icons.stop,
                      label: 'Fin',
                      value: 'Page ${session.endPage}',
                    ),
                    const SizedBox(height: 12),
                    _DetailRow(
                      icon: Icons.calendar_today,
                      label: 'Date',
                      value: _formatDate(session.startTime),
                    ),
                    const SizedBox(height: 12),
                    _DetailRow(
                      icon: Icons.access_time,
                      label: 'Heure',
                      value: '${_formatTime(session.startTime)} - ${_formatTime(session.endTime!)}',
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Bouton retour
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  // Retour à la page du livre (pop toutes les pages de session)
                 Navigator.of(context).pop();
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
                child: const Text(
                  'Retour au livre',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            
            const SizedBox(height: 12),
            
            // Bouton partager (optionnel future)
            /*
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  // TODO: Partager sur le feed
                },
                icon: const Icon(Icons.share),
                label: const Text('Partager ma progression'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                ),
              ),
            ),
            */
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    const months = [
      'jan', 'fév', 'mar', 'avr', 'mai', 'juin',
      'juil', 'août', 'sep', 'oct', 'nov', 'déc'
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey.shade600),
        const SizedBox(width: 12),
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade600,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}