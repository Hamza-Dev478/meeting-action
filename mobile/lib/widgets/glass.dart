import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../theme/glass_theme.dart';

/// A Liquid Glass surface: blurs what is behind it, tints it, and draws a rim
/// and sheen so the edge reads like curved glass catching light.
///
/// Surfaces that sit side by side in a list share one blur pass through the
/// nearest [BackdropGroup] ([grouped]). Surfaces that float over other content
/// (bars, the tab bar, buttons) must blur that content, so they pass
/// `grouped: false`. With Increase Contrast on, the surface is solid instead.
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(24)),
    this.padding,
    this.strong = false,
    this.tint,
    this.onTap,
    this.shadow = false,
    this.grouped = true,
  });

  final Widget child;
  final BorderRadius borderRadius;
  final EdgeInsetsGeometry? padding;

  /// Use the denser tint, for surfaces that carry body text or form fields.
  final bool strong;

  /// Overrides the glass tint, for example a coloured (prominent) button.
  final Color? tint;
  final VoidCallback? onTap;
  final bool shadow;
  final bool grouped;

  @override
  Widget build(BuildContext context) {
    final glass = GlassTheme.of(context);
    final scheme = Theme.of(context).colorScheme;

    Widget content = padding == null ? child : Padding(padding: padding!, child: child);
    if (onTap != null) content = InkWell(onTap: onTap, borderRadius: borderRadius, child: content);
    // Ripples from this surface's own InkWells and ListTiles draw on the glass,
    // not on the Scaffold behind it.
    content = Material(type: MaterialType.transparency, child: content);

    if (MediaQuery.maybeHighContrastOf(context) ?? false) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: tint ?? scheme.surfaceContainerHigh,
          borderRadius: borderRadius,
          border: Border.all(color: scheme.outline),
        ),
        child: ClipRRect(borderRadius: borderRadius, child: content),
      );
    }

    final filter = ImageFilter.blur(sigmaX: glass.blurSigma, sigmaY: glass.blurSigma);
    final painted = CustomPaint(
      painter: _GlassBodyPainter(
        borderRadius: borderRadius,
        fill: tint ?? (strong ? glass.fillStrong : glass.fill),
        sheen: glass.sheen,
      ),
      foregroundPainter: _GlassRimPainter(
        borderRadius: borderRadius,
        highlight: glass.rimHighlight,
        shade: glass.rimShade,
      ),
      child: content,
    );
    final blurred = grouped && BackdropGroup.of(context) != null
        ? BackdropFilter.grouped(filter: filter, child: painted)
        : BackdropFilter(filter: filter, child: painted);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: shadow
            ? [BoxShadow(color: glass.shadow, blurRadius: 28, offset: const Offset(0, 12), spreadRadius: -8)]
            : null,
      ),
      child: ClipRRect(borderRadius: borderRadius, child: blurred),
    );
  }
}

class _GlassBodyPainter extends CustomPainter {
  _GlassBodyPainter({required this.borderRadius, required this.fill, required this.sheen});

  final BorderRadius borderRadius;
  final Color fill;
  final Color sheen;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = borderRadius.toRRect(rect);
    canvas.drawRRect(rrect, Paint()..color = fill);
    // Light pooling along the top edge, fading out by mid-height.
    canvas.drawRRect(
      rrect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.center,
          colors: [sheen, sheen.withValues(alpha: 0)],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_GlassBodyPainter oldDelegate) =>
      oldDelegate.fill != fill || oldDelegate.sheen != sheen || oldDelegate.borderRadius != borderRadius;
}

class _GlassRimPainter extends CustomPainter {
  _GlassRimPainter({required this.borderRadius, required this.highlight, required this.shade});

  final BorderRadius borderRadius;
  final Color highlight;
  final Color shade;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = borderRadius.toRRect(rect).deflate(0.6);
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [highlight, highlight.withValues(alpha: 0.12), shade, highlight.withValues(alpha: 0.45)],
          stops: const [0, 0.38, 0.72, 1],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_GlassRimPainter oldDelegate) =>
      oldDelegate.highlight != highlight || oldDelegate.shade != shade || oldDelegate.borderRadius != borderRadius;
}

/// A glass card for list rows, suggestions and banners.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(16),
    this.margin = const EdgeInsets.symmetric(vertical: 6),
    this.tint,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: margin,
      child: GlassSurface(strong: true, tint: tint, onTap: onTap, padding: padding, child: child),
    );
  }
}

/// A capsule button made of glass. [prominent] tints it with the primary
/// colour for the screen's main action; otherwise it is clear glass.
class GlassButton extends StatelessWidget {
  const GlassButton({
    super.key,
    required this.onPressed,
    required this.label,
    this.icon,
    this.prominent = true,
    this.busy = false,
  });

  final VoidCallback? onPressed;
  final String label;
  final IconData? icon;
  final bool prominent;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final enabled = onPressed != null && !busy;
    final foreground = prominent ? scheme.onPrimary : scheme.primary;
    return Semantics(
      button: true,
      enabled: enabled,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: enabled || busy ? 1 : 0.5,
        child: GlassSurface(
          borderRadius: const BorderRadius.all(Radius.circular(999)),
          tint: prominent ? scheme.primary.withValues(alpha: 0.86) : null,
          shadow: prominent,
          grouped: false,
          onTap: enabled ? onPressed : null,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (busy)
                SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: foreground))
              else if (icon != null)
                Icon(icon, size: 20, color: foreground),
              if (busy || icon != null) const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge
                      ?.copyWith(color: foreground, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A round glass badge holding an icon or a short label, used by empty states,
/// banners and list rows.
class GlassBadge extends StatelessWidget {
  const GlassBadge({super.key, this.icon, this.label, this.color, this.size = 44});

  final IconData? icon;
  final String? label;
  final Color? color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = color ?? scheme.primary;
    return SizedBox(
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [accent.withValues(alpha: 0.30), accent.withValues(alpha: 0.12)],
          ),
          border: Border.all(color: accent.withValues(alpha: 0.35)),
        ),
        child: Center(
          child: label != null
              ? Text(
                  label!,
                  style: TextStyle(color: accent, fontWeight: FontWeight.w700, fontSize: size * 0.38),
                )
              : Icon(icon, color: accent, size: size * 0.5),
        ),
      ),
    );
  }
}
