import 'dart:math';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../../../config/env.dart';
import '../../../services/readon_sync_service.dart';
import 'monthly_wrapped_data.dart';
import 'monthly_wrapped_service.dart';
import 'widgets/monthly_slide_container.dart';
import 'widgets/slides/title_slide.dart';
import 'widgets/slides/stats_slide.dart';
import 'widgets/slides/calendar_slide.dart';
import 'widgets/slides/top_book_slide.dart';
import 'widgets/slides/share_slide.dart';

class MonthlyWrappedScreen extends StatefulWidget {
  final int month; // 1-12
  final int year;
  final MonthlyWrappedData? demoData; // pass non-null to skip Supabase

  const MonthlyWrappedScreen({
    super.key,
    required this.month,
    required this.year,
    this.demoData,
  });

  @override
  State<MonthlyWrappedScreen> createState() => _MonthlyWrappedScreenState();
}

class _MonthlyWrappedScreenState extends State<MonthlyWrappedScreen> {
  static const _slideCount = 5;

  int _currentSlide = 0;
  int _slideKey = 0; // bumped to force slide rebuild & re-trigger animations
  MonthlyWrappedData? _data;
  bool _isLoading = true;
  String? _error;

  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isMuted = false;
  static const double _targetVolume = 0.5;

  static final _baseUrl = '${Env.supabaseStorageUrl}/asset/audio';
  static final List<String> _ambientTracks = [
    '$_baseUrl/wrapped_01_intro_future_bass.mp3',
    '$_baseUrl/wrapped_02_intro_energetic_upbeat.mp3',
    '$_baseUrl/wrapped_03_intro_abstract.mp3',
    '$_baseUrl/wrapped_04_stats_background_motivational.mp3',
    '$_baseUrl/wrapped_05_stats_future_tech.mp3',
    '$_baseUrl/wrapped_06_stats_trap_future_bass.mp3',
    '$_baseUrl/wrapped_07_stats_nightfall.mp3',
    '$_baseUrl/wrapped_08_momentum_bounce_on_it.mp3',
    '$_baseUrl/wrapped_09_momentum_lokiis.mp3',
    '$_baseUrl/wrapped_10_momentum_miro_max.mp3',
    '$_baseUrl/wrapped_11_cool_good_vibes.mp3',
    '$_baseUrl/wrapped_12_cool_vlogs_vlog.mp3',
    '$_baseUrl/wrapped_13_cool_nastel_bom.mp3',
    '$_baseUrl/wrapped_14_calm_new_age_nature.mp3',
    '$_baseUrl/wrapped_15_calm_lofi_ksmk.mp3',
    '$_baseUrl/wrapped_16_calm_lofi_osynthw.mp3',
    '$_baseUrl/wrapped_17_outro_dreamy_night.mp3',
    '$_baseUrl/wrapped_18_outro_80s_synth.mp3',
    '$_baseUrl/wrapped_19_outro_soft_house.mp3',
    '$_baseUrl/wrapped_20_outro_new_age_vibe.mp3',
  ];

  @override
  void initState() {
    super.initState();
    _initAudio();
    if (widget.demoData != null) {
      _data = widget.demoData;
      _isLoading = false;
      // Trigger video pre-render even in demo mode
      ReadonSyncService.renderMonthlyWrapped(widget.month, widget.year);
    } else {
      _loadData();
    }
  }

  Future<void> _initAudio() async {
    try {
      final randomTrack =
          _ambientTracks[Random().nextInt(_ambientTracks.length)];
      await _audioPlayer.setUrl(randomTrack);
      await _audioPlayer.setLoopMode(LoopMode.one);
      await _audioPlayer.setVolume(0);
      await _audioPlayer.play();
      // Fade in: 0 → 0.5 over ~1.5 s
      for (int i = 1; i <= 15; i++) {
        if (!mounted) return;
        await Future.delayed(const Duration(milliseconds: 100));
        await _audioPlayer.setVolume(i / 15 * _targetVolume);
      }
    } catch (e) {
      debugPrint('Monthly Wrapped audio error: $e');
    }
  }

  Future<void> _fadeOut() async {
    try {
      final currentVol = _audioPlayer.volume;
      for (int i = 8; i >= 0; i--) {
        await _audioPlayer.setVolume(currentVol * i / 8);
        await Future.delayed(const Duration(milliseconds: 100));
      }
      await _audioPlayer.stop();
    } catch (_) {}
  }

  @override
  void dispose() {
    _fadeOut().then((_) => _audioPlayer.dispose());
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final service = MonthlyWrappedService();
      final data = await service.getMonthlyData(widget.month, widget.year);
      if (mounted) setState(() { _data = data; _isLoading = false; });

      // Fire-and-forget: trigger server-side video pre-render
      ReadonSyncService.renderMonthlyWrapped(widget.month, widget.year);
    } catch (e) {
      debugPrint('MonthlyWrapped error: $e');
      if (mounted) setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  void _navigateTo(int index) {
    if (index == _currentSlide || index < 0 || index >= _slideCount) return;
    setState(() {
      _currentSlide = index;
      _slideKey++;
    });
  }

  void _toggleMute() {
    setState(() => _isMuted = !_isMuted);
    _audioPlayer.setVolume(_isMuted ? 0 : _targetVolume);
  }

  void _close() {
    _fadeOut().then((_) {
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF06060A),
      body: SafeArea(
        child: _isLoading
            ? _buildLoading()
            : _error != null
                ? _buildError()
                : _buildContent(),
      ),
    );
  }

  Widget _buildLoading() {
    return const Center(
      child: CircularProgressIndicator(color: Colors.white24),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.white38, size: 48),
            const SizedBox(height: 16),
            Text(
              'Impossible de charger le resume',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 16,
                color: Colors.white.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? '',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.3),
              ),
            ),
            const SizedBox(height: 24),
            TextButton(
              onPressed: () {
                setState(() { _isLoading = true; _error = null; });
                _loadData();
              },
              child: const Text('Reessayer'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    final data = _data!;
    final theme = data.theme;

    return MonthlySlideContainer(
      currentSlide: _currentSlide,
      slideCount: _slideCount,
      theme: theme,
      onNavigate: _navigateTo,
      onClose: _close,
      isMuted: _isMuted,
      onToggleMute: _toggleMute,
      child: KeyedSubtree(
        key: ValueKey(_slideKey),
        child: _buildSlide(data, theme),
      ),
    );
  }

  Widget _buildSlide(MonthlyWrappedData data, MonthTheme theme) {
    switch (_currentSlide) {
      case 0:
        return TitleSlide(data: data, theme: theme);
      case 1:
        return StatsSlide(data: data, theme: theme);
      case 2:
        return CalendarSlide(data: data, theme: theme);
      case 3:
        return TopBookSlide(data: data, theme: theme);
      case 4:
        return ShareSlide(data: data, theme: theme);
      default:
        return const SizedBox.shrink();
    }
  }
}
