import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/kindle_api_service.dart';

class KindleSyncScreen extends StatefulWidget {
  const KindleSyncScreen({super.key});

  @override
  State<KindleSyncScreen> createState() => _KindleSyncScreenState();
}

class _KindleSyncScreenState extends State<KindleSyncScreen> {
  final KindleApiService _apiService = KindleApiService();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  
  List<Book> _books = [];
  ReadingStats? _stats;
  bool _isLoading = false;
  bool _isSyncing = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadBooks();
  }

  Future<void> _loadBooks() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final books = await _apiService.getBooks();
      final stats = await _apiService.getStats();
      
      setState(() {
        _books = books;
        _stats = stats;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _syncKindle() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Email et password requis')),
      );
      return;
    }

    setState(() => _isSyncing = true);

    try {
      final result = await _apiService.syncKindle(
        _emailController.text,
        _passwordController.text,
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? 'Sync réussie')),
        );
        Navigator.of(context).pop();
        await _loadBooks();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    } finally {
      setState(() => _isSyncing = false);
    }
  }

  void _showSyncDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Synchroniser Kindle'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email Kindle',
                hintText: 'votre-email@kindle.com',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Password'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: _isSyncing ? null : _syncKindle,
            child: _isSyncing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Synchroniser'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('📚 Mes Livres Kindle'),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            onPressed: _showSyncDialog,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadBooks,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? _buildErrorView()
              : _buildContentView(),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text(_errorMessage!),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadBooks,
            child: const Text('Réessayer'),
          ),
        ],
      ),
    );
  }

  Widget _buildContentView() {
    return Column(
      children: [
        if (_stats != null) _buildStatsCard(),
        Expanded(
          child: _books.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  itemCount: _books.length,
                  itemBuilder: (context, index) => _buildBookCard(_books[index]),
                ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.book, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text('Aucun livre synchronisé'),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _showSyncDialog,
            icon: const Icon(Icons.sync),
            label: const Text('Synchroniser Kindle'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCard() {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildStatItem('Livres', _stats!.totalBooks.toString(), Icons.book),
            _buildStatItem('Highlights', _stats!.totalHighlights.toString(), Icons.highlight),
            _buildStatItem('Moyenne', _stats!.averageHighlightsPerBook, Icons.trending_up),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 32),
        const SizedBox(height: 8),
        Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(color: Colors.grey)),
      ],
    );
  }

  Widget _buildBookCard(Book book) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ListTile(
        leading: book.cover.isNotEmpty
            ? CachedNetworkImage(
                imageUrl: book.cover,
                width: 50,
                fit: BoxFit.cover,
                placeholder: (context, url) => const Icon(Icons.book, size: 50),
                errorWidget: (context, url, error) => const Icon(Icons.book, size: 50),
              )
            : const Icon(Icons.book, size: 50),
        title: Text(book.title, maxLines: 2, overflow: TextOverflow.ellipsis),
        subtitle: Text(book.author),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.highlight, size: 20),
            Text('${book.highlightCount}'),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}