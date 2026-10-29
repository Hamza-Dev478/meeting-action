import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

/// Colours and blur for the app's Liquid Glass surfaces and the ambient
/// backdrop behind them. Screens read it with [GlassTheme.of], which falls back
/// to the built-in palettes when a test pumps a screen without the app theme.
@immutable
class GlassTheme extends ThemeExtension<GlassTheme> {
  const GlassTheme({
    required this.fill,
    required this.fillStrong,
    required this.rimHighlight,
    required this.rimShade,
    required this.sheen,
    required this.shadow,
    required this.blurSigma,
    required this.backdropBase,
    required this.backdropBlobs,
    required this.blobOpacity,
  });

  /// Tint for glass that floats over the backdrop (bars, chips).
  final Color fill;

  /// Denser tint for glass that carries body text or form fields.
  final Color fillStrong;

  /// Edge light where the "curved" glass catches it (top-left).
  final Color rimHighlight;

  /// Edge shade on the far side of the surface.
  final Color rimShade;

  /// Soft highlight across the top of a surface.
  final Color sheen;
  final Color shadow;
  final double blurSigma;
  final List<Color> backdropBase;
  final List<Color> backdropBlobs;
  final double blobOpacity;

  static const light = GlassTheme(
    fill: Color(0x59FFFFFF),
    fillStrong: Color(0xA6FFFFFF),
    rimHighlight: Color(0xF2FFFFFF),
    rimShade: Color(0x1F1B1F3B),
    sheen: Color(0x80FFFFFF),
    shadow: Color(0x241B1F3B),
    blurSigma: 24,
    backdropBase: [Color(0xFFEEF0FF), Color(0xFFF7F1FF), Color(0xFFE9F7FA)],
    backdropBlobs: [Color(0xFF6D7CFF), Color(0xFFB77CFF), Color(0xFF3FCFD6), Color(0xFFFF9B78)],
    blobOpacity: 0.55,
  );

  static const dark = GlassTheme(
    fill: Color(0x1FFFFFFF),
    fillStrong: Color(0x33FFFFFF),
    rimHighlight: Color(0x66FFFFFF),
    rimShade: Color(0x40000000),
    sheen: Color(0x26FFFFFF),
    shadow: Color(0x73000000),
    blurSigma: 28,
    backdropBase: [Color(0xFF0B0D1C), Color(0xFF16113A), Color(0xFF061820)],
    backdropBlobs: [Color(0xFF3D48DA), Color(0xFF7B3FD3), Color(0xFF12858E), Color(0xFFB5543B)],
    blobOpacity: 0.6,
  );

  /// Vivid sweep for the app's "AI" orbs; the same in light and dark.
  static const accentSweep = [Color(0xFF6D7CFF), Color(0xFFB77CFF), Color(0xFF3FCFD6), Color(0xFF6D7CFF)];

  /// Content wider than this is centred, so large and unfolded screens read
  /// like a column rather than stretching edge to edge.
  static const maxContentWidth = 640.0;

  static GlassTheme of(BuildContext context) {
    final theme = Theme.of(context);
    return theme.extension<GlassTheme>() ?? (theme.brightness == Brightness.dark ? dark : light);
  }

  @override
  GlassTheme copyWith({
    Color? fill,
    Color? fillStrong,
    Color? rimHighlight,
    Color? rimShade,
    Color? sheen,
    Color? shadow,
    double? blurSigma,
    List<Color>? backdropBase,
    List<Color>? backdropBlobs,
    double? blobOpacity,
  }) => GlassTheme(
    fill: fill ?? this.fill,
    fillStrong: fillStrong ?? this.fillStrong,
    rimHighlight: rimHighlight ?? this.rimHighlight,
    rimShade: rimShade ?? this.rimShade,
    sheen: sheen ?? this.sheen,
    shadow: shadow ?? this.shadow,
    blurSigma: blurSigma ?? this.blurSigma,
    backdropBase: backdropBase ?? this.backdropBase,
    backdropBlobs: backdropBlobs ?? this.backdropBlobs,
    blobOpacity: blobOpacity ?? this.blobOpacity,
  );

  @override
  GlassTheme lerp(GlassTheme? other, double t) {
    if (other == null) return this;
    List<Color> lerpColors(List<Color> a, List<Color> b) => [
      for (var i = 0; i < a.length && i < b.length; i++) Color.lerp(a[i], b[i], t)!,
    ];
    return GlassTheme(
      fill: Color.lerp(fill, other.fill, t)!,
      fillStrong: Color.lerp(fillStrong, other.fillStrong, t)!,
      rimHighlight: Color.lerp(rimHighlight, other.rimHighlight, t)!,
      rimShade: Color.lerp(rimShade, other.rimShade, t)!,
      sheen: Color.lerp(sheen, other.sheen, t)!,
      shadow: Color.lerp(shadow, other.shadow, t)!,
      blurSigma: lerpDouble(blurSigma, other.blurSigma, t)!,
      backdropBase: lerpColors(backdropBase, other.backdropBase),
      backdropBlobs: lerpColors(backdropBlobs, other.backdropBlobs),
      blobOpacity: lerpDouble(blobOpacity, other.blobOpacity, t)!,
    );
  }
}
