import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/app_theme.dart';
import '../../widgets/back_header.dart';

class AddBookPage extends StatefulWidget {
  const AddBookPage({super.key});

  @override
  State<AddBookPage> createState() => _AddBookPageState();
}

class _AddBookPageState extends State<AddBookPage> {
  final _searchController = TextEditingController();
  final _titleController = TextEditingController();
  final _authorController = TextEditingController();
  final _pagesController = TextEditingController();

  bool _saving = false;
  bool _searching = false;
  List<Map<String, dynamic>> _searchResults = [];
  Timer? _debounce;

  @override
  void dispose() {
    _searchController.dispose();
    _titleController.dispose();
    _authorController.dispose();
    _pagesController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _searchBooks(value);
    });
  }

  Future<void> _searchBooks(String query) async {
    final q = query.trim();
    if (q.length < 2) {
      setState(() => _searchResults = []);
      return;
    }

    setState(() => _searching = true);

    try {
      final response = await Supabase.instance.client.functions.invoke(
        'search_books',
        body: {'q': q},
      );

      List<dynamic> parsedResults = [];
      final payload = response.data;

      if (payload is Map<String, dynamic>) {
        final results = payload['results'];
        if (results is List) parsedResults = results;
      } else if (payload is List) {
        parsedResults = payload;
      } else if (payload is String) {
        try {
          final decoded = jsonDecode(payload);
          if (decoded is Map<String, dynamic>) {
            final results = decoded['results'];
            if (results is List) parsedResults = results;
          } else if (decoded is List) parsedResults = decoded;
        } catch (_) {}
      }

      setState(() {
        _searchResults = parsedResults
            .whereType<Map<String, dynamic>>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        _searching = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _searching = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erreur recherche Google Books')),
      );
    }
  }

  Future<void> _addBookFromSearch(Map<String, dynamic> book) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Non connecté')),
      );
      return;
    }

    try {
      final supabase = Supabase.instance.client;
      final title = (book['title'] as String?)?.trim();
      final author = (book['author'] as String?)?.trim();

      int? bookId;

      if (title != null && title.isNotEmpty) {
        try {
          var query = supabase.from('books').select('id').eq('title', title);
          if (author != null && author.isNotEmpty) {
            query = query.eq('author', author);
          }
          final existing = await query.maybeSingle();
          if (existing != null) {
            bookId = (existing['id'] as num?)?.toInt();
          }
        } catch (_) {}
      }

      if (bookId == null) {
        final inserted = await supabase
            .from('books')
            .insert({
              'title': title ?? 'Titre inconnu',
              'author': author,
              'cover_url': book['cover_url'],
              'description': book['description'],
            })
            .select('id')
            .single();
        bookId = (inserted['id'] as num).toInt();
      }

      await supabase.from('user_books').insert({
        'user_id': user.id,
        'book_id': bookId,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${book['title'] ?? 'Livre'} ajouté')),
      );

      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible d’ajouter ce livre')),
      );
    }
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    final author = _authorController.text.trim();
    final pages = int.tryParse(_pagesController.text.trim());

    if (title.isEmpty || author.isEmpty || pages == null || pages <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Titre, auteur et pages requis')),
      );
      return;
    }

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    setState(() => _saving = true);

    try {
      final supabase = Supabase.instance.client;
      final inserted = await supabase
          .from('books')
          .insert({'title': title, 'author': author, 'total_pages': pages})
          .select('id')
          .single();

      final bookId = (inserted['id'] as num).toInt();

      await supabase.from('user_books').insert({
        'user_id': user.id,
        'book_id': bookId,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Livre ajouté')),
      );

      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erreur lors de l’ajout')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgLight,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpace.l),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const BackHeader(title: 'Ajouter un livre'),
              const SizedBox(height: AppSpace.l),

              Text('Recherche Google Books', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppSpace.xs),

              TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                decoration: const InputDecoration(
                  hintText: 'Titre, auteur ou ISBN',
                  prefixIcon: Icon(Icons.search),
                ),
              ),

              if (_searching) const LinearProgressIndicator(),
              const SizedBox(height: AppSpace.s),

              if (_searchResults.isNotEmpty)
                ..._searchResults.map(
                  (book) => Padding(
                    padding: const EdgeInsets.only(bottom: AppSpace.s),
                    child: ListTile(
                      leading: (book['cover_url'] as String?) != null
                          ? Image.network(
                              book['cover_url'],
                              width: 40,
                              fit: BoxFit.cover,
                            )
                          : const Icon(Icons.menu_book_outlined),
                      title: Text(book['title'] ?? 'Sans titre'),
                      subtitle: Text(book['author'] ?? ''),
                      trailing: TextButton(
                        onPressed: () => _addBookFromSearch(book),
                        child: const Text('Ajouter', style: TextStyle(color: AppColors.primary)),
                      ),
                    ),
                  ),
                ),

              const SizedBox(height: AppSpace.xl),

              Text('Ajout manuel', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: AppSpace.l),

              TextField(
                controller: _titleController,
                decoration: const InputDecoration(hintText: 'Titre'),
              ),
              const SizedBox(height: AppSpace.m),

              TextField(
                controller: _authorController,
                decoration: const InputDecoration(hintText: 'Auteur'),
              ),
              const SizedBox(height: AppSpace.m),

              TextField(
                controller: _pagesController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(hintText: 'Pages totales'),
              ),

              const SizedBox(height: AppSpace.l),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: AppSpace.m),
                  ),
                  child: _saving
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.white),
                        )
                                            : const Text('Enregistrer'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}