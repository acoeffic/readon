import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../widgets/require_account_sheet.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/responsive.dart';
import '../../../services/avatar_cache_service.dart';
import '../../../services/flow_service.dart';
import '../../../services/goals_service.dart';
import '../../../services/notifications_service.dart';
import '../../../models/reading_flow.dart';
import '../../../models/reading_goal.dart';
import '../../profile/profile_page.dart';
import '../../friends/search_users_page.dart';
import '../../notifications/notifications_page.dart';

class FeedHeader extends StatefulWidget {
  const FeedHeader({super.key});

  @override
  State<FeedHeader> createState() => _FeedHeaderState();
}

class _FeedHeaderState extends State<FeedHeader>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  final supabase = Supabase.instance.client;
  final notificationsService = NotificationsService();
  String? _avatarUrl;
  String? _localAvatarPath;
  String _userName = '';

  // Stats
  int _currentFlow = 0;
  int? _dailyGoalTarget; // minutes/jour, null si pas d'objectif actif
  int _todayMinutes = 0;
  int _weekPages = 0;

  late AnimationController _floatController;
  late AnimationController _sparkleController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadUserProfile();
    _loadStats();

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
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadUserProfile();
      _loadStats();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _floatController.dispose();
    _sparkleController.dispose();
    super.dispose();
  }

  Future<void> _loadUserProfile() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final cache = AvatarCacheService.instance;
      final localPath = await cache.getLocalPath();
      if (localPath != null && mounted) {
        setState(() => _localAvatarPath = localPath);
      }

      final profile = await supabase
          .from('profiles')
          .select('avatar_url, display_name')
          .eq('id', user.id)
          .maybeSingle();

      final remoteUrl = profile?['avatar_url'] as String?;

      if (remoteUrl != null && remoteUrl.isNotEmpty) {
        final cachedUrl = await cache.getCachedUrl();
        if (cachedUrl != remoteUrl) {
          await cache.saveFromUrl(remoteUrl);
          final newPath = await cache.getLocalPath();
          if (mounted && newPath != null) {
            setState(() => _localAvatarPath = newPath);
          }
        }
      }

      if (mounted) {
        setState(() {
          _avatarUrl = remoteUrl;
          _userName = profile?['display_name'] as String? ??
              user.email?.split('@').first ??
              'Utilisateur';
        });
      }
    } catch (e) {
      debugPrint('Erreur _loadUserProfile: $e');
    }
  }

  Future<void> _loadStats() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final results = await Future.wait([
        FlowService().getUserFlow(),
        GoalsService().getActiveGoalsWithProgress(),
        _fetchTodayMinutes(user.id),
        _fetchWeekPages(user.id),
      ]);

      if (!mounted) return;

      final flow = results[0] as ReadingFlow;
      final goals = results[1] as List<ReadingGoal>;
      ReadingGoal? dailyGoal;
      for (final g in goals) {
        if (g.goalType == GoalType.minutesPerDay) {
          dailyGoal = g;
          break;
        }
      }

      setState(() {
        _currentFlow = flow.currentFlow;
        _dailyGoalTarget = dailyGoal?.targetValue;
        _todayMinutes = results[2] as int;
        _weekPages = results[3] as int;
      });
    } catch (e) {
      debugPrint('Erreur _loadStats: $e');
    }
  }

  Future<int> _fetchTodayMinutes(String userId) async {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final response = await supabase
        .from('reading_sessions')
        .select('start_time, end_time')
        .eq('user_id', userId)
        .not('end_time', 'is', null)
        .gte('start_time', todayStart.toUtc().toIso8601String());

    int total = 0;
    for (final s in (response as List)) {
      final start = DateTime.parse(s['start_time'] as String);
      final end = DateTime.parse(s['end_time'] as String);
      final m = end.difference(start).inMinutes;
      if (m > 0) total += m;
    }
    return total;
  }

  Future<int> _fetchWeekPages(String userId) async {
    final now = DateTime.now();
    // Semaine ISO : lundi 00:00 → maintenant.
    final monday =
        DateTime(now.year, now.month, now.day - (now.weekday - 1));
    final response = await supabase
        .from('reading_sessions')
        .select('start_page, end_page')
        .eq('user_id', userId)
        .not('end_time', 'is', null)
        .gte('start_time', monday.toUtc().toIso8601String());

    int total = 0;
    for (final s in (response as List)) {
      final sp = s['start_page'] as int?;
      final ep = s['end_page'] as int?;
      if (sp != null && ep != null && ep > sp) total += (ep - sp);
    }
    return total;
  }

  Widget _buildInitial() {
    return Center(
      child: Text(
        _userName.isNotEmpty ? _userName[0].toUpperCase() : '?',
        style: const TextStyle(
          color: AppColors.primary,
          fontWeight: FontWeight.w700,
          fontSize: 18,
        ),
      ),
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    return (hour >= 5 && hour < 18) ? 'BONJOUR' : 'BONSOIR';
  }

  // ── Top row actions ──────────────────────────────────────────────

  Future<void> _onSearchTap() async {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SearchUsersPage()),
    );
  }

  Future<void> _onMessagesTap() async {
    if (Supabase.instance.client.auth.currentUser == null) {
      await showRequireAccountSheet(context);
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const NotificationsPage()),
    );
  }

  Future<void> _onAvatarTap() async {
    if (Supabase.instance.client.auth.currentUser == null) {
      await showRequireAccountSheet(context);
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ProfilePage(showBack: true)),
    );
    _loadUserProfile();
    _loadStats();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(color: AppColors.feedHeader),
      clipBehavior: Clip.hardEdge,
      child: Stack(
        children: [
          ..._buildFloatingCircles(),
          ..._buildSparkles(),
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
          Center(
            heightFactor: 1.0,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: Responsive.isTablet(context)
                    ? Responsive.contentMaxWidth
                    : double.infinity,
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildTopRow(),
                    const SizedBox(height: 24),
                    _buildStatsRow(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Top row (greeting + name + circle actions) ────────────────────

  Widget _buildTopRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _getGreeting(),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white70,
                  letterSpacing: 1.4,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _userName.isEmpty ? '…' : _userName,
                style: GoogleFonts.libreBaskerville(
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  height: 1.1,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        _CircleButton(icon: Icons.search, onTap: _onSearchTap),
        const SizedBox(width: 10),
        StreamBuilder<int>(
          stream: notificationsService.watchUnreadCount(),
          builder: (context, snapshot) {
            return _CircleButton(
              icon: Icons.mail_outline_rounded,
              badgeCount: snapshot.data ?? 0,
              onTap: _onMessagesTap,
            );
          },
        ),
        const SizedBox(width: 10),
        _AvatarCircle(
          localPath: _localAvatarPath,
          remoteUrl: _avatarUrl,
          fallback: _buildInitial(),
          onTap: _onAvatarTap,
        ),
      ],
    );
  }

  // ── Stats row (série / aujourd'hui / cette semaine) ───────────────

  Widget _buildStatsRow() {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: _buildSerieStat()),
          _verticalDivider(),
          Expanded(child: _buildTodayStat()),
          _verticalDivider(),
          Expanded(child: _buildWeekStat()),
        ],
      ),
    );
  }

  Widget _verticalDivider() {
    return Container(
      width: 1,
      margin: const EdgeInsets.symmetric(horizontal: 12),
      color: Colors.white.withValues(alpha: 0.15),
    );
  }

  Widget _statLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: Colors.white60,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _statBigNumber(String value, {Color? color}) {
    return Text(
      value,
      style: GoogleFonts.libreBaskerville(
        fontSize: 26,
        fontWeight: FontWeight.w700,
        color: color ?? Colors.white,
        height: 1.0,
      ),
    );
  }

  Widget _statSuffix(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 3),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          color: Colors.white70,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildSerieStat() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _statLabel('SÉRIE'),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 2, right: 4),
              child: Text('🔥', style: TextStyle(fontSize: 18)),
            ),
            _statBigNumber(
              '$_currentFlow',
              color: const Color(0xFFE8A088),
            ),
            _statSuffix(_currentFlow == 1 ? 'jour' : 'jours'),
          ],
        ),
      ],
    );
  }

  Widget _buildTodayStat() {
    final hasGoal = _dailyGoalTarget != null && _dailyGoalTarget! > 0;
    final progress = hasGoal
        ? (_todayMinutes / _dailyGoalTarget!).clamp(0.0, 1.0)
        : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _statLabel('AUJOURD\'HUI'),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _statBigNumber('$_todayMinutes'),
            if (hasGoal)
              _statSuffix('/ $_dailyGoalTarget min')
            else
              _statSuffix('min'),
          ],
        ),
        if (hasGoal) ...[
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 4,
              backgroundColor: Colors.white.withValues(alpha: 0.15),
              valueColor: const AlwaysStoppedAnimation<Color>(
                Color(0xFFB8D5C4),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildWeekStat() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _statLabel('CETTE SEMAINE'),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _statBigNumber('$_weekPages'),
            _statSuffix('pages'),
          ],
        ),
      ],
    );
  }

  // ── Animated background ───────────────────────────────────────────

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

// ─────────────────────────────────────────────────────────────────────
// Sub-widgets
// ─────────────────────────────────────────────────────────────────────

class _CircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final int badgeCount;

  const _CircleButton({
    required this.icon,
    required this.onTap,
    this.badgeCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.15),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.18),
                  width: 1,
                ),
              ),
              child: Icon(icon, size: 20, color: Colors.white),
            ),
            if (badgeCount > 0)
              Positioned(
                top: -2,
                right: -2,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.feedHeader, width: 2),
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
    );
  }
}

class _AvatarCircle extends StatelessWidget {
  final String? localPath;
  final String? remoteUrl;
  final Widget fallback;
  final VoidCallback onTap;

  const _AvatarCircle({
    required this.localPath,
    required this.remoteUrl,
    required this.fallback,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.3),
            width: 2,
          ),
        ),
        child: ClipOval(
          child: localPath != null && File(localPath!).existsSync()
              ? Image.file(
                  File(localPath!),
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => fallback,
                )
              : remoteUrl != null && remoteUrl!.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: remoteUrl!,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => fallback,
                      errorWidget: (context, url, error) => fallback,
                    )
                  : fallback,
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
