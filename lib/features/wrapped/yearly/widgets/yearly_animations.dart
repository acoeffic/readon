import 'dart:math';
import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// Yearly Wrapped color palette
// ---------------------------------------------------------------------------

class YearlyColors {
  static const gold = Color(0xFFD4A853);
  static const cream = Color(0xFFF5E6C8);
  static const bordeaux = Color(0xFF6B1D3A);
  static const deepBg = Color(0xFF0C0A14);
  static const goldGradient = [gold, cream];
}

// ---------------------------------------------------------------------------
// FadeUp – Opacity 0→1 + translateY 20→0
// ---------------------------------------------------------------------------

class FadeUp extends StatefulWidget {
  final Widget child;
  final Duration delay;
  final Duration duration;

  const FadeUp({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 600),
  });

  @override
  State<FadeUp> createState() => _FadeUpState();
}

class _FadeUpState extends State<FadeUp> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _opacity;
  late final Animation<Offset> _offset;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(duration: widget.duration, vsync: this);
    final curved = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _opacity = curved;
    _offset = Tween<Offset>(
      begin: const Offset(0, 20),
      end: Offset.zero,
    ).animate(curved);

    if (widget.delay == Duration.zero) {
      _ctrl.forward();
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) _ctrl.forward();
      });
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, child) => Opacity(
        opacity: _opacity.value,
        child: Transform.translate(offset: _offset.value, child: child),
      ),
      child: widget.child,
    );
  }
}

// ---------------------------------------------------------------------------
// Typewriter – Reveals text character by character
// ---------------------------------------------------------------------------

class Typewriter extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final TextAlign textAlign;
  final Duration delay;
  final Duration charDuration;

  const Typewriter({
    super.key,
    required this.text,
    this.style,
    this.textAlign = TextAlign.center,
    this.delay = Duration.zero,
    this.charDuration = const Duration(milliseconds: 50),
  });

  @override
  State<Typewriter> createState() => _TypewriterState();
}

class _TypewriterState extends State<Typewriter> {
  int _visibleChars = 0;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(widget.delay, () {
      if (mounted) {
        _started = true;
        _typeNext();
      }
    });
  }

  void _typeNext() {
    if (!mounted || !_started) return;
    if (_visibleChars >= widget.text.length) return;
    Future.delayed(widget.charDuration, () {
      if (mounted) {
        setState(() => _visibleChars++);
        _typeNext();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final visible = widget.text.substring(0, _visibleChars);
    // Use invisible remaining text to maintain layout stability
    final invisible = widget.text.substring(_visibleChars);
    return RichText(
      textAlign: widget.textAlign,
      text: TextSpan(
        children: [
          TextSpan(text: visible, style: widget.style),
          TextSpan(
            text: invisible,
            style: widget.style?.copyWith(color: Colors.transparent) ??
                const TextStyle(color: Colors.transparent),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// AnimatedCounter – Ticks from 0 to [value] over [duration]
// ---------------------------------------------------------------------------

class AnimatedCounter extends StatefulWidget {
  final int value;
  final Duration delay;
  final Duration duration;
  final TextStyle? style;
  final String suffix;
  final String prefix;

  const AnimatedCounter({
    super.key,
    required this.value,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 1500),
    this.style,
    this.suffix = '',
    this.prefix = '',
  });

  @override
  State<AnimatedCounter> createState() => _AnimatedCounterState();
}

class _AnimatedCounterState extends State<AnimatedCounter>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(duration: widget.duration, vsync: this);
    if (widget.delay == Duration.zero) {
      _ctrl.forward();
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) _ctrl.forward();
      });
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final curve = Curves.easeOut.transform(_ctrl.value);
        final v = (widget.value * curve).round();
        return Text(
          '${widget.prefix}$v${widget.suffix}',
          style: widget.style,
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// AnimatedBar – Width from 0 to [fraction] of parent
// ---------------------------------------------------------------------------

class AnimatedBar extends StatefulWidget {
  final double fraction; // 0.0 – 1.0
  final Color color;
  final double height;
  final Duration delay;
  final Duration duration;
  final BorderRadius? borderRadius;

  const AnimatedBar({
    super.key,
    required this.fraction,
    this.color = YearlyColors.gold,
    this.height = 8,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 1000),
    this.borderRadius,
  });

  @override
  State<AnimatedBar> createState() => _AnimatedBarState();
}

class _AnimatedBarState extends State<AnimatedBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(duration: widget.duration, vsync: this);
    if (widget.delay == Duration.zero) {
      _ctrl.forward();
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) _ctrl.forward();
      });
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        final curve = Curves.easeOut.transform(_ctrl.value);
        return FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: widget.fraction * curve,
          child: Container(
            height: widget.height,
            decoration: BoxDecoration(
              color: widget.color,
              borderRadius:
                  widget.borderRadius ?? BorderRadius.circular(widget.height / 2),
            ),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// PulseWidget – Gentle pulsing scale animation
// ---------------------------------------------------------------------------

class PulseWidget extends StatefulWidget {
  final Widget child;
  final Duration duration;

  const PulseWidget({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 1500),
  });

  @override
  State<PulseWidget> createState() => _PulseWidgetState();
}

class _PulseWidgetState extends State<PulseWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(duration: widget.duration, vsync: this)
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, child) {
        final scale = 1.0 + 0.05 * _ctrl.value;
        return Transform.scale(scale: scale, child: child);
      },
      child: widget.child,
    );
  }
}

// ---------------------------------------------------------------------------
// Starfield – ~30 twinkling golden stars as background
// ---------------------------------------------------------------------------

class Starfield extends StatefulWidget {
  final int starCount;
  final Color starColor;

  const Starfield({
    super.key,
    this.starCount = 30,
    this.starColor = YearlyColors.gold,
  });

  @override
  State<Starfield> createState() => _StarfieldState();
}

class _StarfieldState extends State<Starfield> with TickerProviderStateMixin {
  late final List<_StarData> _stars;
  late final List<AnimationController> _controllers;

  @override
  void initState() {
    super.initState();
    final rng = Random();
    _stars = List.generate(widget.starCount, (_) {
      return _StarData(
        x: rng.nextDouble(),
        y: rng.nextDouble(),
        size: 1.0 + rng.nextDouble() * 2.0,
        minOpacity: 0.1 + rng.nextDouble() * 0.2,
        maxOpacity: 0.4 + rng.nextDouble() * 0.5,
      );
    });

    _controllers = List.generate(widget.starCount, (i) {
      final duration = Duration(
        milliseconds: 1500 + rng.nextInt(2500),
      );
      return AnimationController(duration: duration, vsync: this)
        ..repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            children: List.generate(widget.starCount, (i) {
              final star = _stars[i];
              return Positioned(
                left: star.x * constraints.maxWidth,
                top: star.y * constraints.maxHeight,
                child: AnimatedBuilder(
                  animation: _controllers[i],
                  builder: (_, __) {
                    final t = _controllers[i].value;
                    final opacity =
                        star.minOpacity + (star.maxOpacity - star.minOpacity) * t;
                    return Opacity(
                      opacity: opacity,
                      child: Container(
                        width: star.size,
                        height: star.size,
                        decoration: BoxDecoration(
                          color: widget.starColor,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: widget.starColor.withValues(alpha: 0.5),
                              blurRadius: star.size * 2,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              );
            }),
          );
        },
      ),
    );
  }
}

class _StarData {
  final double x;
  final double y;
  final double size;
  final double minOpacity;
  final double maxOpacity;

  const _StarData({
    required this.x,
    required this.y,
    required this.size,
    required this.minOpacity,
    required this.maxOpacity,
  });
}
