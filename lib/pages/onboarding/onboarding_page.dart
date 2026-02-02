import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/book.dart';
import '../../theme/app_theme.dart';
import '../../navigation/main_navigation.dart';
import '../../services/books_service.dart';
import '../../services/kindle_webview_service.dart';
import '../reading/start_reading_session_page_unified.dart';

import 'widgets/onboarding_dots.dart';
import 'widgets/step_welcome.dart';
import 'widgets/step_reading_habit.dart';
import 'widgets/step_kindle_connect.dart';
import 'widgets/step_sync_progress.dart';
import 'widgets/step_sync_success.dart';
import 'widgets/step_manual_add.dart';
import 'widgets/step_first_session.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final PageController _pageController = PageController();
  final BooksService _booksService = BooksService();

  // Shared state
  String? _readingHabit;
  KindleReadingData? _kindleData;
  List<Book> _importedBooks = [];
  Book? _selectedBook;
  int _currentStep = 0;

  bool get _isKindlePath =>
      _readingHabit == 'liseuse' || _readingHabit == 'mix';

  List<Widget> _buildSteps() {
    final steps = <Widget>[
      // Step 1: Welcome
      StepWelcome(onNext: _goToNext),

      // Step 2: Reading habits
      StepReadingHabit(
        selectedHabit: _readingHabit,
        onSelected: (habit) => setState(() => _readingHabit = habit),
        onNext: _goToNext,
      ),
    ];

    if (_isKindlePath) {
      // Kindle path: connect → sync progress → sync success
      steps.addAll([
        StepKindleConnect(
          onKindleResult: _handleKindleResult,
          onSkip: _skipToEnd,
        ),
        StepSyncProgress(
          kindleData: _kindleData,
          onSyncComplete: _handleSyncComplete,
        ),
        StepSyncSuccess(
          bookCount: _importedBooks.length,
          books: _importedBooks,
          onNext: _goToNext,
        ),
      ]);
    } else if (_readingHabit == 'papier') {
      // Paper path: manual add
      steps.add(
        StepManualAdd(
          addedBooks: _importedBooks,
          onBookAdded: _handleBookAdded,
          onNext: _goToNext,
          onSkip: _skipToEnd,
        ),
      );
    }

    // Final step
    steps.add(
      StepFirstSession(
        selectedBook: _selectedBook,
        onStartSession: _startFirstSession,
        onSkip: () => _completeOnboarding(),
      ),
    );

    return steps;
  }

  void _goToNext() {
    final steps = _buildSteps();
    if (_currentStep < steps.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    }
  }

  void _goToPrevious() {
    if (_currentStep > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    }
  }

  void _goToPage(int page) {
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
  }

  // --- Kindle path handlers ---

  void _handleKindleResult(KindleReadingData? data) {
    if (data != null) {
      setState(() => _kindleData = data);
      // Advance to sync progress
      _goToNext();
    }
    // If null (user cancelled), stay on kindle connect step
  }

  Future<void> _handleSyncComplete() async {
    // Load books from DB after Kindle import
    try {
      final booksWithStatus = await _booksService.getUserBooksWithStatus();
      final books = booksWithStatus
          .where((b) => b['is_hidden'] != true)
          .map((b) => b['book'] as Book)
          .toList();
      if (mounted) {
        setState(() {
          _importedBooks = books;
          if (books.isNotEmpty) _selectedBook = books.first;
        });
        _goToNext();
      }
    } catch (_) {
      if (mounted) _goToNext();
    }
  }

  // --- Paper path handlers ---

  void _handleBookAdded(Book book) {
    setState(() {
      if (!_importedBooks.any((b) => b.id == book.id)) {
        _importedBooks.add(book);
      }
      _selectedBook = book;
    });
  }

  // --- Common handlers ---

  void _skipToEnd() {
    // Skip to StepFirstSession (last step)
    final steps = _buildSteps();
    _loadBooksAndGoTo(steps.length - 1);
  }

  Future<void> _loadBooksAndGoTo(int page) async {
    try {
      final booksWithStatus = await _booksService.getUserBooksWithStatus();
      final books = booksWithStatus
          .where((b) => b['is_hidden'] != true)
          .map((b) => b['book'] as Book)
          .toList();
      if (mounted) {
        setState(() => _importedBooks = books);
        _goToPage(page);
      }
    } catch (_) {
      if (mounted) _goToPage(page);
    }
  }

  Future<void> _completeOnboarding() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    // Mark book as reading if selected
    if (_selectedBook != null) {
      try {
        await _booksService.updateBookStatus(_selectedBook!.id, 'reading');
      } catch (_) {}
    }

    await Supabase.instance.client.from('profiles').update({
      'onboarding_completed': true,
      'reading_habit': _readingHabit,
    }).eq('id', userId);

    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const MainNavigation()),
      (route) => false,
    );
  }

  Future<void> _startFirstSession() async {
    final book = _selectedBook;
    if (book == null) {
      await _completeOnboarding();
      return;
    }

    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    // Mark book as reading
    try {
      await _booksService.updateBookStatus(book.id, 'reading');
    } catch (_) {}

    // Mark onboarding complete
    await Supabase.instance.client.from('profiles').update({
      'onboarding_completed': true,
      'reading_habit': _readingHabit,
    }).eq('id', userId);

    if (!mounted) return;

    // Go to main nav then push reading session
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const MainNavigation()),
      (route) => false,
    );
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StartReadingSessionPageUnified(book: book),
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final steps = _buildSteps();

    return Theme(
      data: AppTheme.light,
      child: Scaffold(
        backgroundColor: AppColors.bgLight,
        body: SafeArea(
          child: Column(
            children: [
              // Back button row
              Padding(
                padding: const EdgeInsets.only(
                  left: AppSpace.s,
                  top: AppSpace.s,
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: AnimatedOpacity(
                    opacity: _currentStep > 0 ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: IconButton(
                      onPressed:
                          _currentStep > 0 ? _goToPrevious : null,
                      icon: const Icon(
                        Icons.arrow_back_ios_rounded,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (index) =>
                      setState(() => _currentStep = index),
                  children: steps,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpace.l),
                child: OnboardingDots(
                  total: steps.length,
                  current: _currentStep,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
