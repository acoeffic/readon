import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/app_theme.dart';
import '../../widgets/progress_bar.dart';
import '../../widgets/cached_profile_avatar.dart';
import '../friends/friends_page.dart';
import 'settings_page.dart';
import '../books/user_books_page.dart';
import '../../services/badges_service.dart';
import '../../services/goals_service.dart';
import '../../models/reading_goal.dart';
import '../../widgets/badges_grid.dart';
import 'all_badges_page.dart';
import 'reading_goals_page.dart';

class ProfilePage extends StatefulWidget {
  final bool showBack;
  const ProfilePage({super.key, this.showBack = false});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final supabase = Supabase.instance.client;
  final badgesService = BadgesService();
  final GoalsService _goalsService = GoalsService();
  String _motivatedSince = 'Lecteur motivé';
  String _userName = 'Utilisateur';
  String? _avatarUrl;
  List<UserBadge> _badges = [];
  bool _loadingBadges = true;
  ReadingGoal? _primaryGoal;
  bool _loadingGoal = true;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
    _loadBadges();
    _loadPrimaryGoal();
  }

  Future<void> _loadUserInfo() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      // Récupérer display_name et avatar_url
      final profile = await supabase
          .from('profiles')
          .select('display_name, avatar_url')
          .eq('id', user.id)
          .maybeSingle();

      final displayName = profile?['display_name'] as String?;
      final avatarUrl = profile?['avatar_url'] as String?;
      
      setState(() {
        _userName = displayName ?? user.email?.split('@').first ?? 'Utilisateur';
        _avatarUrl = avatarUrl;
        _motivatedSince = _getMotivatedSince(DateTime.parse(user.createdAt));
      });
    } catch (e) {
      debugPrint('Erreur _loadUserInfo: $e');
    }
  }

  Future<void> _loadBadges() async {
    setState(() => _loadingBadges = true);
    try {
      final badges = await badgesService.getUserBadges();
      setState(() {
        _badges = badges;
        _loadingBadges = false;
      });
    } catch (e) {
      debugPrint('Erreur _loadBadges: $e');
      setState(() => _loadingBadges = false);
    }
  }

  Future<void> _loadPrimaryGoal() async {
    setState(() => _loadingGoal = true);
    try {
      final goal = await _goalsService.getPrimaryGoal();
      if (mounted) {
        setState(() {
          _primaryGoal = goal;
          _loadingGoal = false;
        });
      }
    } catch (e) {
      debugPrint('Erreur _loadPrimaryGoal: $e');
      if (mounted) setState(() => _loadingGoal = false);
    }
  }

  String _getMotivatedSince(DateTime createdAt) {
    final now = DateTime.now();
    final difference = now.difference(createdAt);
    
    if (difference.inDays < 7) {
      return 'Lecteur motivé depuis ${difference.inDays} jour${difference.inDays > 1 ? 's' : ''}';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return 'Lecteur motivé depuis $weeks semaine${weeks > 1 ? 's' : ''}';
    } else if (difference.inDays < 365) {
      final months = (difference.inDays / 30).floor();
      return 'Lecteur motivé depuis $months mois';
    } else {
      final years = (difference.inDays / 365).floor();
      final months = ((difference.inDays % 365) / 30).floor();
      if (months > 0) {
        return 'Lecteur motivé depuis $years an${years > 1 ? 's' : ''} et $months mois';
      }
      return 'Lecteur motivé depuis $years an${years > 1 ? 's' : ''}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpace.l),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- HEADER ---
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  widget.showBack
                      ? IconButton(
                          icon: const Icon(Icons.arrow_back),
                          onPressed: () => Navigator.of(context).pop(),
                        )
                      : const SizedBox(width: 48),

                  Column(
                    children: [
                      // Avatar avec photo ou initiale (avec cache)
                      CachedProfileAvatar(
                        imageUrl: _avatarUrl,
                        userName: _userName,
                        radius: 41,
                        backgroundColor: Theme.of(context).brightness == Brightness.dark
                            ? AppColors.accentDark
                            : AppColors.accentLight,
                        textColor: AppColors.primary,
                        fontSize: 36,
                      ),
                      const SizedBox(height: AppSpace.s),
                      Text(
                        _userName,
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: AppSpace.xs),
                      Text(
                        _motivatedSince,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),

                  IconButton(
                    icon: const Icon(Icons.settings_outlined),
                    onPressed: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const SettingsPage()),
                      );
                      // Recharger les infos après retour des settings
                      _loadUserInfo();
                    },
                  ),
                ],
              ),

              const SizedBox(height: AppSpace.l),

              // --- BADGES ---
              if (_loadingBadges)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.all(AppSpace.l),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(AppRadius.l),
                  ),
                  child: BadgesGrid(
                    badges: _badges,
                    onViewAll: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const AllBadgesPage()),
                      );
                    },
                  ),
                ),

              const SizedBox(height: AppSpace.l),

              // --- NAVIGATION ---
              _navButton(
                context,
                label: 'Mes amis',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const FriendsPage()),
                ),
              ),

              const SizedBox(height: AppSpace.m),

              _navButton(
                context,
                label: 'Ma bibliothèque',
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const UserBooksPage()),
                ),
              ),

              const SizedBox(height: AppSpace.l),

              // --- OBJECTIF ---
              Text(
                'Ton objectif ${DateTime.now().year}',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: 22),
              ),
              const SizedBox(height: AppSpace.s),

              if (_loadingGoal)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(AppSpace.l),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (_primaryGoal != null)
                Container(
                  padding: const EdgeInsets.all(AppSpace.m),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(AppRadius.l),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${_primaryGoal!.goalType.emoji} ${_primaryGoal!.progressText}'),
                            const SizedBox(height: AppSpace.s),
                            ProgressBar(value: _primaryGoal!.progressPercent),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpace.m),
                      OutlinedButton(
                        onPressed: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const ReadingGoalsPage()),
                          );
                          _loadPrimaryGoal();
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(color: AppColors.primary),
                        ),
                        child: const Text('Modifier'),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.all(AppSpace.m),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(AppRadius.l),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Aucun objectif defini',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const ReadingGoalsPage()),
                          );
                          _loadPrimaryGoal();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Definir'),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: AppSpace.l),

            ],
          ),
        ),
      ),
    );
  }

  Widget _navButton(BuildContext context, {required String label, IconData? icon, required VoidCallback onPressed}) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        icon: icon != null ? Icon(icon, color: AppColors.primary) : const SizedBox(),
        label: Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary),
          padding: const EdgeInsets.symmetric(vertical: AppSpace.m),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.l)),
        ),
        onPressed: onPressed,
      ),
    );
  }
}