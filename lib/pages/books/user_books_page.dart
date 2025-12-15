import 'package:flutter/material.dart';
import '../../services/kindle_api_service.dart';

class UserBooksPage extends StatefulWidget {
  const UserBooksPage({super.key});

  @override
  State<UserBooksPage> createState() => _UserBooksPageState();
}

class _UserBooksPageState extends State<UserBooksPage> {
  final KindleApiService _apiService = KindleApiService();
  List<Book> _kindleBooks = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadKindleBooks();
  }

  Future<void> _loadKindleBooks() async {
    setState(() => _isLoading = true);
    
    final books = await _apiService.getBooks();
    
    setState(() {
      _kindleBooks = books;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ma Bibliothèque'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadKindleBooks,
            tooltip: 'Rafraîchir les livres Kindle',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _kindleBooks.isEmpty
              ? _buildEmptyState()
              : _buildBooksList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.book, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text('Aucun livre Kindle synchronisé'),
          const SizedBox(height: 8),
          const Text(
            'Utilisez l\'extension Chrome pour synchroniser',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildBooksList() {
    return ListView.builder(
      itemCount: _kindleBooks.length,
      itemBuilder: (context, index) {
        final book = _kindleBooks[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ListTile(
            leading: book.cover.isNotEmpty
                ? Image.network(book.cover, width: 50, fit: BoxFit.cover)
                : const Icon(Icons.book, size: 50),
            title: Text(book.title, maxLines: 2, overflow: TextOverflow.ellipsis),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(book.author),
                if (book.highlightCount > 0)
                  Text(
                    '${book.highlightCount} highlights',
                    style: TextStyle(color: Theme.of(context).primaryColor),
                  ),
              ],
            ),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              // Navigation vers les détails du livre
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => BookDetailPage(book: book),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

// Page de détails
class BookDetailPage extends StatelessWidget {
  final Book book;

  const BookDetailPage({super.key, required this.book});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(book.title)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover et infos
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (book.cover.isNotEmpty)
                  Image.network(book.cover, height: 200),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        book.title,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(book.author),
                      const SizedBox(height: 16),
                      Text('${book.highlightCount} highlights'),
                    ],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),
            
            // Highlights
            const Text(
              'Highlights',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            
            ...book.highlights.map((highlight) => Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          highlight.text,
                          style: const TextStyle(fontStyle: FontStyle.italic),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          highlight.location,
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        if (highlight.note != null) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text('Note: ${highlight.note}'),
                          ),
                        ],
                      ],
                    ),
                  ),
                )),
          ],
        ),
      ),
    );
  }
}