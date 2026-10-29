import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/glass_theme.dart';
import 'glass.dart';

/// Shown while the server generates suggestions: a pulsing orb, a status line
/// that walks through what the server is doing, and shimmering placeholder
/// cards where the suggestions will appear. Still when motion is reduced.
class GenerationProgress extends StatefulWidget {
  const GenerationProgress({super.key});

  /// These describe the server's real pipeline: the provider drafts
  /// suggestions, then each one is checked against the notes before it is kept.
  static const phases = ['Reading your notes', 'Finding commitments', 'Checking each one against the notes'];

  @override
  State<GenerationProgress> createState() => _GenerationProgressState();
}

class _GenerationProgressState extends State<GenerationProgress> with TickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );
  late final AnimationController _phase = AnimationController(vsync: this, duration: const Duration(seconds: 9));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _pulse.stop();
      _phase.stop();
    } else {
      if (!_pulse.isAnimating) _pulse.repeat();
      if (!_phase.isAnimating) _phase.repeat();
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    _phase.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GlassCard(
          child: Row(
            children: [
              AnimatedBuilder(
                animation: _pulse,
                builder: (context, child) {
                  final wave = math.sin(_pulse.value * 2 * math.pi);
                  return Transform.scale(scale: 1 + 0.07 * wave, child: child);
                },
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const SweepGradient(colors: GlassTheme.accentSweep),
                    boxShadow: [BoxShadow(color: GlassTheme.accentSweep.first.withValues(alpha: 0.45), blurRadius: 18)],
                  ),
                  child: SizedBox(
                    width: 48,
                    height: 48,
                    child: Icon(Icons.auto_awesome, color: scheme.onPrimary, size: 24),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AnimatedBuilder(
                      animation: _phase,
                      builder: (context, _) {
                        final index = (_phase.value * GenerationProgress.phases.length).floor().clamp(0, 2);
                        return AnimatedSwitcher(
                          duration: const Duration(milliseconds: 350),
                          child: Text(
                            '${GenerationProgress.phases[index]}…',
                            key: ValueKey(index),
                            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'This can take up to a minute. You review every suggestion before it becomes an action.',
                      style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        for (var i = 0; i < 2; i++) _SkeletonCard(shimmer: _pulse, lines: i == 0 ? 3 : 2),
      ],
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard({required this.shimmer, required this.lines});

  final Animation<double> shimmer;
  final int lines;

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08);
    final highlight = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.16);
    return ExcludeSemantics(
      child: GlassCard(
        child: AnimatedBuilder(
          animation: shimmer,
          builder: (context, _) {
            final x = shimmer.value * 3 - 1;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var line = 0; line < lines; line++) ...[
                  FractionallySizedBox(
                    widthFactor: line == lines - 1 ? 0.55 : 1,
                    child: Container(
                      height: 12,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        gradient: LinearGradient(
                          begin: Alignment(x - 1, 0),
                          end: Alignment(x + 1, 0),
                          colors: [base, highlight, base],
                        ),
                      ),
                    ),
                  ),
                  if (line < lines - 1) const SizedBox(height: 10),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}
