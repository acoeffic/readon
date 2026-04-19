import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/constrained_content.dart';
import '../../models/reading_group.dart';
import '../../models/feature_flags.dart';
import '../../services/groups_service.dart';
import '../../providers/subscription_provider.dart';
import '../../pages/profile/upgrade_page.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'create_group_page.dart';
import 'group_detail_page.dart';

const _kBg = Color(0xFFFAF3E8);
const _kCard = Color(0xFFF0E8D8);
const _kSageGreen = Color(0xFF6B988D);

class GroupsPage extends StatefulWidget {
  const GroupsPage({super.key});

  @override
  State<GroupsPage> createState() => _GroupsPageState();
}

class _GroupsPageState extends State<GroupsPage> {
  final GroupsService _groupsService = GroupsService();

  List<ReadingGroup> _myGroups = [];
  List<ReadingGroup> _publicGroups = [];
  bool _isLoadingMyGroups = true;
  bool _isLoadingPublic = true;
  int _selectedTab = 0; // 0 = Mes clubs, 1 = Découvrir

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    await Future.wait([
      _loadMyGroups(),
      _loadPublicGroups(),
    ]);
  }

  Future<void> _loadMyGroups() async {
    setState(() => _isLoadingMyGroups = true);
    try {
      final groups = await _groupsService.getUserGroups();
      setState(() {
        _myGroups = groups;
        _isLoadingMyGroups = false;
      });
    } catch (e) {
      setState(() => _isLoadingMyGroups = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    }
  }

  Future<void> _loadPublicGroups() async {
    setState(() => _isLoadingPublic = true);
    try {
      final groups = await _groupsService.getPublicGroups();
      setState(() {
        _publicGroups = groups;
        _isLoadingPublic = false;
      });
    } catch (e) {
      setState(() => _isLoadingPublic = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    }
  }

  void _navigateToCreateGroup() async {
    final isPremium = context.read<SubscriptionProvider>().isPremium;
    if (!isPremium && _myGroups.length >= FeatureFlags.maxFreeGroups) {
      _showGroupLimitDialog();
      return;
    }

    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CreateGroupPage()),
    );

    if (result == true) {
      _loadMyGroups();
    }
  }

  void _showGroupLimitDialog() {
    final l = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.l),
        ),
        title: Text(l.limitReached),
        content: Text(
          l.groupLimitMessage(FeatureFlags.maxFreeGroups),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l.cancel),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const UpgradePage()),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: Text(l.becomePremium),
          ),
        ],
      ),
    );
  }

  Future<void> _navigateToGroupDetail(ReadingGroup group) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GroupDetailPage(groupId: group.id),
      ),
    );
    // Refresh the list when returning (cover image may have changed).
    if (mounted) _loadMyGroups();
  }

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final bg = _isDark ? AppColors.bgDark : _kBg;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpace.l, AppSpace.l, AppSpace.l, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.clubSubtitle.toUpperCase(),
                    style: GoogleFonts.dmSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.5,
                      color: _kSageGreen,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l.readingClubs,
                    style: GoogleFonts.cormorantGaramond(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: _isDark ? Colors.white : Colors.black,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpace.l),

            // Pill toggle
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.l),
              child: Container(
                decoration: BoxDecoration(
                  color: _isDark ? AppColors.surfaceDark : _kCard,
                  borderRadius: BorderRadius.circular(24),
                ),
                padding: const EdgeInsets.all(4),
                child: Row(
                  children: [
                    _buildPillTab(l.myClubs, 0),
                    _buildPillTab(l.discover, 1),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpace.m),

            // Content
            Expanded(
              child: _selectedTab == 0
                  ? _buildMyGroupsTab()
                  : _buildPublicGroupsTab(),
            ),

            // Bottom create button
            Padding(
              padding: const EdgeInsets.fromLTRB(AppSpace.l, AppSpace.s, AppSpace.l, AppSpace.m),
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
                    onPressed: _navigateToCreateGroup,
                    icon: const Icon(Icons.add, color: Colors.white),
                    label: Text(
                      l.createClub,
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
          ],
        ),
      ),
    );
  }

  Widget _buildPillTab(String label, int index) {
    final isActive = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => _selectedTab = index);
          if (index == 1) _loadPublicGroups();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isActive ? _kSageGreen : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.dmSans(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isActive
                    ? Colors.white
                    : (_isDark ? Colors.white70 : Colors.black54),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMyGroupsTab() {
    final l = AppLocalizations.of(context);
    if (_isLoadingMyGroups) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_myGroups.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.group_off, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: AppSpace.m),
            Text(
              l.noGroups,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpace.s),
            Text(
              l.createOrJoinGroup,
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadMyGroups,
      child: ConstrainedContent(
        child: ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.l),
          itemCount: _myGroups.length,
          itemBuilder: (context, index) {
            final group = _myGroups[index];
            return _GroupCard(
              group: group,
              onTap: () => _navigateToGroupDetail(group),
              isDark: _isDark,
            );
          },
        ),
      ),
    );
  }

  Widget _buildPublicGroupsTab() {
    final l = AppLocalizations.of(context);
    if (_isLoadingPublic) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_publicGroups.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.public_off, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: AppSpace.m),
            Text(
              l.noPublicGroups,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpace.s),
            Text(
              l.beFirstToCreate,
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadPublicGroups,
      child: ConstrainedContent(
        child: ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.l),
          itemCount: _publicGroups.length,
          itemBuilder: (context, index) {
            final group = _publicGroups[index];
            return _GroupCard(
              group: group,
              onTap: () => _navigateToGroupDetail(group),
              showCreator: true,
              isDark: _isDark,
            );
          },
        ),
      ),
    );
  }
}

class _GroupCard extends StatelessWidget {
  final ReadingGroup group;
  final VoidCallback onTap;
  final bool showCreator;
  final bool isDark;

  const _GroupCard({
    required this.group,
    required this.onTap,
    this.showCreator = false,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final cardColor = isDark ? AppColors.surfaceDark : Colors.white;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.m),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(16),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Cover image band
              SizedBox(
                height: 100,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Background image or gradient
                    if (group.coverUrl != null)
                      CachedNetworkImage(
                        imageUrl: group.coverUrl!,
                        fit: BoxFit.cover,
                        memCacheWidth: 600,
                        memCacheHeight: 240,
                        errorWidget: (_, __, ___) => Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                _kSageGreen,
                                _kSageGreen.withValues(alpha: 0.7),
                              ],
                            ),
                          ),
                        ),
                      )
                    else
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              _kSageGreen,
                              _kSageGreen.withValues(alpha: 0.7),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: const Center(
                          child: Icon(Icons.menu_book, color: Colors.white38, size: 32),
                        ),
                      ),

                    // Dark gradient overlay
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.1),
                            Colors.black.withValues(alpha: 0.5),
                          ],
                        ),
                      ),
                    ),

                    // Badges bottom-left
                    Positioned(
                      bottom: 8,
                      left: 10,
                      child: Row(
                        children: [
                          if (group.isPrivate)
                            _Badge(
                              label: l.privateTag,
                              icon: Icons.lock,
                              color: const Color(0xFFC6A85A),
                            ),
                          if (group.isPrivate && group.isAdmin)
                            const SizedBox(width: 6),
                          if (group.isAdmin)
                            _Badge(
                              label: l.adminTag,
                              color: _kSageGreen,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // White section with club info
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      group.name,
                      style: GoogleFonts.dmSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.people_outline, size: 14, color: Colors.grey.shade500),
                        const SizedBox(width: 4),
                        Text(
                          l.memberCount(group.memberCount ?? 0),
                          style: GoogleFonts.dmSans(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                          ),
                        ),
                        if (showCreator && group.creatorName != null) ...[
                          const SizedBox(width: 10),
                          Icon(Icons.person_outline, size: 14, color: Colors.grey.shade500),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              l.byCreator(group.creatorName!),
                              style: GoogleFonts.dmSans(
                                fontSize: 12,
                                color: Colors.grey.shade500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color color;

  const _Badge({required this.label, this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(10),
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
