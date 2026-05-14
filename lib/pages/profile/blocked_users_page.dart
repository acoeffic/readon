// lib/pages/profile/blocked_users_page.dart
//
// Liste des utilisateurs bloqués par l'utilisateur courant, avec action
// de déblocage. Requise par les guidelines Apple §1.2 (UGC) pour qu'un
// utilisateur puisse défaire son geste.

import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../services/moderation_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/cached_profile_avatar.dart';
import '../../widgets/constrained_content.dart';

class BlockedUsersPage extends StatefulWidget {
  const BlockedUsersPage({super.key});

  @override
  State<BlockedUsersPage> createState() => _BlockedUsersPageState();
}

class _BlockedUsersPageState extends State<BlockedUsersPage> {
  bool _loading = true;
  List<BlockedUserInfo> _users = const [];
  final _unblocking = <String>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final users = await ModerationService().getBlockedUsers();
    if (!mounted) return;
    setState(() {
      _users = users;
      _loading = false;
    });
  }

  Future<void> _unblock(BlockedUserInfo info) async {
    final l = AppLocalizations.of(context);
    setState(() => _unblocking.add(info.userId));

    final ok = await ModerationService().unblockUser(info.userId);
    if (!mounted) return;

    setState(() {
      _unblocking.remove(info.userId);
      if (ok) {
        _users = _users.where((u) => u.userId != info.userId).toList();
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? l.userUnblockedMessage : l.blockUserErrorMessage),
        backgroundColor: ok ? AppColors.primary : Colors.red.shade700,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l.blockedUsersTitle),
      ),
      body: ConstrainedContent(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _users.isEmpty
                ? _buildEmpty(l)
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: _users.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) => _buildTile(_users[i], l),
                    ),
                  ),
      ),
    );
  }

  Widget _buildEmpty(AppLocalizations l) {
    return ListView(
      // ListView pour rester pull-to-refreshable même quand vide.
      children: [
        const SizedBox(height: 120),
        Icon(
          Icons.block,
          size: 48,
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
        ),
        const SizedBox(height: 12),
        Center(
          child: Text(
            l.blockedUsersEmpty,
            style: TextStyle(
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.6),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTile(BlockedUserInfo info, AppLocalizations l) {
    final isUnblocking = _unblocking.contains(info.userId);
    final name = (info.displayName?.trim().isNotEmpty == true)
        ? info.displayName!
        : '—';

    return ListTile(
      leading: CachedProfileAvatar(
        imageUrl: info.avatarUrl,
        userName: name,
        radius: 22,
        backgroundColor: AppColors.primary.withValues(alpha: 0.15),
        textColor: AppColors.primary,
      ),
      title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
      trailing: isUnblocking
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : TextButton(
              onPressed: () => _unblock(info),
              style: TextButton.styleFrom(foregroundColor: AppColors.primary),
              child: Text(l.unblockUserAction),
            ),
    );
  }
}
