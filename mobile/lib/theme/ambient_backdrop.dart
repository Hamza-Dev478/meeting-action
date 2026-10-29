import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'glass_theme.dart';

/// Drives the slow drift of the backdrop's colour fields. One clock at the app
/// root keeps every screen's backdrop in step, so a pushed page slides over the
/// same scene. Without a clock (a screen pumped on its own in a test) the
/// backdrop is still, which keeps `pumpAndSettle` finite.
class AmbientClock extends StatefulWidget {
  const AmbientClock({super.key, required this.child});

  final Widget child;

  static Animation<double>? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_AmbientClockScope>()?.animation;

  @override
  State<AmbientClock> createState() => _AmbientClockState();
}

class _AmbientClockState extends State<AmbientClock> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 30),
    value: 0.15,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reduce Motion: hold the scene still.
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _AmbientClockScope(animation: _controller, child: widget.child);
}

class _AmbientClockScope extends InheritedWidget {
  const _AmbientClockScope({required this.animation, required super.child});

  final Animation<double> animation;

  @override
  bool updateShouldNotify(_AmbientClockScope oldWidget) => animation != oldWidget.animation;
}

/// The coloured scene that glass surfaces blur: a soft gradient with a few
/// large, drifting colour fields. Paints under [child].
class AmbientBackdrop extends StatelessWidget {
  const AmbientBackdrop({super.key, this.child});

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final painter = _BackdropPainter(
      glass: GlassTheme.of(context),
      clock: AmbientClock.maybeOf(context) ?? const AlwaysStoppedAnimation(0.15),
    );
    return Stack(
      fit: StackFit.expand,
      children: [
        RepaintBoundary(child: CustomPaint(painter: painter)),
        ?child,
      ],
    );
  }
}

class _Orbit {
  const _Orbit(this.x, this.y, this.dx, this.dy, this.radius, this.speed, this.phase);

  final double x, y, dx, dy, radius, phase;

  /// Whole turns per loop, so the drift repeats without a jump.
  final int speed;
}

const _orbits = [
  _Orbit(0.15, 0.12, 0.18, 0.08, 0.95, 1, 0),
  _Orbit(0.90, 0.30, 0.10, 0.14, 0.85, -1, 1.7),
  _Orbit(0.20, 0.78, 0.16, 0.10, 0.90, 1, 3.1),
  _Orbit(0.85, 0.92, 0.12, 0.08, 0.70, 2, 4.4),
];

class _BackdropPainter extends CustomPainter {
  _BackdropPainter({required this.glass, required this.clock}) : super(repaint: clock);

  final GlassTheme glass;
  final Animation<double> clock;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: glass.backdropBase,
        ).createShader(rect),
    );

    final turn = clock.value * 2 * math.pi;
    for (var i = 0; i < _orbits.length && i < glass.backdropBlobs.length; i++) {
      final orbit = _orbits[i];
      final angle = turn * orbit.speed + orbit.phase;
      final center = Offset(
        size.width * (orbit.x + orbit.dx * math.sin(angle)),
        size.height * (orbit.y + orbit.dy * math.cos(angle)),
      );
      final radius = size.shortestSide * orbit.radius;
      final color = glass.backdropBlobs[i];
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..shader = RadialGradient(
            colors: [
              color.withValues(alpha: glass.blobOpacity),
              color.withValues(alpha: 0),
            ],
          ).createShader(Rect.fromCircle(center: center, radius: radius)),
      );
    }
  }

  @override
  bool shouldRepaint(_BackdropPainter oldDelegate) => oldDelegate.glass != glass || oldDelegate.clock != clock;
}
