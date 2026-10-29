import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'glass.dart';

class GlassTab {
  const GlassTab({required this.label, this.icon, this.selectedIcon, this.badge});

  final String label;
  final IconData? icon;
  final IconData? selectedIcon;

  /// A small count shown beside the label (segmented control only).
  final int? badge;
}

/// The floating glass tab bar: a capsule of clear glass with a lens that
/// slides to the selected tab, stretching mid-way like a drop of liquid.
class GlassTabBar extends StatelessWidget {
  const GlassTabBar({super.key, required this.tabs, required this.selectedIndex, required this.onSelected});

  final List<GlassTab> tabs;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: 10),
      child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 300),
          child: GlassSurface(
            borderRadius: const BorderRadius.all(Radius.circular(999)),
            shadow: true,
            grouped: false,
            padding: const EdgeInsets.all(5),
            child: _LensRow(
              tabs: tabs,
              selectedIndex: selectedIndex,
              onSelected: onSelected,
              height: 56,
              vertical: true,
            ),
          ),
        ),
      ),
    );
  }
}

/// A glass segmented control with the same sliding lens as [GlassTabBar].
class GlassSegmentedControl extends StatelessWidget {
  const GlassSegmentedControl({super.key, required this.tabs, required this.selectedIndex, required this.onSelected});

  final List<GlassTab> tabs;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return GlassSurface(
      borderRadius: const BorderRadius.all(Radius.circular(999)),
      padding: const EdgeInsets.all(4),
      child: _LensRow(tabs: tabs, selectedIndex: selectedIndex, onSelected: onSelected, height: 40, vertical: false),
    );
  }
}

class _LensRow extends StatelessWidget {
  const _LensRow({
    required this.tabs,
    required this.selectedIndex,
    required this.onSelected,
    required this.height,
    required this.vertical,
  });

  final List<GlassTab> tabs;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final double height;
  final bool vertical;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return SizedBox(
      height: height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final slot = constraints.maxWidth / tabs.length;
          return Stack(
            children: [
              TweenAnimationBuilder<double>(
                tween: Tween(end: selectedIndex.toDouble()),
                duration: reduceMotion ? Duration.zero : const Duration(milliseconds: 460),
                curve: Curves.easeOutCubic,
                builder: (context, position, _) {
                  // Stretch while travelling between slots, settle round at rest.
                  final travel = math.sin((position - position.floorToDouble()) * math.pi);
                  final width = slot * (1 + 0.35 * travel);
                  final left = (position * slot - (width - slot) / 2).clamp(0.0, constraints.maxWidth - width);
                  return Positioned(
                    left: left,
                    top: 0,
                    bottom: 0,
                    width: width,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(999),
                        color: scheme.primary.withValues(alpha: 0.14),
                        border: Border.all(color: scheme.primary.withValues(alpha: 0.18)),
                      ),
                    ),
                  );
                },
              ),
              // Fill the control's height (a plain Stack child would size to its
              // text and sit at the top), so labels centre and taps cover the lens.
              Positioned.fill(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < tabs.length; i++)
                      Expanded(child: _tab(context, tabs[i], i == selectedIndex, () => _select(i))),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _select(int index) {
    if (index == selectedIndex) return;
    HapticFeedback.selectionClick();
    onSelected(index);
  }

  Widget _tab(BuildContext context, GlassTab tab, bool selected, VoidCallback onTap) {
    final theme = Theme.of(context);
    final color = selected ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant;
    final labelStyle = (vertical ? theme.textTheme.labelSmall : theme.textTheme.labelLarge)?.copyWith(
      color: color,
      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
    );
    final label = Text(tab.label, style: labelStyle);
    final badge = tab.badge == null
        ? null
        : Container(
            margin: const EdgeInsets.only(left: 6),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(999)),
            child: Text('${tab.badge}', style: theme.textTheme.labelSmall?.copyWith(color: color)),
          );
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: vertical
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(selected ? (tab.selectedIcon ?? tab.icon) : tab.icon, color: color, size: 24),
                  const SizedBox(height: 2),
                  label,
                ],
              )
            : Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  // Long labels with a count shrink to fit a narrow segment.
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(mainAxisSize: MainAxisSize.min, children: [label, ?badge]),
                  ),
                ),
              ),
      ),
    );
  }
}
