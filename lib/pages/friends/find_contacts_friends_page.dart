import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../l10n/app_localizations.dart';
import '../../services/contacts_service.dart';
import '../../theme/app_theme.dart';

class FindContactsFriendsPage extends StatefulWidget {
  const FindContactsFriendsPage({super.key});

  @override
  State<FindContactsFriendsPage> createState() =>
      _FindContactsFriendsPageState();
}

enum _PageState { loading, results, permissionDenied, permissionPermanentlyDenied, error }

class _FindContactsFriendsPageState extends State<FindContactsFriendsPage> {
  final ContactsService _contactsService = ContactsService();

  _PageState _state = _PageState.loading;
  List<ContactMatch> _matchedUsers = [];
  List<UnmatchedContact> _unmatchedContacts = [];
  final Set<String> _requestsSent = {};
  final Set<String> _invitesSent = {};

  @override
  void initState() {
    super.initState();
    _scanContacts();
  }

  Future<void> _scanContacts() async {
    setState(() => _state = _PageState.loading);

    try {
      final granted = await _contactsService.requestContactsPermission();

      if (!granted) {
        final permanentlyDenied =
            await _contactsService.isContactsPermissionPermanentlyDenied();
        if (!mounted) return;
        setState(() {
          _state = permanentlyDenied
              ? _PageState.permissionPermanentlyDenied
              : _PageState.permissionDenied;
        });
        return;
      }

      final result = await _contactsService.fetchContactsWithDetails();

      if (!mounted) return;
      setState(() {
        _matchedUsers = result.matched;
        _unmatchedContacts = result.unmatched;
        _state = _PageState.results;
      });
    } catch (e) {
      debugPrint('Erreur scanContacts: $e');
      if (!mounted) return;
      setState(() => _state = _PageState.error);
    }
  }

  Future<void> _sendFriendRequest(ContactMatch user) async {
    final success = await _contactsService.sendFriendRequest(user.id);
    if (!mounted) return;

    if (success) {
      setState(() => _requestsSent.add(user.id));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).invitationSent(user.displayName))),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).requestSent)),
      );
    }
  }

  Future<void> _sendSmsInvite(UnmatchedContact contact) async {
    final l = AppLocalizations.of(context);
    final message = Uri.encodeComponent(l.shareInviteToLexDay);
    final uri = Uri.parse('sms:${contact.phone}?body=$message');

    try {
      await launchUrl(uri);
      if (!mounted) return;
      setState(() => _invitesSent.add(contact.phone));
    } catch (e) {
      debugPrint('Erreur envoi SMS: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        title: Text(l.findContactsFriends),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: switch (_state) {
          _PageState.loading => _buildLoading(isDark),
          _PageState.results => _buildResults(isDark),
          _PageState.permissionDenied => _buildPermissionDenied(isDark),
          _PageState.permissionPermanentlyDenied =>
            _buildPermissionPermanentlyDenied(isDark),
          _PageState.error => _buildError(isDark),
        },
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
            l.searchingYourContacts,
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
    final hasMatched = _matchedUsers.isNotEmpty;
    final hasUnmatched = _unmatchedContacts.isNotEmpty;

    if (!hasMatched && !hasUnmatched) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.l),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.person_search,
                size: 64,
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
              ),
              const SizedBox(height: AppSpace.l),
              Text(
                l.noContactFound,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.textPrimaryDark : Colors.black87,
                ),
              ),
              const SizedBox(height: AppSpace.s),
              Text(
                l.contactsNotOnLexDay,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.l),
      children: [
        if (hasMatched) ...[
          const SizedBox(height: AppSpace.m),
          _buildSectionHeader(
            l.alreadyOnLexDay,
            _matchedUsers.length,
            isDark,
          ),
          const SizedBox(height: AppSpace.s),
          ...List.generate(
            _matchedUsers.length,
            (i) => _buildMatchedUserItem(_matchedUsers[i], isDark),
          ),
        ],
        if (hasUnmatched) ...[
          const SizedBox(height: AppSpace.l),
          _buildSectionHeader(
            l.inviteToLexDay,
            _unmatchedContacts.length,
            isDark,
          ),
          const SizedBox(height: AppSpace.s),
          ...List.generate(
            _unmatchedContacts.length,
            (i) => _buildUnmatchedContactItem(_unmatchedContacts[i], isDark),
          ),
        ],
        const SizedBox(height: AppSpace.l),
      ],
    );
  }

  Widget _buildSectionHeader(String title, int count, bool isDark) {
    return Row(
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: isDark ? AppColors.textPrimaryDark : Colors.black87,
          ),
        ),
        const SizedBox(width: AppSpace.s),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.15),
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: Text(
            '$count',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMatchedUserItem(ContactMatch user, bool isDark) {
    final l = AppLocalizations.of(context);
    final alreadySent = _requestsSent.contains(user.id);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpace.s),
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
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
              onPressed: () => _sendFriendRequest(user),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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

  Widget _buildUnmatchedContactItem(UnmatchedContact contact, bool isDark) {
    final l = AppLocalizations.of(context);
    final alreadyInvited = _invitesSent.contains(contact.phone);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpace.s),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: isDark
                ? AppColors.borderDark
                : Colors.grey.shade300,
            child: Text(
              contact.displayName.isNotEmpty
                  ? contact.displayName[0].toUpperCase()
                  : '?',
              style: TextStyle(
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
          const SizedBox(width: AppSpace.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  contact.displayName,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: isDark ? AppColors.textPrimaryDark : Colors.black87,
                  ),
                ),
                Text(
                  contact.phone,
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
          if (alreadyInvited)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
                    l.invited,
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
            OutlinedButton(
              onPressed: () => _sendSmsInvite(contact),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                l.invite,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPermissionDenied(bool isDark) {
    final l = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.all(AppSpace.l),
      child: Column(
        children: [
          const Spacer(flex: 2),
          Icon(
            Icons.contacts,
            size: 64,
            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
          ),
          const SizedBox(height: AppSpace.l),
          Text(
            l.contactsAccessDenied,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDark ? AppColors.textPrimaryDark : Colors.black87,
            ),
          ),
          const SizedBox(height: AppSpace.s),
          Text(
            l.authorizeContacts,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
            ),
          ),
          const Spacer(flex: 3),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _scanContacts,
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
          const SizedBox(height: AppSpace.l),
        ],
      ),
    );
  }

  Widget _buildPermissionPermanentlyDenied(bool isDark) {
    final l = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.all(AppSpace.l),
      child: Column(
        children: [
          const Spacer(flex: 2),
          Icon(
            Icons.contacts,
            size: 64,
            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
          ),
          const SizedBox(height: AppSpace.l),
          Text(
            l.contactsAccessDenied,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDark ? AppColors.textPrimaryDark : Colors.black87,
            ),
          ),
          const SizedBox(height: AppSpace.s),
          Text(
            l.authorizeContactsSettings,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
            ),
          ),
          const Spacer(flex: 3),
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
          const SizedBox(height: AppSpace.l),
        ],
      ),
    );
  }

  Widget _buildError(bool isDark) {
    final l = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.all(AppSpace.l),
      child: Column(
        children: [
          const Spacer(flex: 2),
          Icon(
            Icons.error_outline,
            size: 64,
            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
          ),
          const SizedBox(height: AppSpace.l),
          Text(
            l.errorOccurred,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDark ? AppColors.textPrimaryDark : Colors.black87,
            ),
          ),
          const SizedBox(height: AppSpace.s),
          Text(
            l.cannotAccessContactsRetry,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
            ),
          ),
          const Spacer(flex: 3),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _scanContacts,
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
          const SizedBox(height: AppSpace.l),
        ],
      ),
    );
  }
}
