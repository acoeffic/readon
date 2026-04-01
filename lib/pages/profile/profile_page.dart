import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../l10n/app_localizations.dart';
import '../../theme/app_theme.dart';
import '../../widgets/constrained_content.dart';
import '../../widgets/cached_profile_avatar.dart';
import '../../services/avatar_cache_service.dart';
import 'settings_page.dart';
import 'profile_detail_page.dart';
import '../sessions/sessions_tab.dart';
import '../stats/stats_tab.dart';
import '../curated_lists/saved_lists_tab.dart';

class ProfilePage extends StatefulWidget {
  final bool showBack;
  const ProfilePage({super.key, this.showBack = false});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final supabase = Supabase.instance.client;
  final _savedListsKey = GlobalKey<SavedListsTabState>();
  String _userName = 'Utilisateur';
  String? _avatarUrl;
  String? _localAvatarPath;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_onTabChanged);
    _loadUserInfo();
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabController.index == 2 && !_tabController.indexIsChanging) {
      _savedListsKey.currentState?.refresh();
    }
  }

  Future<void> _loadUserInfo() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      // Charger immédiatement depuis le cache local
      final cache = AvatarCacheService.instance;
      final localPath = await cache.getLocalPath();
      if (localPath != null && mounted) {
        setState(() => _localAvatarPath = localPath);
      }

      final profile = await supabase
          .from('profiles')
          .select('display_name, avatar_url')
          .eq('id', user.id)
          .maybeSingle();

      final displayName = profile?['display_name'] as String?;
      final avatarUrl = profile?['avatar_url'] as String?;

      // Mettre à jour le cache local si l'URL distante a changé
      if (avatarUrl != null && avatarUrl.isNotEmpty) {
        final cachedUrl = await cache.getCachedUrl();
        if (cachedUrl != avatarUrl) {
          await cache.saveFromUrl(avatarUrl);
          final newPath = await cache.getLocalPath();
          if (mounted && newPath != null) {
            setState(() => _localAvatarPath = newPath);
          }
        }
      }

      if (mounted) {
        setState(() {
          _userName =
              displayName ?? user.email?.split('@').first ?? 'Utilisateur';
          _avatarUrl = avatarUrl;
        });
      }
    } catch (e) {
      debugPrint('Erreur _loadUserInfo: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: ConstrainedContent(
          child: Column(
          children: [
            // --- HEADER COMPACT ---
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpace.m,
                vertical: AppSpace.s,
              ),
              child: Row(
                children: [
                  if (widget.showBack)
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () => Navigator.of(context).pop(),
                    )
                  else
                    const SizedBox(width: 48),

                  const Spacer(),

                  // Avatar cliquable -> ProfileDetailPage
                  GestureDetector(
                    onTap: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => const ProfileDetailPage()),
                      );
                      _loadUserInfo();
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CachedProfileAvatar(
                          imageUrl: _avatarUrl,
                          localFilePath: _localAvatarPath,
                          userName: _userName,
                          radius: 18,
                          backgroundColor:
                              Theme.of(context).brightness == Brightness.dark
                                  ? AppColors.accentDark
                                  : AppColors.accentLight,
                          textColor: AppColors.primary,
                          fontSize: 14,
                        ),
                        const SizedBox(width: AppSpace.s),
                        Text(
                          _userName,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),

                  const Spacer(),

                  IconButton(
                    icon: const Icon(Icons.settings_outlined),
                    onPressed: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => const SettingsPage()),
                      );
                      _loadUserInfo();
                    },
                  ),
                ],
              ),
            ),

            // --- TAB BAR ---
            TabBar(
              controller: _tabController,
              indicatorColor: AppColors.primary,
              labelColor: AppColors.primary,
              unselectedLabelColor:
                  Theme.of(context).textTheme.bodyMedium?.color,
              tabAlignment: TabAlignment.fill,
              tabs: [
                Tab(text: l10n.mySessions),
                Tab(text: l10n.myStatistics),
                Tab(text: l10n.myLists),
              ],
            ),

            // --- TAB CONTENT ---
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  const SessionsTab(),
                  const StatsTab(),
                  SavedListsTab(key: _savedListsKey),
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
