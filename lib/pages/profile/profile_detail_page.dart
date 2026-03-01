import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/app_theme.dart';
import '../../widgets/constrained_content.dart';
import '../../widgets/cached_profile_avatar.dart';
import '../friends/friends_page.dart';
import '../books/user_books_page.dart';
import 'settings_page.dart';
import '../../features/wrapped/monthly/monthly_wrapped_screen.dart';
import '../../features/wrapped/monthly/monthly_wrapped_data.dart';
import '../../features/wrapped/yearly/yearly_wrapped_screen.dart';
import '../../features/badges/widgets/anniversary_debug_page.dart';
import '../../features/badges/widgets/books_badge_debug_page.dart';

class ProfileDetailPage extends StatefulWidget {
  const ProfileDetailPage({super.key});

  @override
  State<ProfileDetailPage> createState() => _ProfileDetailPageState();
}

class _ProfileDetailPageState extends State<ProfileDetailPage> {
  final supabase = Supabase.instance.client;
  String _userName = 'Utilisateur';
  String? _avatarUrl;
  String _motivatedSince = 'Lecteur motivé';

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

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
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SettingsPage()),
              );
              _loadUserInfo();
            },
          ),
        ],
      ),
      body: ConstrainedContent(
        child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpace.l),
        child: Column(
          children: [
            // Avatar
            CachedProfileAvatar(
              imageUrl: _avatarUrl,
              userName: _userName,
              radius: 50,
              backgroundColor: Theme.of(context).brightness == Brightness.dark
                  ? AppColors.accentDark
                  : AppColors.accentLight,
              textColor: AppColors.primary,
              fontSize: 42,
            ),
            const SizedBox(height: AppSpace.m),

            // Username
            Text(
              _userName,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: AppSpace.xs),

            // Motivated since
            Text(
              _motivatedSince,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.6),
                    fontStyle: FontStyle.italic,
                  ),
            ),

            const SizedBox(height: AppSpace.xl),

            // Navigation buttons
            _navButton(
              context,
              label: 'Mes amis',
              icon: Icons.people_outline,
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const FriendsPage()),
              ),
            ),

            const SizedBox(height: AppSpace.m),

            _navButton(
              context,
              label: 'Ma bibliothèque',
              icon: Icons.library_books_outlined,
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const UserBooksPage()),
              ),
            ),

            const SizedBox(height: AppSpace.m),

            _navButton(
              context,
              label: 'Yearly Wrapped 2025',
              icon: Icons.auto_awesome_outlined,
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const YearlyWrappedScreen(year: 2025),
                ),
              ),
            ),

            // ── Debug-only buttons (tree-shaked en release grâce à kDebugMode) ──
            if (kDebugMode) ...[
              const SizedBox(height: AppSpace.m),
              _navButton(
                context,
                label: 'Monthly Wrapped (demo)',
                icon: Icons.calendar_month_outlined,
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => MonthlyWrappedScreen(
                      month: 10,
                      year: 2025,
                      demoData: MonthlyWrappedData.demo(),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpace.m),
              _navButton(
                context,
                label: 'Test Badges Anniversaire',
                icon: Icons.bug_report_outlined,
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const AnniversaryDebugPage(),
                  ),
                ),
              ),
              const SizedBox(height: AppSpace.m),
              _navButton(
                context,
                label: 'Test Badges Livres',
                icon: Icons.bug_report_outlined,
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const BooksBadgeDebugPage(),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      ),
    );
  }

  Widget _navButton(BuildContext context,
      {required String label, IconData? icon, required VoidCallback onPressed}) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        icon: icon != null
            ? Icon(icon, color: AppColors.primary)
            : const SizedBox(),
        label: Text(label,
            style:
                const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary),
          padding: const EdgeInsets.symmetric(vertical: AppSpace.m),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.l)),
        ),
        onPressed: onPressed,
      ),
    );
  }
}
