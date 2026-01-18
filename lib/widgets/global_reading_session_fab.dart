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
import 'package:supabase_flutter/supabase_flutter.dart';

final _supabase = Supabase.instance.client;

/// FloatingActionButton global pour démarrer une session de lecture
class GlobalReadingSessionFAB extends StatelessWidget {
  const GlobalReadingSessionFAB({super.key});

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
    return _ExpandableFAB(
      onScanPressed: () => _handleScan(context),
      onKindlePressed: () => _handleKindle(context),
      onLibraryPressed: () => _handleLibrary(context),
      checkActiveSession: () => _checkActiveSession(context),
    );
  }

  Future<bool> _checkActiveSession(BuildContext context) async {
    final sessionService = ReadingSessionService();

    try {
      final activeSessions = await sessionService.getAllActiveSessions();

      if (!context.mounted) return false;

      if (activeSessions.isNotEmpty) {
        final activeSession = activeSessions.first;

        showDialog(
          context: context,
          builder: (context) => ActiveSessionDialog(
            activeSession: activeSession,
            onResume: () async {
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
              try {
                await sessionService.cancelSession(activeSession.id.toString());

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Session abandonnée'),
                      backgroundColor: Colors.orange,
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
          ),
        );
        return true; // Session active trouvée
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur vérification session: $e'), backgroundColor: Colors.red),
        );
      }
      return true; // Erreur, bloquer l'action
    }

    return false; // Pas de session active
  }

  Future<void> _handleScan(BuildContext context) async {
    if (await _checkActiveSession(context)) return;
    await _scanAndStartSession(context);
  }

  Future<void> _handleKindle(BuildContext context) async {
    if (await _checkActiveSession(context)) return;
    await _selectKindleBookAndStart(context);
  }

  Future<void> _handleLibrary(BuildContext context) async {
    if (await _checkActiveSession(context)) return;
    await _selectFromLibraryAndStart(context);
  }
}

/// FAB Expandable avec animation
class _ExpandableFAB extends StatefulWidget {
  final VoidCallback onScanPressed;
  final VoidCallback onKindlePressed;
  final VoidCallback onLibraryPressed;
  final Future<bool> Function() checkActiveSession;

  const _ExpandableFAB({
    required this.onScanPressed,
    required this.onKindlePressed,
    required this.onLibraryPressed,
    required this.checkActiveSession,
  });

  @override
  State<_ExpandableFAB> createState() => _ExpandableFABState();
}

class _ExpandableFABState extends State<_ExpandableFAB> with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  late AnimationController _animationController;
  late Animation<double> _expandAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _expandAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  void _close() {
    if (_isExpanded) {
      setState(() {
        _isExpanded = false;
        _animationController.reverse();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.bottomRight,
      children: [
        // Overlay transparent pour fermer quand on clique ailleurs
        if (_isExpanded)
          Positioned.fill(
            child: GestureDetector(
              onTap: _close,
              behavior: HitTestBehavior.opaque,
              child: const SizedBox.expand(),
            ),
          ),

        // Options du menu
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Option 1: Scanner
            _buildExpandableOption(
              index: 2,
              label: 'Ajouter un nouveau livre',
              icon: Icons.camera_alt,
              color: Colors.deepPurple,
              onTap: () {
                _close();
                widget.onScanPressed();
              },
            ),
            const SizedBox(height: 12),

            // Option 2: Kindle
            _buildExpandableOption(
              index: 1,
              label: 'Livres Kindle',
              icon: Icons.library_books,
              color: Colors.orange,
              onTap: () {
                _close();
                widget.onKindlePressed();
              },
            ),
            const SizedBox(height: 12),

            // Option 3: Bibliothèque
            _buildExpandableOption(
              index: 0,
              label: 'Ma bibliothèque',
              icon: Icons.book,
              color: Colors.green,
              onTap: () {
                _close();
                widget.onLibraryPressed();
              },
            ),
            const SizedBox(height: 16),

            // Bouton principal
            FloatingActionButton(
              onPressed: _toggle,
              backgroundColor: Theme.of(context).primaryColor,
              child: AnimatedRotation(
                turns: _isExpanded ? 0.125 : 0, // Rotation de 45 degrés
                duration: const Duration(milliseconds: 250),
                child: const Icon(Icons.add, size: 32),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildExpandableOption({
    required int index,
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    final delay = index * 0.1;

    return AnimatedBuilder(
      animation: _expandAnimation,
      builder: (context, child) {
        final progress = Curves.easeOut.transform(
          (_expandAnimation.value - delay).clamp(0.0, 1.0 - delay) / (1.0 - delay),
        );

        if (progress <= 0) return const SizedBox.shrink();

        return Opacity(
          opacity: progress,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - progress)),
            child: child,
          ),
        );
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Label avec fond blanc arrondi
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 14,
                color: Colors.black87,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Bouton circulaire coloré
          GestureDetector(
            onTap: onTap,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
          ),
        ],
      ),
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