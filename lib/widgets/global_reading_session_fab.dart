// lib/widgets/global_reading_session_fab.dart - VERSION FINALE

import 'package:flutter/material.dart';
import '../services/kindle_api_service.dart' as kindle;
import '../services/books_service.dart';
import '../services/reading_session_service.dart';
import '../pages/reading/start_reading_session_page_unified.dart';
import '../pages/reading/active_reading_session_page.dart';
import '../pages/books/scan_book_cover_page.dart';
import '../services/google_books_service.dart';
import '../models/book.dart';
import 'active_session_dialog.dart';
import '../models/book.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final _supabase = Supabase.instance.client;

/// FloatingActionButton global pour démarrer une session de lecture
class GlobalReadingSessionFAB extends StatelessWidget {
  const GlobalReadingSessionFAB({super.key});

  Future<void> _showBookSourceChoice(BuildContext context) async {
    // 🔍 VÉRIFIER S'IL Y A UNE SESSION EN COURS
    final sessionService = ReadingSessionService();
    
    try {
      final activeSessions = await sessionService.getAllActiveSessions();
      
      if (!context.mounted) return;
      
      if (activeSessions.isNotEmpty) {
        // Il y a une session en cours - afficher le dialog
        final activeSession = activeSessions.first;
        
        // Charger le livre associé
        final booksService = BooksService();
        Book? book;
        try {
          book = await booksService.getBookById(int.parse(activeSession.bookId));
        } catch (e) {
          print('Erreur chargement livre: $e');
        }
        
        if (!context.mounted) return;
        
        showDialog(
          context: context,
          builder: (context) => ActiveSessionDialog(
            activeSession: activeSession,
            onResume: () async {
  // Reprendre la session - récupérer les infos du livre d'abord
  try {
    final bookId = activeSession.bookId;
    final bookData = await _supabase
        .from('books')
        .select()
        .eq('id', int.parse(bookId))
        .single();
    
    final book = Book.fromJson(bookData);
    
    if (context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ActiveReadingSessionPage(
            activeSession: activeSession,
            book: book,
          ),
        ),
      );
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
      );
    }
  }
},
            onCancel: () async {
              // Abandonner la session
              try {
                await sessionService.cancelSession(activeSession.id.toString());
                
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Session abandonnée'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  
                  // Continuer avec le choix de livre
                  _showBookSourceChoice(context);
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Erreur: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
          ),
        );
        return; // Sortir de la fonction
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur vérification session: $e'), backgroundColor: Colors.red),
        );
      }
      return;
    }
    
    // ✅ Pas de session en cours - continuer normalement
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Démarrer une session de lecture',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            
            // Option 1: Scanner une couverture
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.deepPurple.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.camera_alt, color: Colors.deepPurple, size: 28),
              ),
              title: const Text(
                'Livre physique',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: const Text('Scanner la couverture'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () => Navigator.pop(context, 'scan'),
            ),
            
            const SizedBox(height: 12),
            
            // Option 2: Livres Kindle
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.library_books, color: Colors.orange, size: 28),
              ),
              title: const Text(
                'Livres Kindle',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: const Text('De votre bibliothèque'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () => Navigator.pop(context, 'kindle'),
            ),
            
            // Option 3: Ma bibliothèque (tous les livres)
            const SizedBox(height: 12),
            
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.book, color: Colors.green, size: 28),
              ),
              title: const Text(
                'Ma bibliothèque',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: const Text('Tous mes livres'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () => Navigator.pop(context, 'library'),
            ),
            
            const SizedBox(height: 12),
          ],
        ),
      ),
    );

    if (choice == null || !context.mounted) return;

    if (choice == 'scan') {
      await _scanAndStartSession(context);
    } else if (choice == 'kindle') {
      await _selectKindleBookAndStart(context);
    } else if (choice == 'library') {
      await _selectFromLibraryAndStart(context);
    }
  }

  Future<void> _scanAndStartSession(BuildContext context) async {
    // 1. Scanner la couverture
    final GoogleBook? googleBook = await Navigator.push<GoogleBook>(
      context,
      MaterialPageRoute(
        builder: (context) => const ScanBookCoverPage(),
      ),
    );

    if (googleBook == null || !context.mounted) return;

    // 2. Ajouter le livre à la BDD
    final booksService = BooksService();
    
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final book = await booksService.addBookFromGoogleBooks(googleBook);
      
      if (!context.mounted) return;
      Navigator.pop(context); // Fermer le loading

      // 3. Démarrer la session de lecture
      await _startSession(context, book);
      
    } catch (e) {
      if (!context.mounted) return;
      Navigator.pop(context);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _selectKindleBookAndStart(BuildContext context) async {
    final apiService = kindle.KindleApiService();
    final books = await apiService.getBooks();
    
    if (!context.mounted) return;
    
    if (books.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Aucun livre Kindle. Synchronisez vos livres d\'abord.'),
        ),
      );
      return;
    }
    
    final selectedKindleBook = await showModalBottomSheet<Book>(
      context: context,
      builder: (context) => _BookSelectorSheet(
        books: books,
        title: 'Livres Kindle',
      ),
    );
    
    if (selectedKindleBook == null || !context.mounted) return;
    
    // Convertir en Book unifié et démarrer
    // TODO: Adapter pour convertir le Book Kindle en Book Supabase
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Fonctionnalité en cours de développement')),
    );
  }

  Future<void> _selectFromLibraryAndStart(BuildContext context) async {
    final booksService = BooksService();
    
    try {
      final allBooks = await booksService.getUserBooks();
      
      if (!context.mounted) return;
      
      if (allBooks.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Votre bibliothèque est vide')),
        );
        return;
      }
      
      final selectedBook = await showModalBottomSheet<Book>(
        context: context,
        builder: (context) => _UnifiedBookSelectorSheet(books: allBooks),
      );
      
      if (selectedBook != null && context.mounted) {
        await _startSession(context, selectedBook);
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _startSession(BuildContext context, Book book) async {
    // Naviguer vers StartReadingSessionPage qui prend la photo de début
    final session = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StartReadingSessionPageUnified(book: book),
      ),
    );

    if (session != null && context.mounted) {
      // Session créée, naviguer vers la page de chronomètre
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ActiveReadingSessionPage(
            activeSession: session,
            book: book,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      onPressed: () => _showBookSourceChoice(context),
      backgroundColor: Theme.of(context).primaryColor,
      child: const Icon(Icons.menu_book),
      tooltip: 'Démarrer une session',
    );
  }
}

/// Bottom sheet pour sélectionner un livre (Books unifiés)
class _UnifiedBookSelectorSheet extends StatefulWidget {
  final List<Book> books;

  const _UnifiedBookSelectorSheet({required this.books});

  @override
  State<_UnifiedBookSelectorSheet> createState() => _UnifiedBookSelectorSheetState();
}

class _UnifiedBookSelectorSheetState extends State<_UnifiedBookSelectorSheet> {
  String _searchQuery = '';

  List<Book> get _filteredBooks {
    if (_searchQuery.isEmpty) return widget.books;
    return widget.books.where((book) {
      return book.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
             (book.author?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              const Text('Ma bibliothèque', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const Spacer(),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            decoration: InputDecoration(
              hintText: 'Rechercher...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onChanged: (value) => setState(() => _searchQuery = value),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _filteredBooks.isEmpty
                ? const Center(child: Text('Aucun livre trouvé'))
                : ListView.builder(
                    itemCount: _filteredBooks.length,
                    itemBuilder: (context, index) {
                      final book = _filteredBooks[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: book.coverUrl != null && book.coverUrl!.isNotEmpty
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: Image.network(book.coverUrl!, width: 40, height: 60, fit: BoxFit.cover),
                                )
                              : const Icon(Icons.book, size: 40),
                          title: Text(book.title, maxLines: 2, overflow: TextOverflow.ellipsis),
                          subtitle: book.author != null ? Text(book.author!, maxLines: 1, overflow: TextOverflow.ellipsis) : null,
                          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                          onTap: () => Navigator.pop(context, book),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// Bottom sheet pour Kindle books (ancien format)
class _BookSelectorSheet extends StatelessWidget {
  final List<dynamic> books;
  final String title;

  const _BookSelectorSheet({required this.books, required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const Spacer(),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: books.length,
              itemBuilder: (context, index) {
                final book = books[index];
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.book),
                    title: Text(book.title ?? 'Sans titre'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () => Navigator.pop(context, book),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}