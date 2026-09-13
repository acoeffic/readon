import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../l10n/app_localizations.dart';
import '../../models/book.dart';
import '../../models/reading_session.dart';
import '../../theme/app_theme.dart';
import 'package:lexday/features/badges/services/badges_service.dart';
import '../../services/moderation_service.dart';
import '../../services/mutual_friends_service.dart';
import '../../widgets/badges_grid.dart';
import '../../widgets/cached_book_cover.dart';
import '../../widgets/cached_profile_avatar.dart';
import '../../widgets/constrained_content.dart';
import '../../widgets/mutual_friends_badge.dart';
import '../../widgets/report_sheet.dart';
import '../../widgets/require_account_sheet.dart';
import '../../widgets/star_rating.dart';
import '../sessions/session_detail_page.dart';
import 'friend_book_detail_page.dart';

/// Page de profil d'un ami — design "Profil ami" (juillet 2026) :
/// header immersif (couverture du livre en cours floutée), stats épurées,
/// livre en cours avec progression, coups de cœur, livres en commun,
/// bibliothèque filtrable, badges.
class FriendProfilePage extends StatefulWidget {
  final String userId;
  final String? initialName;
  final String? initialAvatar;

  const FriendProfilePage({
    super.key,
    required this.userId,
    this.initialName,
    this.initialAvatar,
  });

  @override
  State<FriendProfilePage> createState() => _FriendProfilePageState();
}

class _FriendProfilePageState extends State<FriendProfilePage> {
  final supabase = Supabase.instance.client;
  final badgesService = BadgesService();

  bool _loading = true;
  String _userName = '';
  String? _avatarUrl;
  DateTime? _memberSinceDate;
  int _booksFinished = 0;
  int _totalPages = 0;
  int _totalHours = 0;
  bool _readingHoursHidden = false;
  int _friendCount = 0;
  List<UserBadge> _badges = [];
  String? _friendshipStatus; // 'accepted', 'pending', null
  bool _isProfilePrivate = false;
  bool _canViewDetails = false; // true si public OU ami accepté
  MutualFriendsSummary _mutualFriends = MutualFriendsSummary.empty;

  // Données du nouveau design (RPC get_friend_profile_v2)
  Map<String, dynamic>? _currentReading;
  int _currentReadingSinceDays = 0;
  List<Map<String, dynamic>> _favorites = [];
  List<Map<String, dynamic>> _commonBooks = [];
  Map<String, int> _libraryCounts = {'finished': 0, 'reading': 0, 'to_read': 0};
  List<Map<String, dynamic>> _libraryBooks = [];
  String _libraryFilter = 'finished';
  bool _libraryExpanded = false;

  // Sessions de lecture récentes (RPC get_friend_recent_sessions)
  List<Map<String, dynamic>> _recentSessions = [];
  bool _sessionsExpanded = false;

  static const _sessionsPreviewCount = 3;
  static const _sessionsFetchCount = 10;

  static const _libraryPreviewCount = 8;

  @override
  void initState() {
    super.initState();
    _userName = widget.initialName ?? '';
    _avatarUrl = widget.initialAvatar;
    _loadAll();
  }

  Future<void> _loadAll() async {
    // IMPORTANT: Charger d'abord le profil pour avoir is_profile_private
    await _loadProfile();

    // Puis charger le statut d'amitié (qui dépend de is_profile_private)
    await _loadFriendshipStatus();

    // Amis communs (utile dès qu'on regarde un profil, peu importe le statut)
    final mutualFuture = MutualFriendsService().getSummary(widget.userId);

    // Charger les détails uniquement si autorisé
    if (_canViewDetails) {
      await Future.wait([
        _loadStats(),
        _loadProfileV2(),
        _loadBadges(),
        _loadRecentSessions(),
      ]);
    }

    final mutual = await mutualFuture;
    if (mounted) {
      setState(() {
        _mutualFriends = mutual;
        _loading = false;
      });
    }
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await supabase
          .from('profiles')
          .select('display_name, avatar_url, created_at, is_profile_private')
          .eq('id', widget.userId)
          .maybeSingle();

      if (profile != null && mounted) {
        final isPrivate = profile['is_profile_private'] as bool? ?? false;

        setState(() {
          _userName = profile['display_name'] as String? ??
              widget.initialName ??
              'Utilisateur';
          _avatarUrl = profile['avatar_url'] as String? ?? widget.initialAvatar;
          _isProfilePrivate = isPrivate;
          if (profile['created_at'] != null) {
            _memberSinceDate =
                DateTime.parse(profile['created_at'] as String);
          }
        });
      }
    } catch (e) {
      debugPrint('Erreur _loadProfile: $e');
    }
  }

  Future<void> _loadStats() async {
    try {
      final response = await supabase.rpc(
        'get_friend_profile_stats',
        params: {'p_user_id': widget.userId},
      );

      if (response != null && mounted) {
        final stats = response is Map<String, dynamic>
            ? response
            : Map<String, dynamic>.from(response as Map);
        final totalMinutes = stats['total_minutes'];
        setState(() {
          _booksFinished = (stats['books_finished'] as num?)?.toInt() ?? 0;
          _totalPages = (stats['total_pages'] as num?)?.toInt() ?? 0;
          _readingHoursHidden = totalMinutes == null;
          _totalHours = ((totalMinutes as num?)?.toDouble() ?? 0) ~/ 60;
          _friendCount = (stats['friend_count'] as num?)?.toInt() ?? 0;
        });
      }
    } catch (e) {
      debugPrint('Erreur _loadStats: $e');
    }
  }

  Future<void> _loadProfileV2() async {
    try {
      final response = await supabase.rpc(
        'get_friend_profile_v2',
        params: {'p_user_id': widget.userId},
      );

      if (response == null || !mounted) return;
      final data = response is Map<String, dynamic>
          ? response
          : Map<String, dynamic>.from(response as Map);

      List<Map<String, dynamic>> asList(dynamic v) => (v as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

      final currentList = asList(data['current_reading']);
      final counts = data['library_counts'] is Map
          ? Map<String, dynamic>.from(data['library_counts'] as Map)
          : <String, dynamic>{};

      Map<String, dynamic>? current;
      var sinceDays = 0;
      if (currentList.isNotEmpty) {
        current = currentList.first;
        final startedAt = current['started_at'] as String?;
        if (startedAt != null) {
          sinceDays =
              DateTime.now().difference(DateTime.parse(startedAt)).inDays;
        }
      }

      final libraryBooks = asList(data['books']);
      var filter = _libraryFilter;
      if (!libraryBooks.any((b) => b['status'] == filter)) {
        // Premier filtre non vide (ordre : terminés, en cours, envies)
        for (final s in ['finished', 'reading', 'to_read']) {
          if (libraryBooks.any((b) => b['status'] == s)) {
            filter = s;
            break;
          }
        }
      }

      setState(() {
        _currentReading = current;
        _currentReadingSinceDays = sinceDays;
        _favorites = asList(data['favorites']);
        _commonBooks = asList(data['common_books']);
        _libraryBooks = libraryBooks;
        _libraryFilter = filter;
        _libraryCounts = {
          'finished': (counts['finished'] as num?)?.toInt() ?? 0,
          'reading': (counts['reading'] as num?)?.toInt() ?? 0,
          'to_read': (counts['to_read'] as num?)?.toInt() ?? 0,
        };
      });
    } catch (e) {
      debugPrint('Erreur _loadProfileV2: $e');
    }
  }

  Future<void> _loadRecentSessions() async {
    try {
      final response = await supabase.rpc(
        'get_friend_recent_sessions',
        params: {
          'p_user_id': widget.userId,
          'p_limit': _sessionsFetchCount,
        },
      );
      if (!mounted) return;
      final list = (response as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      setState(() => _recentSessions = list);
    } catch (e) {
      debugPrint('Erreur _loadRecentSessions: $e');
    }
  }

  Future<void> _loadBadges() async {
    try {
      final badges = await badgesService.getUserBadgesById(widget.userId);
      if (mounted) setState(() => _badges = badges);
    } catch (e) {
      debugPrint('Erreur _loadBadges: $e');
    }
  }

  Future<void> _loadFriendshipStatus() async {
    try {
      final currentUserId = supabase.auth.currentUser?.id;
      if (currentUserId == null) {
        // Anonyme : un profil public reste visible, un profil privé non.
        if (mounted) {
          setState(() => _canViewDetails = !_isProfilePrivate);
        }
        return;
      }

      final result = await supabase
          .from('friends')
          .select('status')
          .or('and(requester_id.eq.$currentUserId,addressee_id.eq.${widget.userId}),'
              'and(requester_id.eq.${widget.userId},addressee_id.eq.$currentUserId)')
          .limit(1);

      if (mounted) {
        String? status;
        if ((result as List).isNotEmpty) {
          status = result[0]['status'] as String?;
        }

        setState(() {
          _friendshipStatus = status;
          // On peut voir les détails si:
          // 1. Le profil est public (!_isProfilePrivate)
          // 2. OU si on est ami accepté (status == 'accepted')
          _canViewDetails = !_isProfilePrivate || status == 'accepted';
        });
      }
    } catch (e) {
      debugPrint('Erreur _loadFriendshipStatus: $e');
    }
  }

  String _memberSinceLabel(AppLocalizations l) {
    final createdAt = _memberSinceDate;
    if (createdAt == null) return '';
    final days = DateTime.now().difference(createdAt).inDays;
    if (days < 7) return l.memberSinceDays(days < 1 ? 1 : days);
    if (days < 30) return l.memberSinceWeeks(days ~/ 7);
    if (days < 365) return l.memberSinceMonths(days ~/ 30);
    return l.memberSinceYears(days ~/ 365);
  }

  Future<void> _addFriend() async {
    if (supabase.auth.currentUser == null) {
      await showRequireAccountSheet(context, source: 'add_friend');
      return;
    }
    final l = AppLocalizations.of(context);
    try {
      final currentUserId = supabase.auth.currentUser?.id;
      if (currentUserId == null) return;

      await supabase.from('friends').insert({
        'requester_id': currentUserId,
        'addressee_id': widget.userId,
        'status': 'pending',
      });

      setState(() => _friendshipStatus = 'pending');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.requestSent)),
        );
      }
    } catch (e) {
      debugPrint('Erreur _addFriend: $e');
    }
  }

  Future<void> _cancelFriendRequest() async {
    final l = AppLocalizations.of(context);
    try {
      final currentUserId = supabase.auth.currentUser?.id;
      if (currentUserId == null) return;

      await supabase
          .from('friends')
          .delete()
          .eq('requester_id', currentUserId)
          .eq('addressee_id', widget.userId)
          .eq('status', 'pending');

      setState(() => _friendshipStatus = null);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.requestCancelled)),
        );
      }
    } catch (e) {
      debugPrint('Erreur _cancelFriendRequest: $e');
    }
  }

  void _openBook(Map<String, dynamic> book) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FriendBookDetailPage(
          userId: widget.userId,
          userName: _userName,
          book: book,
        ),
      ),
    );
  }

  void _onMenuAction(String action) {
    switch (action) {
      case 'remove_friend':
        _removeFriend();
      case 'report':
        showReportSheet(
          context,
          targetType: ReportTargetType.user,
          targetId: widget.userId,
          targetUserId: widget.userId,
        );
      case 'block':
        _confirmBlock();
    }
  }

  Future<void> _confirmBlock() async {
    final l = AppLocalizations.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.blockUserConfirmTitle(_userName)),
        content: Text(l.blockUserConfirmMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.blockUserConfirmCta,
                style: const TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    final ok = await ModerationService().blockUser(widget.userId);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? l.userBlockedMessage : l.blockUserErrorMessage),
        backgroundColor: ok ? AppColors.primary : Colors.red.shade700,
      ),
    );
    if (ok) Navigator.of(context).pop();
  }

  Future<void> _removeFriend() async {
    final l = AppLocalizations.of(context);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.removeFriendTitle),
        content: Text(l.removeFriendMessage(_userName)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false), child: Text(l.cancel)),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.confirm, style: const TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final currentUserId = supabase.auth.currentUser!.id;
      await supabase.rpc('remove_friend', params: {
        'uid': currentUserId,
        'fid': widget.userId,
      });

      setState(() => _friendshipStatus = null);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.friendRemoved)),
        );
      }
    } catch (e) {
      debugPrint('Erreur _removeFriend: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // BUILD
  // ---------------------------------------------------------------------------

  String? get _heroCoverUrl {
    final url = _currentReading?['book_cover_url'] as String?;
    if (url == null || url.isEmpty) return null;
    return url;
  }

  bool get _immersiveHeader => _canViewDetails && _heroCoverUrl != null;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final colors = context.appColors;

    final overlayStyle = (_immersiveHeader || colors.isDark)
        ? SystemUiOverlayStyle.light
        : SystemUiOverlayStyle.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlayStyle,
      child: Scaffold(
        backgroundColor: colors.scaffoldBg,
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: () async {
                  setState(() => _loading = true);
                  await _loadAll();
                },
                child: ConstrainedContent(
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildHeader(l, colors),
                        if (_isProfilePrivate && !_canViewDetails)
                          _buildPrivateCard(l, colors)
                        else ...[
                          _buildStatsRow(l, colors),
                          // « Retirer des amis » vit dans le menu ⋮ ; ici
                          // uniquement ajouter / annuler la demande.
                          if (supabase.auth.currentUser?.id != widget.userId &&
                              _friendshipStatus != 'accepted')
                            Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(20, 18, 20, 0),
                              child: _buildFriendAction(l),
                            ),
                          if (_currentReading != null)
                            _buildCurrentReading(l, colors),
                          if (_recentSessions.isNotEmpty)
                            _buildRecentSessions(l, colors),
                          if (_favorites.isNotEmpty)
                            _buildFavorites(l, colors),
                          if (_commonBooks.isNotEmpty)
                            _buildCommonBooks(l, colors),
                          _buildLibrary(l, colors),
                          if (_badges.isNotEmpty) _buildBadges(l, colors),
                        ],
                        const SizedBox(height: 46),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  // --- HEADER -----------------------------------------------------------------

  Widget _buildHeader(AppLocalizations l, AppThemeColors colors) {
    final topPad = MediaQuery.of(context).padding.top;
    final immersive = _immersiveHeader;
    final onHeroColor = immersive ? Colors.white : colors.textPrimary;

    final content = Column(
      children: [
        SizedBox(height: topPad),
        _buildHeaderNav(l, onHeroColor),
        SizedBox(height: immersive ? 26 : 18),
        // Avatar avec anneau
        Container(
          width: 104,
          height: 104,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: immersive
                ? colors.scaffoldBg.withValues(alpha: 0.9)
                : colors.cardBg,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: immersive ? 0.28 : 0.10),
                blurRadius: immersive ? 34 : 26,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: CachedProfileAvatar(
            imageUrl: _avatarUrl,
            userName: _userName,
            radius: 48,
            backgroundColor:
                colors.isDark ? AppColors.accentDark : AppColors.accentLight,
            textColor: colors.primary,
            fontSize: 40,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          _userName,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.6,
            color: colors.textPrimary,
          ),
        ),
        if (_memberSinceDate != null) ...[
          const SizedBox(height: 2),
          Text(
            _memberSinceLabel(l),
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              fontStyle: FontStyle.italic,
              color: colors.textSecondary,
            ),
          ),
        ],
        if (!_mutualFriends.isEmpty) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.fromLTRB(8, 6, 12, 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              color: colors.cardBg.withValues(alpha: 0.8),
              border: Border.all(
                color: colors.textPrimary.withValues(alpha: 0.06),
              ),
            ),
            child: MutualFriendsBadge(
              summary: _mutualFriends,
              fontSize: 13,
              textColor: colors.textPrimary.withValues(alpha: 0.75),
            ),
          ),
        ],
        const SizedBox(height: 4),
      ],
    );

    if (!immersive) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: content,
      );
    }

    return Stack(
      children: [
        // Couverture floutée en fond
        Positioned.fill(
          child: ClipRect(
            child: Transform.scale(
              scale: 1.3,
              child: ImageFiltered(
                imageFilter: ui.ImageFilter.blur(sigmaX: 28, sigmaY: 28),
                child: CachedNetworkImage(
                  imageUrl: _heroCoverUrl!,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) =>
                      Container(color: colors.primaryDeep),
                ),
              ),
            ),
          ),
        ),
        // Voile dégradé vers le fond de page
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.0, 0.30, 0.66, 0.84, 1.0],
                colors: [
                  Colors.black.withValues(alpha: 0.62),
                  Colors.black.withValues(alpha: 0.30),
                  colors.scaffoldBg.withValues(alpha: 0.55),
                  colors.scaffoldBg.withValues(alpha: 0.96),
                  colors.scaffoldBg,
                ],
              ),
            ),
          ),
        ),
        content,
      ],
    );
  }

  Widget _buildHeaderNav(AppLocalizations l, Color color) {
    final isOwnProfile =
        supabase.auth.currentUser?.id == widget.userId;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back, color: color),
            onPressed: () => Navigator.pop(context),
          ),
          Expanded(
            child: Text(
              l.profileSection.toUpperCase(),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.6,
                color: color.withValues(alpha: 0.8),
              ),
            ),
          ),
          // Menu modération (Apple §1.2 UGC) : signaler / bloquer.
          // Caché pour son propre profil.
          if (isOwnProfile)
            const SizedBox(width: 48)
          else
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, color: color),
              onSelected: _onMenuAction,
              itemBuilder: (ctx) => [
                if (_friendshipStatus == 'accepted')
                  PopupMenuItem(
                    value: 'remove_friend',
                    child: Row(
                      children: [
                        const Icon(Icons.person_remove_outlined, size: 18),
                        const SizedBox(width: 10),
                        Text(l.removeFriend),
                      ],
                    ),
                  ),
                PopupMenuItem(
                  value: 'report',
                  child: Row(
                    children: [
                      const Icon(Icons.flag_outlined,
                          size: 18, color: Colors.red),
                      const SizedBox(width: 10),
                      Text(l.reportUserAction),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'block',
                  child: Row(
                    children: [
                      const Icon(Icons.block, size: 18, color: Colors.red),
                      const SizedBox(width: 10),
                      Text(l.blockUserAction),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  // --- PROFIL PRIVÉ -----------------------------------------------------------

  Widget _buildPrivateCard(AppLocalizations l, AppThemeColors colors) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpace.l),
            decoration: BoxDecoration(
              color: colors.cardBg,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.lock_outline,
                  size: 48,
                  color: colors.textPrimary.withValues(alpha: 0.3),
                ),
                const SizedBox(height: AppSpace.m),
                Text(
                  l.privateProfileLabel,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: AppSpace.s),
                Text(
                  l.privateProfileMessage(_userName),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: colors.textPrimary.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          _buildFriendAction(l),
        ],
      ),
    );
  }

  // --- STATS ------------------------------------------------------------------

  Widget _buildStatsRow(AppLocalizations l, AppThemeColors colors) {
    final items = <(String, String)>[
      ('$_booksFinished', l.books),
      ('$_totalPages', l.pagesLabel),
      if (!_readingHoursHidden)
        ('$_totalHours h', l.readingLabel)
      else
        ('$_friendCount', l.friendsLabel),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(26, 22, 26, 0),
      child: IntrinsicHeight(
        child: Row(
          children: [
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Container(
                    width: 1,
                    color: colors.textPrimary.withValues(alpha: 0.10),
                  ),
                ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      items[i].$1,
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        color: colors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      items[i].$2.toUpperCase(),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.1,
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // --- EN CE MOMENT -----------------------------------------------------------

  Widget _buildCurrentReading(AppLocalizations l, AppThemeColors colors) {
    final book = _currentReading!;
    final title = book['book_title'] as String? ?? '';
    final author = book['book_author'] as String? ?? '';
    final currentPage = (book['current_page'] as num?)?.toInt() ?? 0;
    final pageCount = (book['book_page_count'] as num?)?.toInt() ?? 0;
    final hasProgress = pageCount > 0 && currentPage > 0;
    final progress =
        hasProgress ? (currentPage / pageCount).clamp(0.0, 1.0) : 0.0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 26, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text(
                  l.profileCurrentSection.toUpperCase(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.7,
                    color: colors.primary,
                  ),
                ),
              ),
              if (_currentReadingSinceDays >= 1)
                Text(
                  l.profileCurrentSince(_currentReadingSinceDays),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: colors.textSecondary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () => _openBook(book),
            child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.cardBg,
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.18),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: CachedBookCover(
                    imageUrl: book['book_cover_url'] as String?,
                    isbn: book['book_isbn'] as String?,
                    googleId: book['book_google_id'] as String?,
                    title: title,
                    author: author,
                    width: 90,
                    height: 135,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                          letterSpacing: -0.2,
                          color: colors.textPrimary,
                        ),
                      ),
                      if (author.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          author,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                      if (hasProgress) ...[
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 6,
                            backgroundColor: colors.pillBg,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(colors.primary),
                          ),
                        ),
                        const SizedBox(height: 7),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${(progress * 100).round()} %',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color:
                                    colors.textPrimary.withValues(alpha: 0.75),
                              ),
                            ),
                            Text(
                              l.profilePageProgress(currentPage, pageCount),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: colors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          ),
        ],
      ),
    );
  }

  // --- SES COUPS DE CŒUR ------------------------------------------------------

  Widget _buildSectionHeader(
    AppThemeColors colors, {
    required String title,
    String? trailing,
    EdgeInsetsGeometry padding =
        const EdgeInsets.only(left: 20, right: 20, bottom: 12),
  }) {
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
                color: colors.textPrimary,
              ),
            ),
          ),
          if (trailing != null)
            Text(
              trailing,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: colors.textSecondary,
              ),
            ),
        ],
      ),
    );
  }

  // --- SESSIONS RÉCENTES ------------------------------------------------------

  Widget _buildRecentSessions(AppLocalizations l, AppThemeColors colors) {
    final visible = _sessionsExpanded
        ? _recentSessions
        : _recentSessions.take(_sessionsPreviewCount).toList();
    final canExpand = _recentSessions.length > _sessionsPreviewCount;

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 30, 0, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            colors,
            title: l.recentSessions,
            trailing: '${_recentSessions.length}',
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              decoration: BoxDecoration(
                color: colors.cardBg,
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                children: [
                  for (var i = 0; i < visible.length; i++) ...[
                    if (i > 0)
                      Divider(
                        height: 1,
                        indent: 16,
                        endIndent: 16,
                        color: colors.textPrimary.withValues(alpha: 0.06),
                      ),
                    _buildSessionTile(l, colors, visible[i]),
                  ],
                  if (canExpand)
                    InkWell(
                      onTap: () => setState(
                          () => _sessionsExpanded = !_sessionsExpanded),
                      borderRadius: const BorderRadius.vertical(
                          bottom: Radius.circular(22)),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _sessionsExpanded ? l.seeLess : l.seeAll,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: colors.primary,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              _sessionsExpanded
                                  ? Icons.expand_less
                                  : Icons.expand_more,
                              size: 18,
                              color: colors.primary,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionTile(
    AppLocalizations l,
    AppThemeColors colors,
    Map<String, dynamic> session,
  ) {
    final title = session['book_title'] as String? ?? '';
    final startPage = (session['start_page'] as num?)?.toInt() ?? 0;
    final endPage = (session['end_page'] as num?)?.toInt();
    final pagesRead = endPage != null ? endPage - startPage : 0;
    // Si l'ami masque ses heures de lecture, on ne montre que les pages.
    final duration = _readingHoursHidden
        ? ''
        : _formatSessionDuration(
            session['start_time'] as String?,
            session['end_time'] as String?,
          );
    final date = _formatSessionDate(session['end_time'] as String?, l);

    return InkWell(
      onTap: () => _openSession(session),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            CachedBookCover(
              imageUrl: session['book_cover_url'] as String?,
              isbn: session['book_isbn'] as String?,
              googleId: session['book_google_id'] as String?,
              title: title,
              author: session['book_author'] as String?,
              width: 36,
              height: 52,
              borderRadius: BorderRadius.circular(6),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: colors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [
                      endPage != null
                          ? l.sessionPageRange(startPage, endPage)
                          : l.pageAtNumber(startPage),
                      if (pagesRead > 0) l.nPages(pagesRead),
                      if (duration.isNotEmpty) duration,
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              date,
              style: TextStyle(
                fontSize: 12,
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.chevron_right,
              size: 18,
              color: colors.textPrimary.withValues(alpha: 0.3),
            ),
          ],
        ),
      ),
    );
  }

  String _formatSessionDuration(String? startTime, String? endTime) {
    if (startTime == null || endTime == null) return '';
    final minutes = DateTime.parse(endTime)
        .difference(DateTime.parse(startTime))
        .inMinutes;
    if (minutes >= 60) return '${minutes ~/ 60}h ${minutes % 60}min';
    return '${minutes}min';
  }

  String _formatSessionDate(String? dateStr, AppLocalizations l) {
    if (dateStr == null) return '';
    final date = DateTime.parse(dateStr).toLocal();
    final diff = DateTime.now().difference(date);
    if (diff.inDays == 0) return l.today;
    if (diff.inDays == 1) return l.yesterday;
    if (diff.inDays < 7) return l.daysAgo(diff.inDays);
    final locale = Localizations.localeOf(context).toString();
    return DateFormat('d MMM', locale).format(date);
  }

  void _openSession(Map<String, dynamic> session) {
    final now = DateTime.now();
    DateTime? parseLocal(dynamic v) =>
        v is String ? DateTime.parse(v).toLocal() : null;

    final readingSession = ReadingSession(
      id: session['id'] as String,
      userId: session['user_id'] as String,
      bookId: session['book_id'] as String,
      startPage: (session['start_page'] as num).toInt(),
      endPage: (session['end_page'] as num?)?.toInt(),
      startTime: parseLocal(session['start_time']) ?? now,
      endTime: parseLocal(session['end_time']),
      isHidden: session['is_hidden'] as bool? ?? false,
      readingFor: session['reading_for'] as String?,
      createdAt: parseLocal(session['created_at']) ?? now,
      updatedAt: parseLocal(session['updated_at']) ?? now,
    );

    final book = Book(
      id: (session['b_id'] as num?)?.toInt() ?? 0,
      googleId: session['book_google_id'] as String?,
      title: session['book_title'] as String? ?? '',
      author: session['book_author'] as String?,
      coverUrl: session['book_cover_url'] as String?,
      pageCount: (session['book_page_count'] as num?)?.toInt(),
      isbn: session['book_isbn'] as String?,
    );

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SessionDetailPage(
          session: readingSession,
          book: book,
          isOwn: false,
        ),
      ),
    );
  }

  // --- COUPS DE CŒUR ----------------------------------------------------------

  Widget _buildFavorites(AppLocalizations l, AppThemeColors colors) {
    return Padding(
      padding: const EdgeInsets.only(top: 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            colors,
            title: l.profileFavoritesSection,
            trailing: l.nBooks(_favorites.length),
          ),
          SizedBox(
            height: 218,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: _favorites.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final book = _favorites[index];
                final rating = (book['rating'] as num?)?.toDouble();
                return GestureDetector(
                  onTap: () => _openBook(book),
                  child: SizedBox(
                  width: 106,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.16),
                              blurRadius: 18,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: CachedBookCover(
                          imageUrl: book['book_cover_url'] as String?,
                          isbn: book['book_isbn'] as String?,
                          googleId: book['book_google_id'] as String?,
                          title: book['book_title'] as String?,
                          author: book['book_author'] as String?,
                          width: 106,
                          height: 159,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        book['book_title'] as String? ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          height: 1.25,
                          color: colors.textPrimary,
                        ),
                      ),
                      if (rating != null) ...[
                        const SizedBox(height: 4),
                        StarRating(
                          rating: rating,
                          size: 13,
                          spacing: 1,
                          color: colors.variantAccent,
                        ),
                      ],
                    ],
                  ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // --- VOUS AVEZ LU LES DEUX --------------------------------------------------

  Widget _buildCommonBooks(AppLocalizations l, AppThemeColors colors) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 32, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            colors,
            title: l.profileCommonSection,
            trailing: '${_commonBooks.length}',
            padding: const EdgeInsets.only(bottom: 4),
          ),
          Text(
            l.profileCommonSubtitle,
            style: TextStyle(fontSize: 13, color: colors.textSecondary),
          ),
          const SizedBox(height: 14),
          Column(
            children: [
              for (var i = 0; i < _commonBooks.length; i++) ...[
                if (i > 0) const SizedBox(height: 10),
                _buildCommonBookTile(l, colors, _commonBooks[i]),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCommonBookTile(
    AppLocalizations l,
    AppThemeColors colors,
    Map<String, dynamic> book,
  ) {
    final theirRating = (book['their_rating'] as num?)?.toDouble();
    final myRating = (book['my_rating'] as num?)?.toDouble();
    final firstName = _userName.split(' ').first;

    Widget ratingChunk(String label, double rating) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(width: 4),
          StarRating(
            rating: rating,
            size: 12,
            spacing: 0,
            color: colors.variantAccent,
          ),
        ],
      );
    }

    final chunks = <Widget>[
      if (theirRating != null) ratingChunk(firstName, theirRating),
      if (myRating != null) ratingChunk(l.profileYouLabel, myRating),
    ];

    return GestureDetector(
      onTap: () => _openBook(book),
      child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: colors.cardBg,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.16),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: CachedBookCover(
              imageUrl: book['book_cover_url'] as String?,
              isbn: book['book_isbn'] as String?,
              googleId: book['book_google_id'] as String?,
              title: book['book_title'] as String?,
              author: book['book_author'] as String?,
              width: 44,
              height: 66,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  book['book_title'] as String? ?? '',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                    color: colors.textPrimary,
                  ),
                ),
                if (chunks.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Wrap(
                    spacing: 10,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: chunks,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }

  // --- SA BIBLIOTHÈQUE --------------------------------------------------------

  Widget _buildLibrary(AppLocalizations l, AppThemeColors colors) {
    final total = _libraryCounts.values.fold<int>(0, (a, b) => a + b);
    final filtered =
        _libraryBooks.where((b) => b['status'] == _libraryFilter).toList();
    final visible =
        _libraryExpanded ? filtered : filtered.take(_libraryPreviewCount).toList();
    final filterCount = _libraryCounts[_libraryFilter] ?? filtered.length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 34, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader(
            colors,
            title: l.profileLibrarySection,
            trailing: l.nBooks(total),
            padding: const EdgeInsets.only(bottom: 12),
          ),
          if (total == 0)
            Text(
              l.noBooksYet,
              style: TextStyle(
                color: colors.textPrimary.withValues(alpha: 0.5),
                fontStyle: FontStyle.italic,
              ),
            )
          else ...[
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildLibraryChip(
                      colors, 'finished', l.finishedBooksSection),
                  const SizedBox(width: 8),
                  _buildLibraryChip(colors, 'reading', l.currentlyReading),
                  const SizedBox(width: 8),
                  _buildLibraryChip(colors, 'to_read', l.profileToReadChip),
                ],
              ),
            ),
            const SizedBox(height: 14),
            if (filtered.isEmpty)
              Text(
                l.noBooksYet,
                style: TextStyle(
                  color: colors.textPrimary.withValues(alpha: 0.5),
                  fontStyle: FontStyle.italic,
                ),
              )
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 2 / 3,
                ),
                itemCount: visible.length,
                itemBuilder: (context, index) {
                  final book = visible[index];
                  return GestureDetector(
                    onTap: () => _openBook(book),
                    child: LayoutBuilder(
                      builder: (context, constraints) => CachedBookCover(
                        imageUrl: book['book_cover_url'] as String?,
                        isbn: book['book_isbn'] as String?,
                        googleId: book['book_google_id'] as String?,
                        title: book['book_title'] as String?,
                        author: book['book_author'] as String?,
                        width: constraints.maxWidth,
                        height: constraints.maxHeight,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  );
                },
              ),
            if (filtered.length > _libraryPreviewCount) ...[
              const SizedBox(height: 14),
              Material(
                color: colors.cardBg,
                borderRadius: BorderRadius.circular(18),
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () =>
                      setState(() => _libraryExpanded = !_libraryExpanded),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 15),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _libraryExpanded
                                ? l.seeLess
                                : l.profileSeeFullLibrary,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: colors.textPrimary,
                            ),
                          ),
                        ),
                        if (!_libraryExpanded) ...[
                          Text(
                            '$filterCount',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: colors.textSecondary,
                            ),
                          ),
                          const SizedBox(width: 10),
                        ],
                        Icon(
                          _libraryExpanded
                              ? Icons.expand_less
                              : Icons.arrow_forward,
                          size: 16,
                          color: colors.primary,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildLibraryChip(
      AppThemeColors colors, String status, String label) {
    final selected = _libraryFilter == status;
    final count = _libraryCounts[status] ?? 0;
    return GestureDetector(
      onTap: () => setState(() {
        _libraryFilter = status;
        _libraryExpanded = false;
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: selected
              ? colors.textPrimary
              : colors.textPrimary.withValues(alpha: 0.05),
        ),
        child: Text(
          '$label  $count',
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
            color: selected
                ? colors.scaffoldBg
                : colors.textPrimary.withValues(alpha: 0.75),
          ),
        ),
      ),
    );
  }

  // --- BADGES -----------------------------------------------------------------

  Widget _buildBadges(AppLocalizations l, AppThemeColors colors) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 34, 20, 0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpace.l),
        decoration: BoxDecoration(
          color: colors.cardBg,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: BadgesGrid(
          badges: _badges,
          title: l.theirBadges,
        ),
      ),
    );
  }

  // --- ACTION AMI -------------------------------------------------------------

  Widget _buildFriendAction(AppLocalizations l) {
    if (supabase.auth.currentUser?.id == widget.userId ||
        _friendshipStatus == 'accepted') {
      // Ami accepté : l'action « retirer » est dans le menu ⋮.
      return const SizedBox.shrink();
    }
    if (_friendshipStatus == 'pending') {
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: _cancelFriendRequest,
          icon: const Icon(Icons.close, size: 18),
          label: Text(l.cancelRequest),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.error,
            side: BorderSide(color: AppColors.error.withValues(alpha: 0.55)),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ),
      );
    } else {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: _addFriend,
          icon: const Icon(Icons.person_add, size: 18),
          label: Text(l.addFriend),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ),
      );
    }
  }
}
