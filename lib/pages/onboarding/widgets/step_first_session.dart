import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import '../../../models/book.dart';

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
    return Padding(
      padding: const EdgeInsets.all(AppSpace.l),
      child: Column(
        children: [
          const Spacer(),
          if (selectedBook?.coverUrl != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.m),
              child: Image.network(
                selectedBook!.coverUrl!,
                width: 140,
                height: 210,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _buildPlaceholder(),
              ),
            )
          else
            _buildPlaceholder(),
          const SizedBox(height: AppSpace.l),
          if (selectedBook != null) ...[
            Text(
              selectedBook!.title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                  ),
            ),
            if (selectedBook!.author != null) ...[
              const SizedBox(height: AppSpace.xs),
              Text(
                selectedBook!.author!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, color: Colors.black54),
              ),
            ],
          ],
          const SizedBox(height: AppSpace.l),
          const Text(
            'Prêt à lire ?',
            style: TextStyle(
              fontSize: 18,
              color: Colors.black87,
              fontWeight: FontWeight.w500,
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
              label: const Text(
                'Lire',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(height: AppSpace.m),
          TextButton(
            onPressed: onSkip,
            child: const Text(
              'Plus tard',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      width: 140,
      height: 210,
      decoration: BoxDecoration(
        color: Colors.grey.shade300,
        borderRadius: BorderRadius.circular(AppRadius.m),
      ),
      child: const Center(
        child: Icon(Icons.book, color: Colors.grey, size: 48),
      ),
    );
  }
}
