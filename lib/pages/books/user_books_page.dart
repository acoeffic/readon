import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/app_theme.dart';
import '../../widgets/back_header.dart';

class UserBooksPage extends StatefulWidget {
  const UserBooksPage({super.key});

  @override
  State<UserBooksPage> createState() => _UserBooksPageState();
}

class _UserBooksPageState extends State<UserBooksPage> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _userBooks = [];
  final Set<String> _deleting = {};

  @override
  void initState() {
    super.initState();
    _loadBooks();
  }

  Future<void> _loadBooks() async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;

    if (user == null) {
      setState(() {
        _error = 'Non connecté';
        _loading = false;
      });
      return;
    }

    try {
      final data = await client
          .from('user_books')
          .select('id, created_at, book:books(id, title, author, cover_url, description)')
          .eq('user_id', user.id)
          .order('created_at', ascending: false);

      final list = (data as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

      if (!mounted) return;
      setState(() {
        _userBooks = list;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Erreur de chargement';
        _loading = false;
      });
    }
  }

  Future<void> _removeUserBook(String userBookId) async {
    if (userBookId.isEmpty) return;

    final client = Supabase.instance.client;

    setState(() => _deleting.add(userBookId));

    try {
      await client.from('user_books').delete().eq('id', userBookId);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Livre retiré')),
      );

      await _loadBooks();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible de retirer ce livre')),
      );
    } finally {
      if (mounted) {
        setState(() => _deleting.remove(userBookId));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgLight,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.l),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const BackHeader(title: 'Ma bibliothèque'),
              const SizedBox(height: AppSpace.m),

              if (_loading) const LinearProgressIndicator(),
              if (_error != null && !_loading)
                Center(child: Text(_error!)),

              if (!_loading && _userBooks.isEmpty && _error == null)
                Expanded(
                  child: Center(
                    child: Text(
                      'Aucun livre dans ta bibliothèque',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ),

              if (!_loading && _userBooks.isNotEmpty)
                Expanded(
                  child: ListView.separated(
                    itemCount: _userBooks.length,
                    separatorBuilder: (_, __) => const SizedBox(height: AppSpace.s),
                    itemBuilder: (context, index) {
                      final entry = _userBooks[index];
                      final book = (entry['book'] as Map?) ?? {};
                      final title = book['title'] as String? ?? 'Sans titre';
                      final author = book['author'] as String? ?? 'Auteur inconnu';
                      final cover = book['cover_url'] as String?;
                      final userBookId = entry['id']?.toString() ?? '';
                      final deleting = _deleting.contains(userBookId);

                      return Container(
                        padding: const EdgeInsets.all(AppSpace.m),
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(AppRadius.l),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 60,
                              height: 90,
                              decoration: BoxDecoration(
                                color: AppColors.accentLight,
                                borderRadius: BorderRadius.circular(AppRadius.m),
                                image: cover != null
                                    ? DecorationImage(
                                        image: NetworkImage(cover),
                                        fit: BoxFit.cover,
                                      )
                                    : null,
                              ),
                              child: cover == null
                                  ? const Icon(Icons.menu_book_outlined)
                                  : null,
                            ),
                            const SizedBox(width: AppSpace.m),

                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                                  const SizedBox(height: AppSpace.xs),
                                  Text(author, style: Theme.of(context).textTheme.bodyMedium),
                                ],
                              ),
                            ),

                            IconButton(
                              icon: deleting
                                  ? const SizedBox(
                                      height: 16,
                                      width: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(AppColors.error),
                                      ),
                                    )
                                  : const Icon(Icons.delete_outline, color: AppColors.error),
                              onPressed: deleting || userBookId.isEmpty
                                  ? null
                                  : () => _removeUserBook(userBookId),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
