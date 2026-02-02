// lib/widgets/global_reading_session_fab.dart - LIQUID GLASS DESIGN

import 'dart:ui';
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
import '../theme/app_theme.dart';

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
    if (!context.mounted) return;
    await _scanAndStartSession(context);
  }

  Future<void> _handleKindle(BuildContext context) async {
    if (await _checkActiveSession(context)) return;
    if (!context.mounted) return;
    await _selectKindleBookAndStart(context);
  }

  Future<void> _handleLibrary(BuildContext context) async {
    if (await _checkActiveSession(context)) return;
    if (!context.mounted) return;
    await _selectFromLibraryAndStart(context);
  }
}

/// FAB Expandable avec design Liquid Glass (Apple style)
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
      duration: const Duration(milliseconds: 450),
    );
    _expandAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Stack(
      alignment: Alignment.bottomRight,
      children: [
        // Overlay avec blur (sans fond grisé) pour fermer
        if (_isExpanded)
          Positioned.fill(
            child: GestureDetector(
              onTap: _close,
              behavior: HitTestBehavior.opaque,
              child: AnimatedBuilder(
                animation: _expandAnimation,
                builder: (context, child) {
                  return BackdropFilter(
                    filter: ImageFilter.blur(
                      sigmaX: 5 * _expandAnimation.value,
                      sigmaY: 5 * _expandAnimation.value,
                    ),
                    child: const SizedBox.expand(),
                  );
                },
              ),
            ),
          ),

        // Options du menu
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Option 1: Scanner
            _buildLiquidGlassOption(
              index: 2,
              label: 'Nouveau livre',
              icon: Icons.camera_alt_rounded,
              accentColor: const Color(0xFF8B5CF6), // Violet
              onTap: () {
                _close();
                widget.onScanPressed();
              },
              isDark: isDark,
            ),
            const SizedBox(height: 12),

            // Option 2: Kindle
            _buildLiquidGlassOption(
              index: 1,
              label: 'Livres Kindle',
              icon: Icons.auto_stories_rounded,
              accentColor: const Color(0xFFF59E0B), // Orange/Ambre
              onTap: () {
                _close();
                widget.onKindlePressed();
              },
              isDark: isDark,
            ),
            const SizedBox(height: 12),

            // Option 3: Bibliothèque
            _buildLiquidGlassOption(
              index: 0,
              label: 'Ma bibliothèque',
              icon: Icons.menu_book_rounded,
              accentColor: const Color(0xFF10B981), // Vert émeraude
              onTap: () {
                _close();
                widget.onLibraryPressed();
              },
              isDark: isDark,
            ),
            const SizedBox(height: 16),

            // Bouton principal Liquid Glass
            _buildMainLiquidGlassButton(isDark),
          ],
        ),
      ],
    );
  }

  Widget _buildMainLiquidGlassButton(bool isDark) {
    return GestureDetector(
      onTap: _toggle,
      child: AnimatedBuilder(
        animation: _expandAnimation,
        builder: (context, child) {
          return Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              // Gradient de fond glass
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [
                        AppColors.primary.withValues(alpha: 0.25),
                        AppColors.primary.withValues(alpha: 0.12),
                      ]
                    : [
                        AppColors.primary.withValues(alpha: 0.4),
                        AppColors.primary.withValues(alpha: 0.2),
                      ],
              ),
              // Bordure subtile avec reflet
              border: Border.all(
                color: isDark
                    ? AppColors.primary.withValues(alpha: 0.35)
                    : AppColors.primary.withValues(alpha: 0.6),
                width: 1.5,
              ),
              // Ombres multiples pour l'effet de profondeur
              boxShadow: [
                // Ombre externe douce
                BoxShadow(
                  color: Colors.black.withValues(alpha:0.15),
                  blurRadius: 20,
                  spreadRadius: 0,
                  offset: const Offset(0, 8),
                ),
                // Ombre interne lumineuse (simulée)
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: isDark ? 0.15 : 0.35),
                  blurRadius: 10,
                  spreadRadius: -5,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: ClipOval(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        AppColors.primary.withValues(alpha: isDark ? 0.2 : 0.3),
                        Colors.transparent,
                      ],
                      stops: const [0.0, 0.5],
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.menu_book_rounded,
                      size: 28,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLiquidGlassOption({
    required int index,
    required String label,
    required IconData icon,
    required Color accentColor,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    final delay = index * 0.1;

    return AnimatedBuilder(
      animation: _expandAnimation,
      builder: (context, child) {
        final progress = Curves.easeOutCubic.transform(
          ((_expandAnimation.value - delay) / (1.0 - delay)).clamp(0.0, 1.0),
        );

        if (progress <= 0) return const SizedBox.shrink();

        return Opacity(
          opacity: progress,
          child: Transform.translate(
            offset: Offset(0, 30 * (1 - progress)),
            child: Transform.scale(
              scale: 0.8 + (0.2 * progress),
              child: child,
            ),
          ),
        );
      },
      child: GestureDetector(
        onTap: onTap,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Label avec effet Liquid Glass
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: isDark
                          ? [
                              Colors.white.withValues(alpha:0.15),
                              Colors.white.withValues(alpha:0.05),
                            ]
                          : [
                              Colors.white.withValues(alpha:0.7),
                              Colors.white.withValues(alpha:0.4),
                            ],
                    ),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha:0.2)
                          : Colors.white.withValues(alpha:0.6),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha:0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: isDark ? Colors.white : Colors.black87,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Bouton icône avec Liquid Glass + accent coloré
            ClipOval(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        accentColor.withValues(alpha:0.8),
                        accentColor.withValues(alpha:0.5),
                      ],
                    ),
                    border: Border.all(
                      color: Colors.white.withValues(alpha:0.4),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: accentColor.withValues(alpha:0.4),
                        blurRadius: 12,
                        spreadRadius: 0,
                        offset: const Offset(0, 4),
                      ),
                      BoxShadow(
                        color: Colors.black.withValues(alpha:0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      // Reflet en haut
                      Positioned(
                        top: 4,
                        left: 8,
                        right: 8,
                        child: Container(
                          height: 12,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.white.withValues(alpha:0.5),
                                Colors.white.withValues(alpha:0.0),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Center(
                        child: Icon(
                          icon,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
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
