// lib/widgets/abandon_session_sheet.dart
//
// Feuille de confirmation d'abandon d'une session de lecture.
//
// `ReadingSessionService.cancelSession()` fait un DELETE : le temps déjà lu est
// détruit, définitivement. Jusqu'ici ça se jouait derrière un « Voulez-vous
// vraiment ? » générique qui ne disait ni combien de temps était en jeu, ni
// qu'il existait une sortie qui le préserve. Cette feuille dit les deux.

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/reading_session.dart';
import '../services/session_pause_service.dart';
import '../theme/app_theme.dart';

enum AbandonSessionChoice {
  /// Ne rien faire, retourner à la lecture.
  keepReading,

  /// Aller à l'écran de fin de session : le temps est conservé.
  endSession,

  /// Supprimer la session et le temps avec.
  discard,
}

/// Formate une durée pour l'affichage : « 42 min », « 1 h 20 ».
String formatSessionDuration(Duration d) {
  final hours = d.inHours;
  final minutes = d.inMinutes % 60;
  if (hours > 0) return '$hours h ${minutes.toString().padLeft(2, '0')}';
  return '$minutes min';
}

/// Durée réellement lue : temps écoulé moins le cumul des pauses.
Future<Duration> effectiveSessionDuration(ReadingSession session) async {
  final pause = await SessionPauseService().getTotalPauseDuration();
  final elapsed = DateTime.now().difference(session.startTime) - pause;
  return elapsed.isNegative ? Duration.zero : elapsed;
}

Future<AbandonSessionChoice?> showAbandonSessionSheet(
  BuildContext context, {
  required ReadingSession session,
}) async {
  // Calculé avant l'ouverture : la feuille ne doit pas afficher un état de
  // chargement là où l'utilisateur attend une décision immédiate.
  final duration = await effectiveSessionDuration(session);
  if (!context.mounted) return null;

  return showModalBottomSheet<AbandonSessionChoice>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) =>
        _AbandonSessionSheet(duration: duration),
  );
}

class _AbandonSessionSheet extends StatelessWidget {
  final Duration duration;

  const _AbandonSessionSheet({required this.duration});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                l.abandonSessionTitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                l.abandonSessionElapsed(formatSessionDuration(duration)),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 15),
              ),
              const SizedBox(height: 6),
              Text(
                l.abandonDeletesTime,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.red.shade400,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 22),

              // Action par défaut : ne rien casser.
              FilledButton(
                onPressed: () => Navigator.pop(
                  context,
                  AbandonSessionChoice.keepReading,
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  l.abandonKeepReading,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // La sortie qui préserve le temps : c'est elle que la plupart
              // des gens veulent quand ils appuient sur « Abandonner ».
              OutlinedButton(
                onPressed: () => Navigator.pop(
                  context,
                  AbandonSessionChoice.endSession,
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  l.abandonEndInstead,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 6),

              TextButton(
                onPressed: () => Navigator.pop(
                  context,
                  AbandonSessionChoice.discard,
                ),
                child: Text(
                  l.abandonDiscard,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.red.shade400,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
