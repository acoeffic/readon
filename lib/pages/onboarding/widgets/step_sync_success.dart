import 'dart:math';
import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import '../../../models/book.dart';

class StepSyncSuccess extends StatelessWidget {
  final int bookCount;
  final List<Book> books;
  final VoidCallback onNext;

  const StepSyncSuccess({
    super.key,
    required this.bookCount,
    required this.books,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    if (bookCount == 0) {
      return _buildEmptyState(context);
    }
    return _buildSuccessState(context);
  }

  Widget _buildSuccessState(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpace.l),
      child: Column(
        children: [
          const Spacer(),
          Container(
            width: 80,
            height: 80,
            decoration: const BoxDecoration(
              color: AppColors.accentLight,
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Icon(
                Icons.check_rounded,
                color: AppColors.primary,
                size: 48,
              ),
            ),
          ),
          const SizedBox(height: AppSpace.l),
          Text(
            '$bookCount livres synchronisés !',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                ),
          ),
          const SizedBox(height: 32),
          if (books.isNotEmpty)
            SizedBox(
              height: 130,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: min(books.length, 10),
                padding: EdgeInsets.zero,
                itemBuilder: (context, index) {
                  final book = books[index];
                  return Padding(
                    padding: const EdgeInsets.only(right: AppSpace.s),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.s),
                      child: book.coverUrl != null
                          ? Image.network(
                              book.coverUrl!,
                              width: 80,
                              height: 120,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  _buildPlaceholderCover(),
                            )
                          : _buildPlaceholderCover(),
                    ),
                  );
                },
              ),
            ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.white,
                padding: const EdgeInsets.symmetric(vertical: AppSpace.m),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
              ),
              onPressed: onNext,
              child: const Text(
                'Suivant',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpace.l),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(),
          Icon(Icons.library_books_outlined,
              size: 64, color: Colors.grey.shade400),
          const SizedBox(height: AppSpace.l),
          Text(
            'Aucun livre trouvé',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                ),
          ),
          const SizedBox(height: AppSpace.s),
          const Text(
            'Tu pourras en ajouter plus tard\ndepuis ta bibliothèque.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, color: Colors.black54, height: 1.4),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.white,
                padding: const EdgeInsets.symmetric(vertical: AppSpace.m),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
              ),
              onPressed: onNext,
              child: const Text(
                'Continuer',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholderCover() {
    return Container(
      width: 80,
      height: 120,
      color: Colors.grey.shade300,
      child: const Center(
        child: Icon(Icons.book, color: Colors.grey, size: 28),
      ),
    );
  }
}
