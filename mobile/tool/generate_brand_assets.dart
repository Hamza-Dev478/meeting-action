// Renders the app icon and launch-screen images from the app's own drawing
// code, so the home screen, launch screen and sign-in screen match.
//
//   cd mobile && flutter test tool/generate_brand_assets.dart
//   dart run flutter_launcher_icons && dart run flutter_native_splash:create
//
// Output goes to assets/branding/. The sparkle is drawn as a path, not with
// the icon font, because widget tests do not load real fonts.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meeting_action/theme/ambient_backdrop.dart';
import 'package:meeting_action/theme/app_theme.dart';
import 'package:meeting_action/theme/glass_theme.dart';

const _out = 'assets/branding';

void main() {
  Future<void> render(
    WidgetTester tester,
    String name, {
    required Size size,
    required double pixelRatio,
    required Widget child,
    Brightness brightness = Brightness.light,
  }) async {
    await tester.binding.setSurfaceSize(size);
    final key = GlobalKey();
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Theme(
          data: buildAppTheme(brightness),
          child: RepaintBoundary(
            key: key,
            child: SizedBox.fromSize(size: size, child: child),
          ),
        ),
      ),
    );
    await tester.runAsync(() async {
      final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: pixelRatio);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      File('$_out/$name.png')
        ..createSync(recursive: true)
        ..writeAsBytesSync(bytes!.buffer.asUint8List());
    });
  }

  testWidgets('generate brand assets', (tester) async {
    // App icon: the orb on the light backdrop, full bleed and opaque.
    await render(
      tester,
      'app_icon',
      size: const Size(1024, 1024),
      pixelRatio: 1,
      child: const Stack(
        children: [
          AmbientBackdrop(),
          Center(child: Orb(diameter: 600)),
        ],
      ),
    );
    // Launch background: the same scene the first screen paints, so the switch
    // from the launch screen to the app is seamless. Rendered at 1x on purpose:
    // a soft gradient loses nothing when iOS scales it up, and the two images
    // are about 4 MB smaller than at 3x.
    for (final brightness in Brightness.values) {
      await render(
        tester,
        brightness == Brightness.light ? 'splash_background' : 'splash_background_dark',
        size: const Size(430, 932),
        pixelRatio: 1,
        brightness: brightness,
        child: const AmbientBackdrop(),
      );
    }
    // Launch logo, transparent, at 4x as flutter_native_splash expects (shows at 120 pt).
    await render(
      tester,
      'splash_logo',
      size: const Size(120, 120),
      pixelRatio: 4,
      child: const Center(child: Orb(diameter: 96)),
    );
    // Android 12 shows the logo inside a circle covering two thirds of a 960 px canvas.
    await render(
      tester,
      'splash_logo_android12',
      size: const Size(240, 240),
      pixelRatio: 4,
      child: const Center(child: Orb(diameter: 128)),
    );
    await tester.binding.setSurfaceSize(null);
  });
}

/// The app's "AI" orb: the accent sweep, a soft glow, a highlight, and three sparkles.
class Orb extends StatelessWidget {
  const Orb({super.key, required this.diameter});

  final double diameter;

  @override
  Widget build(BuildContext context) => CustomPaint(size: Size.square(diameter), painter: _OrbPainter());
}

class _OrbPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2 * 0.86;
    final rect = Rect.fromCircle(center: c, radius: r);

    canvas.drawCircle(
      c,
      r,
      Paint()
        ..color = GlassTheme.accentSweep.first.withValues(alpha: 0.45)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.16),
    );
    canvas.drawCircle(c, r, Paint()..shader = const SweepGradient(colors: GlassTheme.accentSweep).createShader(rect));
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.45, -0.55),
          radius: 0.9,
          colors: [Colors.white.withValues(alpha: 0.38), Colors.white.withValues(alpha: 0)],
        ).createShader(rect),
    );

    final white = Paint()..color = Colors.white;
    canvas.drawPath(_sparkle(c + Offset(-r * 0.12, r * 0.06), r * 0.46), white);
    canvas.drawPath(_sparkle(c + Offset(r * 0.36, -r * 0.34), r * 0.18), white);
    canvas.drawPath(_sparkle(c + Offset(r * 0.38, r * 0.34), r * 0.13), white);
  }

  /// A four-point star with concave sides.
  Path _sparkle(Offset c, double r) {
    final k = r * 0.2;
    return Path()
      ..moveTo(c.dx, c.dy - r)
      ..quadraticBezierTo(c.dx + k, c.dy - k, c.dx + r, c.dy)
      ..quadraticBezierTo(c.dx + k, c.dy + k, c.dx, c.dy + r)
      ..quadraticBezierTo(c.dx - k, c.dy + k, c.dx - r, c.dy)
      ..quadraticBezierTo(c.dx - k, c.dy - k, c.dx, c.dy - r)
      ..close();
  }

  @override
  bool shouldRepaint(_OrbPainter oldDelegate) => false;
}
