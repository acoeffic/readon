import 'dart:math';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../../../config/env.dart';
import 'yearly_wrapped_data.dart';
import 'yearly_wrapped_service.dart';
import 'widgets/yearly_animations.dart';
import 'widgets/yearly_slide_container.dart';
import 'widgets/slides/slide_opening.dart';
import 'widgets/slides/slide_time.dart';
import 'widgets/slides/slide_books.dart';
import 'widgets/slides/slide_genres.dart';
import 'widgets/slides/slide_habits.dart';
import 'widgets/slides/slide_top_books.dart';
import 'widgets/slides/slide_milestones.dart';
import 'widgets/slides/slide_social.dart';
import 'widgets/slides/slide_evolution.dart';
import 'widgets/slides/slide_final.dart';

class YearlyWrappedScreen extends StatefulWidget {
  final int year;
  final YearlyWrappedData? demoData;

  const YearlyWrappedScreen({
    super.key,
    required this.year,
    this.demoData,
  });

  @override
  State<YearlyWrappedScreen> createState() => _YearlyWrappedScreenState();
}

class _YearlyWrappedScreenState extends State<YearlyWrappedScreen> {
  static const _slideCount = 10;

  int _currentSlide = 0;
  int _slideKey = 0;
  YearlyWrappedData? _data;
  bool _isLoading = true;
  String? _error;

  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isMuted = false;
  static const double _targetVolume = 0.3;

  static final _baseUrl =
      '${Env.supabaseStorageUrl}/asset/audio';
  late final List<String> _ambientTracks = [
    '$_baseUrl/wrapped_ambient_1.mp3',
    '$_baseUrl/wrapped_ambient_2.mp3',
    '$_baseUrl/wrapped_ambient_3.mp3',
  ];

  @override
  void initState() {
    super.initState();
    _initAudio();
    if (widget.demoData != null) {
      _data = widget.demoData;
      _isLoading = false;
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
      // Fade in: 0 → 0.3 over ~2 seconds
      await _fadeIn();
    } catch (e) {
      debugPrint('Yearly Wrapped audio error: $e');
    }
  }

  Future<void> _fadeIn() async {
    const steps = 20;
    const stepDuration = Duration(milliseconds: 100);
    for (int i = 1; i <= steps; i++) {
      if (!mounted) return;
      await Future.delayed(stepDuration);
      await _audioPlayer.setVolume(i / steps * _targetVolume);
    }
  }

  Future<void> _fadeOut() async {
    try {
      const steps = 10;
      const stepDuration = Duration(milliseconds: 80);
      final currentVol = _audioPlayer.volume;
      for (int i = steps; i >= 0; i--) {
        await _audioPlayer.setVolume(currentVol * i / steps);
        await Future.delayed(stepDuration);
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
      final service = YearlyWrappedService();
      final data = await service.getYearlyData(widget.year);
      if (mounted) {
        setState(() {
          _data = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('YearlyWrapped error: $e');
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
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
      backgroundColor: YearlyColors.deepBg,
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
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(
              color: YearlyColors.gold.withValues(alpha: 0.5),
              strokeWidth: 2,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Preparation de ton annee...',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              color: YearlyColors.cream.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              color: YearlyColors.cream.withValues(alpha: 0.3),
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              'Impossible de charger le resume',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 16,
                color: YearlyColors.cream.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? '',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                color: YearlyColors.cream.withValues(alpha: 0.3),
              ),
            ),
            const SizedBox(height: 24),
            TextButton(
              onPressed: () {
                setState(() {
                  _isLoading = true;
                  _error = null;
                });
                _loadData();
              },
              child: Text(
                'Reessayer',
                style: TextStyle(color: YearlyColors.gold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    final data = _data!;

    return YearlySlideContainer(
      currentSlide: _currentSlide,
      slideCount: _slideCount,
      onNavigate: _navigateTo,
      onClose: _close,
      isMuted: _isMuted,
      onToggleMute: _toggleMute,
      child: KeyedSubtree(
        key: ValueKey(_slideKey),
        child: _buildSlide(data),
      ),
    );
  }

  Widget _buildSlide(YearlyWrappedData data) {
    switch (_currentSlide) {
      case 0:
        return SlideOpening(data: data);
      case 1:
        return SlideTime(data: data);
      case 2:
        return SlideBooks(data: data);
      case 3:
        return SlideGenres(data: data);
      case 4:
        return SlideHabits(data: data);
      case 5:
        return SlideTopBooks(data: data);
      case 6:
        return SlideMilestones(data: data);
      case 7:
        return SlideSocial(data: data);
      case 8:
        return SlideEvolution(data: data);
      case 9:
        return SlideFinal(data: data);
      default:
        return const SizedBox.shrink();
    }
  }
}
