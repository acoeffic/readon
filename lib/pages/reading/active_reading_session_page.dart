// lib/pages/reading/active_reading_session_page.dart

import 'package:flutter/material.dart';
import 'dart:async';
import '../../models/reading_session.dart';
import '../../models/book.dart';
import '../../navigation/main_navigation.dart';
import 'end_reading_session_page.dart';
import 'reading_session_summary_page.dart';
import '../../theme/app_theme.dart';
import '../../widgets/cached_book_cover.dart';

class ActiveReadingSessionPage extends StatefulWidget {
  final ReadingSession activeSession;
  final Book book;

  const ActiveReadingSessionPage({
    super.key,
    required this.activeSession,
    required this.book,
  });

  @override
  State<ActiveReadingSessionPage> createState() => _ActiveReadingSessionPageState();
}

class _ActiveReadingSessionPageState extends State<ActiveReadingSessionPage> {
  Timer? _timer;
  Duration _elapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    // Debug pour comprendre le problème du chronomètre
    final now = DateTime.now();
    final startTime = widget.activeSession.startTime;
    debugPrint('DEBUG ActiveReadingSession - DateTime.now(): $now');
    debugPrint('DEBUG ActiveReadingSession - startTime: $startTime');
    debugPrint('DEBUG ActiveReadingSession - startTime.isUtc: ${startTime.isUtc}');
    debugPrint('DEBUG ActiveReadingSession - difference: ${now.difference(startTime)}');

    // Calculer immédiatement le temps écoulé pour ne pas commencer à 0
    _elapsed = now.difference(startTime);
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _elapsed = DateTime.now().difference(widget.activeSession.startTime);
      });
    });
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;

    return '${hours.toString().padLeft(2, '0')}h${minutes.toString().padLeft(2, '0')}min${seconds.toString().padLeft(2, '0')}s';
  }

  Future<void> _endSession() async {
  final completedSession = await Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => EndReadingSessionPage(
        activeSession: widget.activeSession,
      ),
    ),
  );

  if (!mounted) return;
  
  // Si la session est complétée, aller à la page résumé
  if (completedSession != null) {
    await Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => ReadingSessionSummaryPage(
          session: completedSession,
        ),
      ),
    );
  } else {
    // Session annulée, retour en arrière
    Navigator.of(context).pop();
  }
}

  Future<void> _cancelSession() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Abandonner la session'),
        content: const Text('Voulez-vous vraiment abandonner cette session de lecture ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Non'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Oui', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      // TODO: Supprimer la session de la base de données
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const MainNavigation()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Quitter la session'),
            content: const Text('La session reste active. Vous pourrez la terminer plus tard.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Rester'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Quitter'),
              ),
            ],
          ),
        );
        if (confirm == true && context.mounted) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Lecture en cours'),
          backgroundColor: AppColors.primary,
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                // Infos du livre
                Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        CachedBookCover(
                          imageUrl: widget.book.coverUrl,
                          width: 60,
                          height: 90,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.book.title,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (widget.book.author != null) ...[
                                const SizedBox(height: 4),
                                Text(
                                  widget.book.author!,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 40),
                
                // Chronomètre
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Temps de lecture',
                          style: TextStyle(
                            fontSize: 20,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 30),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _formatDuration(_elapsed),
                            style: TextStyle(
                              fontSize: 64,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary.withValues(alpha: 0.9),
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 24),
                        
                        Text(
                          'Page de départ: ${widget.activeSession.startPage}',
                          style: TextStyle(
                            fontSize: 18,
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 40),
                
                // Boutons d'action
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _endSession,
                      icon: const Icon(Icons.stop, size: 28),
                      label: const Text(
                        'Terminer la session',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.all(20),
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    
                    const SizedBox(height: 12),
                    
                    OutlinedButton.icon(
                      onPressed: _cancelSession,
                      icon: const Icon(Icons.cancel_outlined),
                      label: const Text('Abandonner'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.all(16),
                        foregroundColor: Colors.red,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}