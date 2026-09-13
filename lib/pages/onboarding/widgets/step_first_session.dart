import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import '../../../models/book.dart';
import '../../../widgets/cached_book_cover.dart';
import '../../../l10n/app_localizations.dart';

class StepFirstSession extends StatelessWidget {
  final Book? selectedBook;
  final VoidCallback onStartSession;
  final VoidCallback onSkip;

  const StepFirstSession({
    super.key,
    required this.selectedBook,
    required this.onStartSession,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    // Sans livre sélectionné (ajout sauté / import Kindle vide), on n'affiche
    // pas un CTA « Lire » trompeur qui ne lance aucune session : on présente
    // un écran de fin clair qui termine l'onboarding.
    return selectedBook == null
        ? _buildNoBook(context)
        : _buildWithBook(context);
  }

  Widget _buildWithBook(BuildContext context) {
    final book = selectedBook!;
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.all(AppSpace.l),
      child: Column(
        children: [
          const Spacer(),
          CachedBookCover(
            imageUrl: book.coverUrl,
            isbn: book.isbn,
            googleId: book.googleId,
            title: book.title,
            author: book.author,
            width: 140,
            height: 210,
            borderRadius: BorderRadius.circular(AppRadius.m),
          ),
          const SizedBox(height: AppSpace.l),
          Text(
            book.title,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                ),
          ),
          if (book.author != null) ...[
            const SizedBox(height: AppSpace.xs),
            Text(
              book.author!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, color: Colors.black54),
            ),
          ],
          const SizedBox(height: AppSpace.l),
          Text(
            l10n.onboardingFirstSessionReady,
            style: const TextStyle(
              fontSize: 18,
              color: Colors.black87,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: AppSpace.s),
          // Le diagnostic du 02/09 : 100 % des inscrits d'août qui n'ont pas
          // lancé de session ICI ne sont jamais revenus. On abaisse donc le
          // coût perçu du « oui » (5 minutes, arrêt libre) plutôt que de
          // laisser « Plus tard » à égalité avec « Lire ».
          Text(
            l10n.onboardingFirstSessionHint,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.black54,
              height: 1.4,
            ),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.white,
                padding: const EdgeInsets.symmetric(vertical: AppSpace.m),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
              ),
              onPressed: onStartSession,
              icon: const Icon(Icons.play_arrow_rounded, size: 24),
              label: Text(
                l10n.onboardingFirstSessionCta,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(height: AppSpace.s),
          TextButton(
            onPressed: onSkip,
            child: Text(
              l10n.onboardingFirstSessionLater,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoBook(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.all(AppSpace.l),
      child: Column(
        children: [
          const Spacer(),
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.auto_stories_rounded,
              size: 48,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: AppSpace.l),
          Text(
            l10n.onboardingNoBookTitle,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                ),
          ),
          const SizedBox(height: AppSpace.s),
          Text(
            l10n.onboardingNoBookBody,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.black54,
              height: 1.4,
            ),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.white,
                padding: const EdgeInsets.symmetric(vertical: AppSpace.m),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
              ),
              // onStartSession route vers _completeOnboarding quand le livre
              // est null — termine l'onboarding proprement.
              onPressed: onStartSession,
              icon: const Icon(Icons.check_rounded, size: 24),
              label: Text(
                l10n.onboardingNoBookCta,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(height: AppSpace.m),
        ],
      ),
    );
  }
}
