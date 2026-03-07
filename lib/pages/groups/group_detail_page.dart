import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/app_theme.dart';
import '../../models/reading_group.dart';
import '../../models/group_challenge.dart';
import '../../services/groups_service.dart';
import '../../services/challenge_service.dart';
import 'group_members_page.dart';
import 'group_settings_page.dart';
import 'create_challenge_page.dart';
import 'challenge_detail_page.dart';
import 'package:intl/intl.dart';

const _kBg = Color(0xFFFAF3E8);
const _kCard = Color(0xFFF0E8D8);
const _kSageGreen = Color(0xFF6B988D);
const _kGold = Color(0xFFC6A85A);

class GroupDetailPage extends StatefulWidget {
  final String groupId;

  const GroupDetailPage({super.key, required this.groupId});

  @override
  State<GroupDetailPage> createState() => _GroupDetailPageState();
}

class _GroupDetailPageState extends State<GroupDetailPage> {
  final GroupsService _groupsService = GroupsService();
  final ChallengeService _challengeService = ChallengeService();

  ReadingGroup? _group;
  List<GroupActivity> _activities = [];
  List<GroupChallenge> _challenges = [];
  bool _isLoading = true;
  bool _isLoadingActivities = true;
  bool _isLoadingChallenges = true;

  @override
  void initState() {
    super.initState();
    _loadGroup();
    _loadActivities();
    _loadChallenges();
  }

  Future<void> _loadGroup() async {
    setState(() => _isLoading = true);
    try {
      final group = await _groupsService.getGroup(widget.groupId);
      setState(() {
        _group = group;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    }
  }

  Future<void> _loadActivities() async {
    setState(() => _isLoadingActivities = true);
    try {
      final activities = await _groupsService.getGroupActivities(
        groupId: widget.groupId,
      );
      setState(() {
        _activities = activities;
        _isLoadingActivities = false;
      });
    } catch (e) {
      setState(() => _isLoadingActivities = false);
    }
  }

  Future<void> _loadChallenges() async {
    setState(() => _isLoadingChallenges = true);
    try {
      final challenges = await _challengeService.getActiveChallenges(widget.groupId);
      setState(() {
        _challenges = challenges;
        _isLoadingChallenges = false;
      });
    } catch (e) {
      setState(() => _isLoadingChallenges = false);
    }
  }

  Future<void> _navigateToCreateChallenge() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => CreateChallengePage(groupId: widget.groupId),
      ),
    );

    if (result == true) _loadChallenges();
  }

  Future<void> _navigateToChallengeDetail(GroupChallenge challenge) async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (context) => ChallengeDetailPage(
          challenge: challenge,
          isAdmin: _group?.isAdmin ?? false,
        ),
      ),
    );

    if (result == 'deleted') _loadChallenges();
  }

  Future<void> _leaveGroup() async {
    final l = AppLocalizations.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.l),
        ),
        title: Text(l.leaveGroupTitle),
        content: Text(l.leaveGroupMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              l.leave,
              style: const TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _groupsService.leaveGroup(widget.groupId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context).leftGroup),
            backgroundColor: Colors.orange,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    }
  }

  void _navigateToMembers() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GroupMembersPage(
          groupId: widget.groupId,
          isAdmin: _group?.isAdmin ?? false,
        ),
      ),
    );
  }

  Future<void> _navigateToSettings() async {
    if (_group == null) return;

    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (context) => GroupSettingsPage(group: _group!),
      ),
    );

    if (result == 'deleted') {
      if (mounted) Navigator.pop(context);
    } else {
      _loadGroup();
    }
  }

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final bg = _isDark ? AppColors.bgDark : _kBg;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: bg,
        appBar: AppBar(backgroundColor: bg),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_group == null) {
      return Scaffold(
        backgroundColor: bg,
        appBar: AppBar(backgroundColor: bg),
        body: Center(child: Text(l.groupNotFound)),
      );
    }

    return Scaffold(
      backgroundColor: bg,
      body: CustomScrollView(
        slivers: [
          // Hero with cover image
          SliverToBoxAdapter(child: _buildHero(context)),

          // Content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.l),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: AppSpace.l),

                  // Stats row
                  Row(
                    children: [
                      _StatCard(
                        icon: Icons.people_outline,
                        label: l.members,
                        value: '${_group!.memberCount ?? 0}',
                        onTap: _navigateToMembers,
                        isDark: _isDark,
                      ),
                      const SizedBox(width: AppSpace.m),
                      _StatCard(
                        icon: Icons.auto_stories_outlined,
                        label: l.sessions,
                        value: '${_activities.length}',
                        isDark: _isDark,
                      ),
                      const SizedBox(width: AppSpace.m),
                      _StatCard(
                        icon: Icons.flag_outlined,
                        label: l.activeChallenges,
                        value: '${_challenges.length}',
                        isDark: _isDark,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpace.xl),

                  // Current reading card
                  _buildCurrentReadingCard(context),
                  const SizedBox(height: AppSpace.xl),

                  // Challenges section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        l.activeChallenges,
                        style: GoogleFonts.cormorantGaramond(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: _isDark ? Colors.white : Colors.black,
                        ),
                      ),
                      if (_group!.isAdmin)
                        GestureDetector(
                          onTap: _navigateToCreateChallenge,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: _kSageGreen.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.add, color: _kSageGreen, size: 20),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpace.m),
                  if (_isLoadingChallenges)
                    const Center(child: CircularProgressIndicator())
                  else if (_challenges.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppSpace.l),
                      decoration: BoxDecoration(
                        color: _isDark ? AppColors.surfaceDark : _kCard,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.flag_outlined, size: 40,
                              color: (_isDark ? Colors.white : Colors.black).withValues(alpha: 0.3)),
                          const SizedBox(height: AppSpace.s),
                          Text(
                            l.noChallengeActive,
                            style: GoogleFonts.dmSans(
                              color: (_isDark ? Colors.white : Colors.black).withValues(alpha: 0.5),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    ..._challenges.map((challenge) => _ChallengeCard(
                          challenge: challenge,
                          onTap: () => _navigateToChallengeDetail(challenge),
                          isDark: _isDark,
                        )),
                  const SizedBox(height: AppSpace.xl),

                  // Activities section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        l.groupActivities,
                        style: GoogleFonts.cormorantGaramond(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: _isDark ? Colors.white : Colors.black,
                        ),
                      ),
                      GestureDetector(
                        onTap: _loadActivities,
                        child: Icon(Icons.refresh, size: 20,
                            color: (_isDark ? Colors.white : Colors.black).withValues(alpha: 0.4)),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpace.m),
                ],
              ),
            ),
          ),

          // Activities list
          _isLoadingActivities
              ? const SliverToBoxAdapter(
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.all(AppSpace.xl),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                )
              : _activities.isEmpty
                  ? SliverToBoxAdapter(
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(AppSpace.xl),
                          child: Column(
                            children: [
                              Icon(Icons.auto_stories_outlined, size: 64,
                                  color: (_isDark ? Colors.white : Colors.black).withValues(alpha: 0.3)),
                              const SizedBox(height: AppSpace.m),
                              Text(
                                l.noActivity,
                                style: GoogleFonts.dmSans(
                                  fontSize: 16,
                                  color: (_isDark ? Colors.white : Colors.black).withValues(alpha: 0.5),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                l.activitiesWillAppear,
                                style: GoogleFonts.dmSans(
                                  fontSize: 13,
                                  color: (_isDark ? Colors.white : Colors.black).withValues(alpha: 0.4),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  : SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpace.l),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final activity = _activities[index];
                            return _ActivityCard(activity: activity, isDark: _isDark);
                          },
                          childCount: _activities.length,
                        ),
                      ),
                    ),

          // Invite CTA button
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(AppSpace.l, AppSpace.l, AppSpace.l, AppSpace.xl),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [_kSageGreen, Color(0xFF5A8A7E)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ElevatedButton.icon(
                    onPressed: _navigateToMembers,
                    icon: const Icon(Icons.person_add_outlined, color: Colors.white),
                    label: Text(
                      l.inviteMembers,
                      style: GoogleFonts.dmSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHero(BuildContext context) {
    final l = AppLocalizations.of(context);
    return SizedBox(
      height: 200,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Cover image
          if (_group!.coverUrl != null)
            CachedNetworkImage(
              imageUrl: _group!.coverUrl!,
              fit: BoxFit.cover,
              memCacheWidth: (MediaQuery.of(context).size.width * MediaQuery.of(context).devicePixelRatio).toInt(),
              memCacheHeight: (200 * MediaQuery.of(context).devicePixelRatio).toInt(),
              placeholder: (context, url) => Container(
                color: _kSageGreen.withValues(alpha: 0.3),
                child: const Center(child: CircularProgressIndicator(color: Colors.white)),
              ),
              errorWidget: (context, url, error) => Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_kSageGreen, _kSageGreen.withValues(alpha: 0.6)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: const Icon(Icons.menu_book, size: 60, color: Colors.white38),
              ),
            )
          else
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [_kSageGreen, _kSageGreen.withValues(alpha: 0.6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: const Icon(Icons.menu_book, size: 60, color: Colors.white38),
            ),

          // Gradient overlay: transparent top → dark bottom
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.0, 0.5, 1.0],
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.15),
                  Colors.black.withValues(alpha: 0.65),
                ],
              ),
            ),
          ),

          // Back button top-left
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 12,
            child: _HeroButton(
              icon: Icons.arrow_back,
              onTap: () => Navigator.pop(context),
            ),
          ),

          // Settings / Leave button top-right
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            right: 12,
            child: _group!.isAdmin
                ? _HeroButton(
                    icon: Icons.settings_outlined,
                    onTap: _navigateToSettings,
                  )
                : _HeroButton(
                    icon: Icons.exit_to_app,
                    onTap: _leaveGroup,
                  ),
          ),

          // Club name + badges at bottom
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Badges row
                Row(
                  children: [
                    if (_group!.isPrivate)
                      _HeroBadge(label: l.privateTag, icon: Icons.lock),
                    if (_group!.isPrivate && _group!.isAdmin)
                      const SizedBox(width: 6),
                    if (_group!.isAdmin)
                      _HeroBadge(label: l.adminTag),
                  ],
                ),
                if (_group!.isPrivate || _group!.isAdmin) const SizedBox(height: 6),
                Text(
                  _group!.name,
                  style: GoogleFonts.cormorantGaramond(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentReadingCard(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l.currentReading,
          style: GoogleFonts.cormorantGaramond(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: _isDark ? Colors.white : Colors.black,
          ),
        ),
        const SizedBox(height: AppSpace.m),
        // Dashed empty state
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: (_isDark ? Colors.white : Colors.black).withValues(alpha: 0.15),
              width: 1.5,
              strokeAlign: BorderSide.strokeAlignInside,
            ),
          ),
          child: Column(
            children: [
              Icon(Icons.menu_book_outlined, size: 36,
                  color: (_isDark ? Colors.white : Colors.black).withValues(alpha: 0.25)),
              const SizedBox(height: AppSpace.s),
              Text(
                l.noCurrentReading,
                style: GoogleFonts.dmSans(
                  fontSize: 14,
                  color: (_isDark ? Colors.white : Colors.black).withValues(alpha: 0.4),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ──────────────────────────────────────────────
// Hero helper widgets
// ──────────────────────────────────────────────

class _HeroButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _HeroButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
        ),
      ),
    );
  }
}

class _HeroBadge extends StatelessWidget {
  final String label;
  final IconData? icon;

  const _HeroBadge({required this.label, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 10, color: Colors.white),
            const SizedBox(width: 3),
          ],
          Text(
            label,
            style: GoogleFonts.dmSans(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────
// Stat card
// ──────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;
  final bool isDark;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : _kCard,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: [
              Icon(icon, color: _kSageGreen, size: 24),
              const SizedBox(height: 6),
              Text(
                value,
                style: GoogleFonts.cormorantGaramond(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              Text(
                label,
                style: GoogleFonts.dmSans(
                  fontSize: 11,
                  color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.5),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────
// Activity card
// ──────────────────────────────────────────────

class _ActivityCard extends StatelessWidget {
  final GroupActivity activity;
  final bool isDark;

  const _ActivityCard({required this.activity, required this.isDark});

  String _getActivityDescription(BuildContext context) {
    final l = AppLocalizations.of(context);
    switch (activity.activityType) {
      case 'reading_session':
        final pages = activity.payload['pages_read'] ?? 0;
        final bookTitle = activity.payload['book_title'] ?? 'un livre';
        return l.readPagesOf(pages as int, bookTitle as String);
      case 'book_finished':
        final bookTitle = activity.payload['book_title'] ?? 'un livre';
        return l.finishedBook(bookTitle as String);
      case 'joined':
        return l.joinedGroup;
      case 'comment':
        return activity.payload['content'] ?? 'a laissé un commentaire';
      case 'book_recommendation':
        final bookTitle = activity.payload['book_title'] ?? 'un livre';
        return l.recommendsBook(bookTitle as String);
      default:
        return l.unknownActivity;
    }
  }

  String _formatDate(BuildContext context, DateTime date) {
    final l = AppLocalizations.of(context);
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 1) {
      return l.justNow;
    } else if (difference.inHours < 1) {
      return l.timeAgoMinutes(difference.inMinutes);
    } else if (difference.inHours < 24) {
      return l.timeAgoHours(difference.inHours);
    } else if (difference.inDays < 7) {
      return l.timeAgoDays(difference.inDays);
    } else {
      return DateFormat('dd MMM yyyy', 'fr_FR').format(date);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpace.m),
      padding: const EdgeInsets.all(AppSpace.m),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : _kCard,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: _kSageGreen.withValues(alpha: 0.15),
            backgroundImage: activity.userAvatar != null
                ? NetworkImage(activity.userAvatar!)
                : null,
            child: activity.userAvatar == null
                ? Text(
                    activity.displayName.substring(0, 1).toUpperCase(),
                    style: GoogleFonts.dmSans(
                      color: _kSageGreen,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: AppSpace.m),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    style: GoogleFonts.dmSans(
                      fontSize: 14,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                    children: [
                      TextSpan(
                        text: activity.displayName,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      TextSpan(
                        text: ' ${_getActivityDescription(context)}',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatDate(context, activity.createdAt),
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.45),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────
// Challenge card
// ──────────────────────────────────────────────

class _ChallengeCard extends StatelessWidget {
  final GroupChallenge challenge;
  final VoidCallback onTap;
  final bool isDark;

  const _ChallengeCard({
    required this.challenge,
    required this.onTap,
    required this.isDark,
  });

  IconData _getTypeIcon() {
    switch (challenge.type) {
      case 'read_book':
        return Icons.book;
      case 'read_pages':
        return Icons.menu_book;
      case 'read_daily':
        return Icons.calendar_today;
      default:
        return Icons.flag;
    }
  }

  String _getTimeRemaining(BuildContext context) {
    final l = AppLocalizations.of(context);
    final remaining = challenge.timeRemaining;
    if (remaining.isNegative) return l.expired;
    if (remaining.inDays > 0) return l.daysRemaining(remaining.inDays);
    if (remaining.inHours > 0) return l.hoursRemaining(remaining.inHours);
    return l.minutesRemaining(remaining.inMinutes);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpace.m),
        padding: const EdgeInsets.all(AppSpace.m),
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : _kCard,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _kSageGreen.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(_getTypeIcon(), color: _kSageGreen, size: 20),
            ),
            const SizedBox(width: AppSpace.m),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    challenge.title,
                    style: GoogleFonts.dmSans(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        l.memberCount(challenge.participantCount),
                        style: GoogleFonts.dmSans(
                          fontSize: 12,
                          color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.5),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: _kGold.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _getTimeRemaining(context),
                          style: GoogleFonts.dmSans(
                            fontSize: 10,
                            color: _kGold,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (challenge.userJoined) ...[
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: challenge.progressPercent,
                        minHeight: 4,
                        backgroundColor: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.1),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          challenge.userCompleted ? _kSageGreen : _kGold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(Icons.chevron_right,
                color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.3), size: 20),
          ],
        ),
      ),
    );
  }
}
