// lib/pages/friends/contacts_suggestion_page.dart

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../l10n/app_localizations.dart';
import '../../models/reading_session.dart';
import '../../models/trophy.dart';
import '../../models/book.dart';
import '../../services/contacts_service.dart';
import '../../theme/app_theme.dart';
import '../reading/reading_session_summary_page.dart';
import '../reading/book_completed_summary_page.dart';

class ContactsSuggestionPage extends StatefulWidget {
  final ReadingSession session;
  final Trophy? trophy;
  final Book? book;
  final bool isBookCompleted;

  const ContactsSuggestionPage({
    super.key,
    required this.session,
    this.trophy,
    this.book,
    this.isBookCompleted = false,
  });

  @override
  State<ContactsSuggestionPage> createState() => _ContactsSuggestionPageState();
}

enum _PageStep { congratulations, loading, results, error }

class _ContactsSuggestionPageState extends State<ContactsSuggestionPage>
    with SingleTickerProviderStateMixin {
  final ContactsService _contactsService = ContactsService();

  _PageStep _step = _PageStep.congratulations;
  List<ContactMatch> _matchedUsers = [];
  final Set<String> _requestsSent = {};
  String? _errorMessage;

  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _scaleAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _findFriends() async {
    setState(() => _step = _PageStep.loading);

    try {
      final granted = await _contactsService.requestContactsPermission();

      if (!granted) {
        final permanentlyDenied =
            await _contactsService.isContactsPermissionPermanentlyDenied();

        setState(() {
          _step = _PageStep.error;
          _errorMessage = permanentlyDenied
              ? 'permission_denied_permanently'
              : 'permission_denied';
        });
        return;
      }

      final data = await _contactsService.getContactData();
      final matches = await _contactsService.findMatchedUsers(data.emails, data.phones);

      if (!mounted) return;
      setState(() {
        _matchedUsers = matches;
        _step = _PageStep.results;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _step = _PageStep.error;
        _errorMessage = 'generic';
      });
    }
  }

  Future<void> _sendRequest(ContactMatch user) async {
    final l = AppLocalizations.of(context);
    final success = await _contactsService.sendFriendRequest(user.id);
    if (!mounted) return;

    if (success) {
      setState(() => _requestsSent.add(user.id));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.invitationSent(user.displayName))),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.requestSent)),
      );
    }
  }

  Future<void> _continue() async {
    await _contactsService.markContactsPromptSeen();
    if (!mounted) return;
    _navigateToSummary();
  }

  Future<void> _skip() async {
    await _contactsService.markContactsPromptSeen();
    if (!mounted) return;
    _navigateToSummary();
  }

  void _navigateToSummary() {
    if (widget.isBookCompleted && widget.book != null) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => BookCompletedSummaryPage(
            book: widget.book!,
            lastSession: widget.session,
          ),
        ),
      );
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => ReadingSessionSummaryPage(
            session: widget.session,
            trophy: widget.trophy,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: switch (_step) {
          _PageStep.congratulations => _buildCongratulations(isDark),
          _PageStep.loading => _buildLoading(isDark),
          _PageStep.results => _buildResults(isDark),
          _PageStep.error => _buildError(isDark),
        },
      ),
    );
  }

  Widget _buildCongratulations(bool isDark) {
    final l = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.all(AppSpace.l),
      child: Column(
        children: [
          const Spacer(flex: 2),
          ScaleTransition(
            scale: _scaleAnimation,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Text(
                  '🎉',
                  style: TextStyle(fontSize: 56),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpace.xl),
          Text(
            l.firstSessionBravo,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: isDark ? AppColors.textPrimaryDark : Colors.black87,
            ),
          ),
          const SizedBox(height: AppSpace.m),
          Text(
            l.friendsReadToo,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
            ),
          ),
          const Spacer(flex: 3),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _findFriends,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.people, size: 20),
                  const SizedBox(width: AppSpace.s),
                  Text(
                    l.findMyFriends,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpace.m),
          TextButton(
            onPressed: _skip,
            child: Text(
              l.skip,
              style: TextStyle(
                fontSize: 15,
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(height: AppSpace.l),
        ],
      ),
    );
  }

  Widget _buildLoading(bool isDark) {
    final l = AppLocalizations.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(color: AppColors.primary),
          const SizedBox(height: AppSpace.l),
          Text(
            l.searchingContacts,
            style: TextStyle(
              fontSize: 16,
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResults(bool isDark) {
    final l = AppLocalizations.of(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(AppSpace.l),
          child: Column(
            children: [
              const SizedBox(height: AppSpace.l),
              Icon(
                _matchedUsers.isEmpty ? Icons.person_search : Icons.people,
                size: 48,
                color: AppColors.primary,
              ),
              const SizedBox(height: AppSpace.m),
              Text(
                _matchedUsers.isEmpty
                    ? l.noContactOnLexDay
                    : l.friendsFoundOnLexDay(_matchedUsers.length),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.textPrimaryDark : Colors.black87,
                ),
              ),
              if (_matchedUsers.isEmpty) ...[
                const SizedBox(height: AppSpace.s),
                Text(
                  l.inviteFriendsToJoin,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (_matchedUsers.isNotEmpty)
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.l),
              itemCount: _matchedUsers.length,
              separatorBuilder: (_, __) => Divider(
                color: isDark ? AppColors.borderDark : AppColors.border,
                height: 1,
              ),
              itemBuilder: (context, index) {
                return _buildUserItem(_matchedUsers[index], isDark);
              },
            ),
          ),
        if (_matchedUsers.isEmpty) const Spacer(),
        Padding(
          padding: const EdgeInsets.all(AppSpace.l),
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _continue,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
              ),
              child: Text(
                l.continueButton,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUserItem(ContactMatch user, bool isDark) {
    final l = AppLocalizations.of(context);
    final alreadySent = _requestsSent.contains(user.id);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpace.m),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: AppColors.primary.withOpacity(0.15),
            backgroundImage:
                user.avatarUrl != null ? NetworkImage(user.avatarUrl!) : null,
            child: user.avatarUrl == null
                ? Text(
                    user.displayName.isNotEmpty
                        ? user.displayName[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: AppSpace.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.displayName,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: isDark ? AppColors.textPrimaryDark : Colors.black87,
                  ),
                ),
                if (user.email != null && !user.isProfilePrivate)
                  Text(
                    user.email!,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpace.s),
          if (alreadySent)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.check,
                    size: 16,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    l.sent,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            )
          else
            ElevatedButton(
              onPressed: () => _sendRequest(user),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                l.addFriend,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildError(bool isDark) {
    final l = AppLocalizations.of(context);
    final isPermanentlyDenied = _errorMessage == 'permission_denied_permanently';

    return Padding(
      padding: const EdgeInsets.all(AppSpace.l),
      child: Column(
        children: [
          const Spacer(flex: 2),
          Icon(
            isPermanentlyDenied ? Icons.contacts : Icons.error_outline,
            size: 64,
            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
          ),
          const SizedBox(height: AppSpace.l),
          Text(
            isPermanentlyDenied
                ? l.contactsAccessDenied
                : l.cannotAccessContacts,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDark ? AppColors.textPrimaryDark : Colors.black87,
            ),
          ),
          const SizedBox(height: AppSpace.s),
          Text(
            isPermanentlyDenied
                ? l.authorizeContactsSettings
                : l.errorOccurredRetryLater,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
            ),
          ),
          const Spacer(flex: 3),
          if (isPermanentlyDenied)
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () => openAppSettings(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                ),
                child: Text(
                  l.openSettings,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          if (!isPermanentlyDenied)
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _findFriends,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                ),
                child: Text(
                  l.retry,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          const SizedBox(height: AppSpace.m),
          TextButton(
            onPressed: _skip,
            child: Text(
              l.skip,
              style: TextStyle(
                fontSize: 15,
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(height: AppSpace.l),
        ],
      ),
    );
  }
}
