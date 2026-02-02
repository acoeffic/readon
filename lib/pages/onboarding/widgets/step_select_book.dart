import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import '../../../models/book.dart';

class StepSelectBook extends StatelessWidget {
  final List<Book> books;
  final Book? selectedBook;
  final ValueChanged<Book> onSelected;
  final VoidCallback onNext;
  final VoidCallback onSkip;

  const StepSelectBook({
    super.key,
    required this.books,
    required this.selectedBook,
    required this.onSelected,
    required this.onNext,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    if (books.isEmpty) {
      return _buildEmptyState(context);
    }
    return _buildBookList(context);
  }

  Widget _buildBookList(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpace.l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppSpace.l),
          Text(
            'Que lis-tu en ce moment ?',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                ),
          ),
          const SizedBox(height: AppSpace.s),
          const Text(
            'Sélectionne ton livre en cours',
            style: TextStyle(fontSize: 15, color: Colors.black54),
          ),
          const SizedBox(height: AppSpace.l),
          Expanded(
            child: ListView.builder(
              itemCount: books.length,
              itemBuilder: (context, index) {
                final book = books[index];
                final isSelected = selectedBook?.id == book.id;
                return GestureDetector(
                  onTap: () => onSelected(book),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(bottom: AppSpace.s),
                    padding: const EdgeInsets.all(AppSpace.m),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primary.withValues(alpha: 0.1)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(AppRadius.m),
                      border: Border.all(
                        color:
                            isSelected ? AppColors.primary : AppColors.border,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius:
                              BorderRadius.circular(AppRadius.s),
                          child: book.coverUrl != null
                              ? Image.network(
                                  book.coverUrl!,
                                  width: 45,
                                  height: 65,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      _placeholderCover(),
                                )
                              : _placeholderCover(),
                        ),
                        const SizedBox(width: AppSpace.m),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                book.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                  color: Colors.black,
                                ),
                              ),
                              if (book.author != null)
                                Text(
                                  book.author!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.black54,
                                    fontSize: 13,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (isSelected)
                          const Icon(Icons.check_circle,
                              color: AppColors.primary, size: 24),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: selectedBook != null
                    ? AppColors.primary
                    : Colors.grey.shade400,
                foregroundColor: AppColors.white,
                padding: const EdgeInsets.symmetric(vertical: AppSpace.m),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
              ),
              onPressed: selectedBook != null ? onNext : null,
              child: const Text(
                'Suivant',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(height: AppSpace.s),
          Center(
            child: TextButton(
              onPressed: onSkip,
              child: const Text(
                'Passer',
                style:
                    TextStyle(color: AppColors.textSecondary, fontSize: 15),
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
            'Pas encore de livres',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                ),
          ),
          const SizedBox(height: AppSpace.s),
          const Text(
            'Tu pourras en ajouter depuis\nta bibliothèque.',
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
              onPressed: onSkip,
              child: const Text(
                'Terminer',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholderCover() {
    return Container(
      width: 45,
      height: 65,
      color: Colors.grey.shade300,
      child: const Center(
        child: Icon(Icons.book, color: Colors.grey, size: 22),
      ),
    );
  }
}
