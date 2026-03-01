import 'dart:math';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/responsive.dart';
import '../../profile/profile_page.dart';
import '../../friends/search_users_page.dart';
import '../../notifications/notifications_page.dart';
import '../../../services/notifications_service.dart';

class FeedHeader extends StatefulWidget {
  const FeedHeader({super.key});

  @override
  State<FeedHeader> createState() => _FeedHeaderState();
}

class _FeedHeaderState extends State<FeedHeader> with TickerProviderStateMixin {
  final supabase = Supabase.instance.client;
  final notificationsService = NotificationsService();
  String? _avatarUrl;
  String _userName = '';

  late AnimationController _floatController;
  late AnimationController _sparkleController;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();

    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat(reverse: true);

    _sparkleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _floatController.dispose();
    _sparkleController.dispose();
    super.dispose();
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
      debugPrint('Erreur _loadUserProfile: $e');
    }
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 18) {
      return 'BONJOUR';
    } else {
      return 'BONSOIR';
    }
  }

  String _getSubtitle() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 18) {
      return 'Prêt à lire aujourd\'hui ?';
    } else {
      return 'Une soirée lecture ?';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.feedHeader,
      ),
      clipBehavior: Clip.hardEdge,
      child: Stack(
        children: [
            // Floating circles
            ..._buildFloatingCircles(),
            // Sparkles
            ..._buildSparkles(),
            // Wave shapes at bottom
            Positioned(
              bottom: -10,
              left: 0,
              right: 0,
              child: CustomPaint(
                size: const Size(double.infinity, 50),
                painter: _WavePainter(opacity: 0.1),
              ),
            ),
            Positioned(
              bottom: -5,
              left: 0,
              right: 0,
              child: CustomPaint(
                size: const Size(double.infinity, 50),
                painter: _WavePainter(opacity: 0.15, offset: 0.5),
              ),
            ),
            // Content
            Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: Responsive.isTablet(context)
                      ? Responsive.contentMaxWidth
                      : double.infinity,
                ),
                child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Top row: greeting + avatar
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _getGreeting(),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Colors.white70,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _userName,
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                letterSpacing: -0.5,
                                height: 1.1,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _getSubtitle(),
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.white70,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Avatar
                      GestureDetector(
                        onTap: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const ProfilePage(showBack: true),
                            ),
                          );
                          _loadUserProfile();
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.3),
                              width: 3,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.15),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(13),
                            child: Container(
                              width: 48,
                              height: 48,
                              color: Colors.white,
                              child: _avatarUrl != null && _avatarUrl!.isNotEmpty
                                  ? CachedNetworkImage(
                                      imageUrl: _avatarUrl!,
                                      fit: BoxFit.cover,
                                      placeholder: (context, url) => Center(
                                        child: Text(
                                          _userName.isNotEmpty ? _userName[0].toUpperCase() : '?',
                                          style: const TextStyle(
                                            color: AppColors.primary,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 20,
                                          ),
                                        ),
                                      ),
                                      errorWidget: (context, url, error) => Center(
                                        child: Text(
                                          _userName.isNotEmpty ? _userName[0].toUpperCase() : '?',
                                          style: const TextStyle(
                                            color: AppColors.primary,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 20,
                                          ),
                                        ),
                                      ),
                                    )
                                  : Center(
                                      child: Text(
                                        _userName.isNotEmpty
                                            ? _userName[0].toUpperCase()
                                            : '?',
                                        style: const TextStyle(
                                          color: AppColors.primary,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 20,
                                        ),
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Action bar
                  Row(
                    children: [
                      Expanded(
                        child: _ActionChip(
                          icon: Icons.search,
                          label: 'Rechercher',
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const SearchUsersPage(),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: StreamBuilder<int>(
                          stream: notificationsService.watchUnreadCount(),
                          builder: (context, snapshot) {
                            final unreadCount = snapshot.data ?? 0;
                            return _ActionChip(
                              icon: Icons.mail_outline_rounded,
                              label: 'Messages',
                              badgeCount: unreadCount,
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => const NotificationsPage(),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            ),
            ),
        ],
      ),
    );
  }

  List<Widget> _buildFloatingCircles() {
    return [
      Positioned(
        top: -40,
        right: -20,
        child: AnimatedBuilder(
          animation: _floatController,
          builder: (context, child) {
            final value = _floatController.value;
            return Transform.translate(
              offset: Offset(0, -20 * sin(value * pi)),
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
            );
          },
        ),
      ),
      Positioned(
        top: 40,
        left: -30,
        child: AnimatedBuilder(
          animation: _floatController,
          builder: (context, child) {
            final value = ((_floatController.value + 0.33) % 1.0);
            return Transform.translate(
              offset: Offset(0, -20 * sin(value * pi)),
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
            );
          },
        ),
      ),
      Positioned(
        bottom: 20,
        right: 60,
        child: AnimatedBuilder(
          animation: _floatController,
          builder: (context, child) {
            final value = ((_floatController.value + 0.66) % 1.0);
            return Transform.translate(
              offset: Offset(0, -20 * sin(value * pi)),
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
            );
          },
        ),
      ),
    ];
  }

  List<Widget> _buildSparkles() {
    final positions = [
      const Offset(40, 50),
      const Offset(250, 60),
      const Offset(100, 110),
      const Offset(200, 35),
    ];

    return List.generate(positions.length, (index) {
      return Positioned(
        left: positions[index].dx,
        top: positions[index].dy,
        child: AnimatedBuilder(
          animation: _sparkleController,
          builder: (context, child) {
            final phase = ((_sparkleController.value + index * 0.25) % 1.0);
            final opacity = sin(phase * pi);
            final scale = sin(phase * pi);
            return Transform.scale(
              scale: scale,
              child: Opacity(
                opacity: opacity.clamp(0.0, 1.0),
                child: Container(
                  width: 3,
                  height: 3,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          },
        ),
      );
    });
  }
}

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final int badgeCount;

  const _ActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
    this.badgeCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Container(
          height: 40,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            color: Colors.white.withValues(alpha: 0.18),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Stack(
            children: [
              Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, size: 18, color: Colors.white),
                    const SizedBox(width: 8),
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              if (badgeCount > 0)
                Positioned(
                  top: 4,
                  right: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.red.withValues(alpha: 0.3),
                          blurRadius: 4,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        badgeCount > 99 ? '99+' : '$badgeCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WavePainter extends CustomPainter {
  final double opacity;
  final double offset;

  _WavePainter({this.opacity = 0.1, this.offset = 0.0});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: opacity)
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(0, size.height * (0.5 + offset * 0.2));

    path.cubicTo(
      size.width * 0.25,
      size.height * (0.8 + offset * 0.1),
      size.width * 0.5,
      size.height * (0.2 + offset * 0.1),
      size.width * 0.75,
      size.height * (0.5 + offset * 0.2),
    );
    path.cubicTo(
      size.width * 0.875,
      size.height * (0.65 + offset * 0.1),
      size.width,
      size.height * (0.35 + offset * 0.1),
      size.width,
      size.height * (0.35 + offset * 0.1),
    );
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _WavePainter oldDelegate) =>
      oldDelegate.opacity != opacity || oldDelegate.offset != offset;
}
