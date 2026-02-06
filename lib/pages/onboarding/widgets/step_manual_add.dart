import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';
import '../../../models/book.dart';
import '../../../services/books_service.dart';
import '../../../services/google_books_service.dart';
import '../../books/scan_book_cover_page.dart';
import '../../../widgets/cached_book_cover.dart';

class StepManualAdd extends StatefulWidget {
  final ValueChanged<Book> onBookAdded;
  final VoidCallback onNext;
  final VoidCallback onSkip;
  final List<Book> addedBooks;

  const StepManualAdd({
    super.key,
    required this.onBookAdded,
    required this.onNext,
    required this.onSkip,
    required this.addedBooks,
  });

  @override
  State<StepManualAdd> createState() => _StepManualAddState();
}

class _StepManualAddState extends State<StepManualAdd> {
  final _searchController = TextEditingController();
  final _googleBooksService = GoogleBooksService();
  final _booksService = BooksService();

  List<GoogleBook> _searchResults = [];
  bool _searching = false;
  bool _adding = false;

  Future<void> _search() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() => _searching = true);
    try {
      final results = await _googleBooksService.searchBooks(query);
      if (mounted) {
        setState(() {
          _searchResults = results;
          _searching = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _openScanner() async {
    final googleBook = await Navigator.push<GoogleBook>(
      context,
      MaterialPageRoute(builder: (_) => const ScanBookCoverPage()),
    );
    if (googleBook != null && mounted) {
      await _addBook(googleBook);
    }
  }

  Future<void> _addBook(GoogleBook googleBook) async {
    if (_adding) return;
    setState(() => _adding = true);
    try {
      final book = await _booksService.addBookFromGoogleBooks(googleBook);
      if (mounted) {
        widget.onBookAdded(book);
        setState(() {
          _searchResults.clear();
          _searchController.clear();
          _adding = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _adding = false);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpace.l),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppSpace.l),
          Text(
            'Ajoute tes livres',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                ),
          ),
          const SizedBox(height: AppSpace.s),
          const Text(
            'Scanne ou recherche un livre',
            style: TextStyle(fontSize: 15, color: Colors.black54),
          ),
          const SizedBox(height: AppSpace.l),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
                padding: const EdgeInsets.symmetric(vertical: AppSpace.m),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.l),
                ),
              ),
              onPressed: _openScanner,
              icon: const Icon(Icons.camera_alt_outlined, size: 20),
              label: const Text(
                'Scanner un livre',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(height: AppSpace.l),
          const Text(
            'Ou recherche par titre',
            style: TextStyle(fontSize: 14, color: Colors.black45),
          ),
          const SizedBox(height: AppSpace.s),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    hintText: 'Titre ou auteur...',
                    hintStyle: TextStyle(color: Colors.grey),
                  ),
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _search(),
                ),
              ),
              const SizedBox(width: AppSpace.s),
              IconButton(
                onPressed: _searching ? null : _search,
                icon: const Icon(Icons.search, color: AppColors.primary),
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.accentLight,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.m),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.m),
          if (_searching)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(AppSpace.l),
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            ),
          if (_searchResults.isNotEmpty)
            Expanded(
              child: ListView.builder(
                itemCount: _searchResults.length,
                itemBuilder: (context, index) {
                  final gb = _searchResults[index];
                  return _SearchResultTile(
                    googleBook: gb,
                    adding: _adding,
                    onAdd: () => _addBook(gb),
                  );
                },
              ),
            )
          else if (!_searching && widget.addedBooks.isNotEmpty)
            Expanded(child: _buildAddedBooks())
          else
            const Spacer(),
          if (widget.addedBooks.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpace.s),
              child: Text(
                '${widget.addedBooks.length} livre${widget.addedBooks.length > 1 ? 's' : ''} ajouté${widget.addedBooks.length > 1 ? 's' : ''}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.addedBooks.isNotEmpty
                    ? AppColors.primary
                    : Colors.grey.shade400,
                foregroundColor: AppColors.white,
                padding: const EdgeInsets.symmetric(vertical: AppSpace.m),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
              ),
              onPressed:
                  widget.addedBooks.isNotEmpty ? widget.onNext : null,
              child: const Text(
                'Suivant',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(height: AppSpace.s),
          Center(
            child: TextButton(
              onPressed: widget.onSkip,
              child: const Text(
                'Passer cette étape',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 15),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddedBooks() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Livres ajoutés',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: AppSpace.s),
        Expanded(
          child: ListView.builder(
            itemCount: widget.addedBooks.length,
            itemBuilder: (context, index) {
              final book = widget.addedBooks[index];
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CachedBookCover(
                  imageUrl: book.coverUrl,
                  width: 40,
                  height: 60,
                  borderRadius: BorderRadius.circular(AppRadius.s),
                ),
                title: Text(
                  book.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
                subtitle: Text(
                  book.author ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.black54),
                ),
                trailing:
                    const Icon(Icons.check_circle, color: AppColors.primary),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _SearchResultTile extends StatelessWidget {
  final GoogleBook googleBook;
  final bool adding;
  final VoidCallback onAdd;

  const _SearchResultTile({
    required this.googleBook,
    required this.adding,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: AppSpace.xs),
      leading: CachedBookCover(
        imageUrl: googleBook.coverUrl,
        width: 40,
        height: 60,
        borderRadius: BorderRadius.circular(AppRadius.s),
      ),
      title: Text(
        googleBook.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.black),
      ),
      subtitle: Text(
        googleBook.authors.join(', '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: Colors.black54),
      ),
      trailing: IconButton(
        onPressed: adding ? null : onAdd,
        icon: adding
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.add_circle_outline, color: AppColors.primary),
      ),
    );
  }
}
