import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../theme/app_theme.dart';
import '../../profile/profile_page.dart';
import '../../friends/search_users_page.dart';

class FeedHeader extends StatefulWidget {
  const FeedHeader({super.key});

  @override
  State<FeedHeader> createState() => _FeedHeaderState();
}

class _FeedHeaderState extends State<FeedHeader> {
  final supabase = Supabase.instance.client;
  String? _avatarUrl;
  String _userName = '';

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final profile = await supabase
          .from('profiles')
          .select('avatar_url, display_name')
          .eq('id', user.id)
          .maybeSingle();

      if (mounted) {
        setState(() {
          _avatarUrl = profile?['avatar_url'] as String?;
          _userName = profile?['display_name'] as String? ?? 
                      user.email?.split('@').first ?? 
                      'Utilisateur';
        });
      }
    } catch (e) {
      print('Erreur _loadUserProfile: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.primary,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.l,
        vertical: AppSpace.s,
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                GestureDetector(
                  onTap: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const ProfilePage(showBack: true),
                      ),
                    );
                    // Recharger le profil après retour des settings
                    _loadUserProfile();
                  },
                  child: CircleAvatar(
                    radius: 20,
                    backgroundColor: AppColors.white,
                    backgroundImage: _avatarUrl != null && _avatarUrl!.isNotEmpty
                        ? NetworkImage(_avatarUrl!)
                        : null,
                    child: _avatarUrl == null || _avatarUrl!.isEmpty
                        ? Text(
                            _userName.isNotEmpty ? _userName[0].toUpperCase() : '?',
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          )
                        : null,
                  ),
                ),
                const SizedBox(width: AppSpace.m),
                IconButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const SearchUsersPage(),
                      ),
                    );
                  },
                  icon: const Icon(
                    Icons.search,
                    color: AppColors.white,
                    size: 28,
                  ),
                ),
              ],
            ),
            Text(
              'Accueil',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            IconButton(
              onPressed: () {},
              icon: const Icon(
                Icons.notifications_none,
                color: AppColors.white,
                size: 28,
              ),
            ),
          ],
        ),
      ),
    );
  }
}