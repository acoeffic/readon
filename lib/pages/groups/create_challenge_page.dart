import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/app_theme.dart';
import '../../widgets/back_header.dart';
import '../../widgets/cached_book_cover.dart';
import '../../models/book.dart';
import '../../services/challenge_service.dart';
import '../../services/books_service.dart';
import '../../services/google_books_service.dart';

class CreateChallengePage extends StatefulWidget {
  final String groupId;

  const CreateChallengePage({super.key, required this.groupId});

  @override
  State<CreateChallengePage> createState() => _CreateChallengePageState();
}

class _CreateChallengePageState extends State<CreateChallengePage> {
  final _formKey = GlobalKey<FormState>();
  final ChallengeService _challengeService = ChallengeService();

  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _targetValueController = TextEditingController();
  final _targetDaysController = TextEditingController();

  String _type = 'read_pages';
  Book? _selectedBook;
  DateTime _endsAt = DateTime.now().add(const Duration(days: 7));
  bool _isCreating = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _targetValueController.dispose();
    _targetDaysController.dispose();
    super.dispose();
  }

  Future<void> _selectBook() async {
    final book = await showDialog<Book>(
      context: context,
      builder: (ctx) => const _BookSearchDialog(),
    );

    if (book != null) {
      setState(() {
        _selectedBook = book;
        if (_titleController.text.isEmpty) {
          _titleController.text = AppLocalizations.of(context).readBookTitle(book.title);
        }
      });
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endsAt,
      firstDate: DateTime.now().add(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (picked != null) {
      setState(() => _endsAt = picked);
    }
  }

  Future<void> _createChallenge() async {
    final l = AppLocalizations.of(context);
    if (!_formKey.currentState!.validate()) return;

    if (_type == 'read_book' && _selectedBook == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.selectBookPrompt)),
      );
      return;
    }

    setState(() => _isCreating = true);

    try {
      int targetValue;
      int? targetDays;

      switch (_type) {
        case 'read_book':
          targetValue = _selectedBook?.pageCount ?? 1;
          break;
        case 'read_pages':
          targetValue = int.parse(_targetValueController.text);
          break;
        case 'read_daily':
          targetValue = int.parse(_targetValueController.text);
          targetDays = int.parse(_targetDaysController.text);
          break;
        default:
          targetValue = 1;
      }

      await _challengeService.createChallenge(
        groupId: widget.groupId,
        type: _type,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        targetBookId: _selectedBook?.id,
        targetValue: targetValue,
        targetDays: targetDays,
        endsAt: _endsAt,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).challengeCreated),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() => _isCreating = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  String _getDurationLabel(BuildContext context) {
    final l = AppLocalizations.of(context);
    final days = _endsAt.difference(DateTime.now()).inDays;
    if (days == 7) return l.oneWeek;
    if (days == 14) return l.twoWeeks;
    if (days == 30) return l.oneMonth;
    return '$days ${l.daysUnit}';
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpace.l),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BackHeader(title: l.newChallenge),
                const SizedBox(height: AppSpace.xl),

                // Challenge type selector
                _buildSectionTitle(l.challengeType),
                const SizedBox(height: AppSpace.m),
                _buildTypeSelector(),
                const SizedBox(height: AppSpace.xl),

                // Title
                TextFormField(
                  controller: _titleController,
                  decoration: InputDecoration(
                    labelText: l.challengeTitleRequired,
                    hintText: l.challengeTitleHint,
                    border: const OutlineInputBorder(),
                  ),
                  maxLength: 150,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return l.titleRequired;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpace.m),

                // Description
                TextFormField(
                  controller: _descriptionController,
                  decoration: InputDecoration(
                    labelText: l.descriptionOptional,
                    border: const OutlineInputBorder(),
                  ),
                  maxLines: 2,
                  maxLength: 300,
                ),
                const SizedBox(height: AppSpace.xl),

                // Type-specific fields
                _buildTypeSpecificFields(),
                const SizedBox(height: AppSpace.xl),

                // Expiration date
                _buildSectionTitle(l.deadline),
                const SizedBox(height: AppSpace.m),
                _buildDateSelector(),
                const SizedBox(height: AppSpace.xl),

                // Create button
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isCreating ? null : _createChallenge,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.m),
                      ),
                    ),
                    child: _isCreating
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Text(
                            l.createChallengeBtn,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildTypeSelector() {
    final l = AppLocalizations.of(context);
    return Row(
      children: [
        _buildTypeChip('read_pages', l.pagesType, Icons.menu_book),
        const SizedBox(width: AppSpace.s),
        _buildTypeChip('read_book', l.bookType, Icons.book),
        const SizedBox(width: AppSpace.s),
        _buildTypeChip('read_daily', l.dailyType, Icons.calendar_today),
      ],
    );
  }

  Widget _buildTypeChip(String type, String label, IconData icon) {
    final isSelected = _type == type;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _type = type),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primary.withValues(alpha:0.15)
                : Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(AppRadius.m),
            border: Border.all(
              color: isSelected ? AppColors.primary : Colors.transparent,
              width: 2,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: isSelected ? AppColors.primary : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                size: 24,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected ? AppColors.primary : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeSpecificFields() {
    switch (_type) {
      case 'read_book':
        return _buildBookSelector();
      case 'read_pages':
        return _buildPagesField();
      case 'read_daily':
        return _buildDailyFields();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildBookSelector() {
    final l = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(l.bookToRead),
        const SizedBox(height: AppSpace.m),
        GestureDetector(
          onTap: _selectBook,
          child: Container(
            padding: const EdgeInsets.all(AppSpace.m),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(AppRadius.m),
              border: Border.all(
                color: _selectedBook != null
                    ? AppColors.primary.withValues(alpha:0.5)
                    : Colors.grey.withValues(alpha:0.3),
              ),
            ),
            child: _selectedBook != null
                ? Row(
                    children: [
                      CachedBookCover(
                        imageUrl: _selectedBook!.coverUrl,
                        width: 40,
                        height: 56,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      const SizedBox(width: AppSpace.m),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _selectedBook!.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (_selectedBook!.author != null)
                              Text(
                                _selectedBook!.author!,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                                ),
                              ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4)),
                    ],
                  )
                : Row(
                    children: [
                      Icon(Icons.search, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
                      const SizedBox(width: AppSpace.m),
                      Text(
                        l.searchBookHint,
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildPagesField() {
    final l = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(l.goalLabel),
        const SizedBox(height: AppSpace.m),
        TextFormField(
          controller: _targetValueController,
          decoration: InputDecoration(
            labelText: l.pagesCountRequired,
            hintText: l.pagesCountHint,
            border: const OutlineInputBorder(),
            suffixText: l.pagesUnit,
          ),
          keyboardType: TextInputType.number,
          validator: (value) {
            if (_type != 'read_pages') return null;
            if (value == null || value.isEmpty) return l.required;
            final n = int.tryParse(value);
            if (n == null || n <= 0) return l.invalidNumber;
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildDailyFields() {
    final l = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(l.dailyGoal),
        const SizedBox(height: AppSpace.m),
        TextFormField(
          controller: _targetValueController,
          decoration: InputDecoration(
            labelText: l.dailyMinutesRequired,
            hintText: l.dailyMinutesHint,
            border: const OutlineInputBorder(),
            suffixText: l.minPerDay,
          ),
          keyboardType: TextInputType.number,
          validator: (value) {
            if (_type != 'read_daily') return null;
            if (value == null || value.isEmpty) return l.required;
            final n = int.tryParse(value);
            if (n == null || n <= 0) return l.invalidNumber;
            return null;
          },
        ),
        const SizedBox(height: AppSpace.m),
        TextFormField(
          controller: _targetDaysController,
          decoration: InputDecoration(
            labelText: l.daysCountRequired,
            hintText: l.daysCountHint,
            border: const OutlineInputBorder(),
            suffixText: l.daysUnit,
          ),
          keyboardType: TextInputType.number,
          validator: (value) {
            if (_type != 'read_daily') return null;
            if (value == null || value.isEmpty) return l.required;
            final n = int.tryParse(value);
            if (n == null || n <= 0) return l.invalidNumber;
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildDateSelector() {
    final l = AppLocalizations.of(context);
    return Column(
      children: [
        // Preset buttons
        Row(
          children: [
            _buildPresetChip(7, l.oneWeek),
            const SizedBox(width: AppSpace.s),
            _buildPresetChip(14, l.twoWeeks),
            const SizedBox(width: AppSpace.s),
            _buildPresetChip(30, l.oneMonth),
          ],
        ),
        const SizedBox(height: AppSpace.m),
        // Selected date
        GestureDetector(
          onTap: _selectDate,
          child: Container(
            padding: const EdgeInsets.all(AppSpace.m),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(AppRadius.m),
            ),
            child: Row(
              children: [
                const Icon(Icons.event, color: AppColors.primary),
                const SizedBox(width: AppSpace.m),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l.expiresOn,
                      style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
                    ),
                    Text(
                      '${_formatDate(_endsAt)} (${_getDurationLabel(context)})',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Icon(Icons.chevron_right, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPresetChip(int days, String label) {
    final target = DateTime.now().add(Duration(days: days));
    final isSelected = _endsAt.difference(DateTime.now()).inDays == days;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _endsAt = target),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primary.withValues(alpha:0.15)
                : Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(AppRadius.s),
            border: Border.all(
              color: isSelected ? AppColors.primary : Colors.transparent,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? AppColors.primary : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Dialog for searching and selecting a book
class _BookSearchDialog extends StatefulWidget {
  const _BookSearchDialog();

  @override
  State<_BookSearchDialog> createState() => _BookSearchDialogState();
}

class _BookSearchDialogState extends State<_BookSearchDialog> {
  final _searchController = TextEditingController();
  final BooksService _booksService = BooksService();
  final GoogleBooksService _googleBooksService = GoogleBooksService();

  List<Book> _userBooks = [];
  List<GoogleBook> _searchResults = [];
  bool _isLoading = true;
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _loadUserBooks();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUserBooks() async {
    try {
      final books = await _booksService.getUserBooks();
      setState(() {
        _userBooks = books;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _search(String query) async {
    if (query.trim().length < 2) {
      setState(() => _searchResults = []);
      return;
    }

    setState(() => _isSearching = true);
    try {
      final results = await _googleBooksService.searchBooks(query);
      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    } catch (e) {
      setState(() => _isSearching = false);
    }
  }

  Future<void> _selectGoogleBook(GoogleBook googleBook) async {
    try {
      final book = await _booksService.addBookFromGoogleBooks(googleBook);
      if (mounted) Navigator.of(context).pop(book);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.l),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.l),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l.chooseBook,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSpace.m),
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: l.searchBookHint,
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.m),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              onChanged: _search,
            ),
            const SizedBox(height: AppSpace.m),
            SizedBox(
              height: 300,
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _searchController.text.isNotEmpty
                      ? _buildSearchResults()
                      : _buildUserBooks(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserBooks() {
    if (_userBooks.isEmpty) {
      return Center(
        child: Text(AppLocalizations.of(context).libraryEmpty),
      );
    }

    return ListView.builder(
      itemCount: _userBooks.length,
      itemBuilder: (context, index) {
        final book = _userBooks[index];
        return _BookListTile(
          title: book.title,
          author: book.author,
          coverUrl: book.coverUrl,
          onTap: () => Navigator.of(context).pop(book),
        );
      },
    );
  }

  Widget _buildSearchResults() {
    final l = AppLocalizations.of(context);
    if (_isSearching) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_searchResults.isEmpty) {
      return Center(child: Text(l.noResult));
    }

    return ListView.builder(
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final book = _searchResults[index];
        return _BookListTile(
          title: book.title,
          author: book.authorsString,
          coverUrl: book.coverUrl,
          onTap: () => _selectGoogleBook(book),
        );
      },
    );
  }
}

class _BookListTile extends StatelessWidget {
  final String title;
  final String? author;
  final String? coverUrl;
  final VoidCallback onTap;

  const _BookListTile({
    required this.title,
    this.author,
    this.coverUrl,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 4),
      leading: CachedBookCover(
        imageUrl: coverUrl,
        width: 32,
        height: 48,
        borderRadius: BorderRadius.circular(4),
      ),
      title: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 14),
      ),
      subtitle: author != null
          ? Text(
              author!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12),
            )
          : null,
      onTap: onTap,
    );
  }
}
