import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../theme/ambient_backdrop.dart';
import '../theme/glass_theme.dart';

/// Screen scaffold for the glass look: the ambient backdrop, an iOS-style large
/// title that collapses into a glass navigation bar as content scrolls under it,
/// and either a list of [children] or one centred [body] (loading, empty, error).
class GlassPage extends StatelessWidget {
  const GlassPage({
    super.key,
    required this.title,
    this.heroTag,
    this.actions = const [],
    this.children,
    this.body,
    this.onRefresh,
    this.floatingActionButton,
    this.padding = const EdgeInsets.fromLTRB(16, 4, 16, 24),
  }) : assert((children == null) != (body == null), 'Pass either children or body');

  final String title;

  /// When set, the large title is a [HeroTitle] with this tag.
  final Object? heroTag;
  final List<Widget> actions;
  final List<Widget>? children;
  final Widget? body;
  final Future<void> Function()? onRefresh;
  final Widget? floatingActionButton;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.paddingOf(context);
    Widget scroll = CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      slivers: [
        SliverPersistentHeader(
          pinned: true,
          delegate: _GlassHeader(
            title: title,
            heroTag: heroTag,
            actions: actions,
            topInset: insets.top,
            canPop: ModalRoute.of(context)?.impliesAppBarDismissal ?? false,
          ),
        ),
        if (children != null)
          SliverLayoutBuilder(
            builder: (context, constraints) => SliverPadding(
              padding: padding
                  .copyWith(bottom: padding.bottom + insets.bottom + 72)
                  .add(centeringInsets(constraints.crossAxisExtent)),
              sliver: SliverList.list(children: children!),
            ),
          )
        else
          SliverFillRemaining(
            hasScrollBody: false,
            child: Padding(
              padding: EdgeInsets.only(bottom: insets.bottom),
              child: body,
            ),
          ),
      ],
    );
    if (onRefresh != null) {
      scroll = RefreshIndicator(onRefresh: onRefresh!, edgeOffset: insets.top + _GlassHeader.barHeight, child: scroll);
    }
    // Scaffold places a floating button from the device's safe area only, so lift
    // it by whatever an enclosing scaffold reserved for its floating tab bar.
    final fabLift = math.max(0.0, insets.bottom - MediaQuery.viewPaddingOf(context).bottom);
    return Scaffold(
      floatingActionButton: floatingActionButton == null
          ? null
          : Padding(
              padding: EdgeInsets.only(bottom: fabLift),
              child: floatingActionButton,
            ),
      body: AmbientBackdrop(child: BackdropGroup(child: scroll)),
    );
  }
}

class _GlassHeader extends SliverPersistentHeaderDelegate {
  _GlassHeader({
    required this.title,
    required this.heroTag,
    required this.actions,
    required this.topInset,
    required this.canPop,
  });

  static const barHeight = 52.0;
  static const largeTitleHeight = 56.0;

  final String title;
  final Object? heroTag;
  final List<Widget> actions;
  final double topInset;
  final bool canPop;

  @override
  double get minExtent => topInset + barHeight;

  @override
  double get maxExtent => topInset + barHeight + largeTitleHeight;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final theme = Theme.of(context);
    final glass = GlassTheme.of(context);
    // 0 while the large title is showing, 1 once content scrolls under the bar.
    final progress = (shrinkOffset / largeTitleHeight).clamp(0.0, 1.0);
    final smallTitleOpacity = ((progress - 0.6) / 0.4).clamp(0.0, 1.0);
    final largeStyle = theme.textTheme.headlineMedium!.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.6);

    return Stack(
      fit: StackFit.expand,
      children: [
        if (progress > 0)
          ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: glass.blurSigma * progress, sigmaY: glass.blurSigma * progress),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Color.lerp(glass.fill.withValues(alpha: 0), glass.fillStrong, progress),
                  border: Border(
                    bottom: BorderSide(color: glass.rimShade.withValues(alpha: glass.rimShade.a * progress)),
                  ),
                ),
              ),
            ),
          ),
        Positioned(
          top: topInset,
          left: 0,
          right: 0,
          height: barHeight,
          child: NavigationToolbar(
            leading: canPop ? const BackButton() : null,
            middle: ExcludeSemantics(
              excluding: smallTitleOpacity == 0,
              child: Opacity(
                opacity: smallTitleOpacity,
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [...actions, const SizedBox(width: 8)]),
            middleSpacing: 12,
          ),
        ),
        Positioned(
          top: topInset + barHeight,
          left: 20,
          right: 20,
          bottom: 0,
          child: ClipRect(
            child: OverflowBox(
              alignment: Alignment.bottomLeft,
              minHeight: largeTitleHeight,
              maxHeight: largeTitleHeight,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Opacity(
                  opacity: 1 - progress,
                  child: heroTag == null
                      ? Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: largeStyle)
                      : HeroTitle(tag: heroTag!, text: title, style: largeStyle),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  bool shouldRebuild(_GlassHeader oldDelegate) => true;
}

/// A title that flies between two screens, easing its text style from one end
/// to the other (the meeting row's title into the meeting's large title).
class HeroTitle extends StatelessWidget {
  const HeroTitle({super.key, required this.tag, required this.text, required this.style});

  final Object tag;
  final String text;
  final TextStyle style;

  static Widget _shuttle(
    BuildContext flightContext,
    Animation<double> animation,
    HeroFlightDirection direction,
    BuildContext fromContext,
    BuildContext toContext,
  ) {
    final from = (fromContext.widget as Hero).child as _HeroText;
    final to = (toContext.widget as Hero).child as _HeroText;
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) => _HeroText(text: to.text, style: TextStyle.lerp(from.style, to.style, animation.value)!),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: tag,
      flightShuttleBuilder: _shuttle,
      child: _HeroText(text: text, style: style),
    );
  }
}

class _HeroText extends StatelessWidget {
  const _HeroText({required this.text, required this.style});

  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: style),
    );
  }
}

/// Lifts and fades a list item into place, staggered by [index], the first
/// time it is built. Skipped when the system asks for reduced motion.
class Entrance extends StatelessWidget {
  const Entrance({super.key, required this.index, required this.child});

  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    final step = index.clamp(0, 8);
    final total = 360 + step * 55;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: total),
      curve: Interval(step * 55 / total, 1, curve: Curves.easeOutCubic),
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, (1 - t) * 18), child: child),
      ),
      child: child,
    );
  }
}

/// Side padding that centres content in a column no wider than
/// [GlassTheme.maxContentWidth] when [width] is wider (large or unfolded screens).
EdgeInsets centeringInsets(double width) {
  final extra = (width - GlassTheme.maxContentWidth) / 2;
  return extra > 0 ? EdgeInsets.symmetric(horizontal: extra) : EdgeInsets.zero;
}
