import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../api/api_exception.dart';
import '../app_scope.dart';
import '../models/action_item.dart';
import '../util/dates.dart';
import '../widgets/account_menu.dart';
import '../widgets/action_item_tile.dart';
import '../widgets/glass.dart';
import '../widgets/glass_page.dart';
import '../widgets/glass_tab_bar.dart';
import '../widgets/state_views.dart';

/// Every action in the organization. The list is loaded once (`status=all`) so
/// the progress header can count open and completed items and switching filters
/// needs no request.
class ActionsScreen extends StatefulWidget {
  const ActionsScreen({super.key});

  @override
  State<ActionsScreen> createState() => _ActionsScreenState();
}

class _ActionsScreenState extends State<ActionsScreen> {
  static const _filters = [ActionFilter.open, ActionFilter.completed, ActionFilter.all];

  /// How long a just-toggled item stays in a list it no longer belongs to, so
  /// the tick lands before the row slides away.
  static const _linger = Duration(milliseconds: 650);

  ActionFilter _filter = ActionFilter.open;
  List<ActionItem>? _items;
  ApiException? _error;
  final Set<int> _busy = {};
  final Set<int> _lingering = {};
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      _load();
    }
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final items = await AppScope.apiOf(context).actionItems(ActionFilter.all);
      if (mounted) {
        setState(() {
          _items = items;
          _lingering.clear();
        });
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  void _setFilter(ActionFilter filter) => setState(() {
    _filter = filter;
    _lingering.clear();
  });

  bool _matchesFilter(ActionItem item) => switch (_filter) {
    ActionFilter.open => !item.completed,
    ActionFilter.completed => item.completed,
    ActionFilter.all => true,
  };

  Future<void> _toggle(ActionItem item, bool completed) async {
    setState(() => _busy.add(item.id));
    try {
      final updated = await AppScope.apiOf(context).setCompleted(item.id, completed);
      if (!mounted) return;
      setState(() {
        _items = [for (final existing in _items ?? <ActionItem>[]) existing.id == updated.id ? updated : existing];
        if (!_matchesFilter(updated)) _lingering.add(updated.id);
      });
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(completed ? 'Marked complete' : 'Marked open'),
            action: SnackBarAction(label: 'Undo', onPressed: () => _undo(updated, !completed)),
            // Flutter keeps a snack bar with an action up until it is tapped. Let
            // Undo time out like any other notice, except with a screen reader on,
            // where the user needs time to reach the button.
            duration: const Duration(seconds: 5),
            persist: MediaQuery.accessibleNavigationOf(context),
          ),
        );
      if (_lingering.contains(updated.id)) {
        await Future<void>.delayed(MediaQuery.disableAnimationsOf(context) ? Duration.zero : _linger);
        if (mounted) setState(() => _lingering.remove(updated.id));
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _busy.remove(item.id));
    }
  }

  Future<void> _undo(ActionItem item, bool completed) async {
    try {
      await AppScope.apiOf(context).setCompleted(item.id, completed);
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    const actions = [AccountMenu()];
    final items = _items;
    if (items == null) {
      return GlassPage(
        title: 'Actions',
        actions: actions,
        body: _error != null
            ? ErrorView(message: _error!.message, onRetry: _load)
            : const LoadingView(message: 'Loading actions…'),
      );
    }

    final done = items.where((item) => item.completed).length;
    final visible = items.where((item) => _matchesFilter(item) || _lingering.contains(item.id)).toList();
    return GlassPage(
      title: 'Actions',
      actions: actions,
      onRefresh: _load,
      children: [
        if (_error != null) StatusBanner(tone: BannerTone.error, message: _error!.message),
        if (items.isNotEmpty) _ProgressHeader(items: items, done: done),
        const SizedBox(height: 8),
        GlassSegmentedControl(
          selectedIndex: _filters.indexOf(_filter),
          onSelected: (index) => _setFilter(_filters[index]),
          tabs: [
            GlassTab(label: 'Open', badge: items.length - done),
            GlassTab(label: 'Completed', badge: done),
            GlassTab(label: 'All', badge: items.length),
          ],
        ),
        const SizedBox(height: 8),
        if (visible.isEmpty)
          EmptyView(
            icon: Icons.checklist_rtl,
            title: switch (_filter) {
              ActionFilter.open => items.isEmpty ? 'No open actions' : 'All caught up',
              ActionFilter.completed => 'Nothing completed yet',
              ActionFilter.all => 'No actions yet',
            },
            message: 'Accepted suggestions from your meetings appear here.',
          )
        else
          ..._sections(visible),
      ],
    );
  }

  /// Open items are grouped by urgency; completed ones follow under "Done".
  List<Widget> _sections(List<ActionItem> visible) {
    if (_filter == ActionFilter.completed) return [_group(null, visible)];

    final today = DateTime.now();
    final groups = <String, List<ActionItem>>{
      'Overdue': [],
      'Due this week': [],
      'Later': [],
      'No due date': [],
      'Done': [],
    };
    for (final item in visible) {
      // A just-completed item stays in its group until it slides away.
      final key = item.completed && !_lingering.contains(item.id)
          ? 'Done'
          : switch (dueBucket(item.dueDate, today)) {
              DueBucket.overdue => 'Overdue',
              DueBucket.thisWeek => 'Due this week',
              DueBucket.later => 'Later',
              DueBucket.none => 'No due date',
            };
      groups[key]!.add(item);
    }
    return [
      for (final entry in groups.entries)
        if (entry.value.isNotEmpty) _group(entry.key, entry.value),
    ];
  }

  Widget _group(String? title, List<ActionItem> items) {
    final theme = Theme.of(context);
    final color = title == 'Overdue' ? theme.colorScheme.error : theme.colorScheme.onSurfaceVariant;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (title != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 14, 6, 2),
            child: Text(
              title,
              style: theme.textTheme.labelLarge?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
          ),
        for (final (index, item) in items.indexed)
          AnimatedSize(
            key: ValueKey('row-${item.id}'),
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            child: Entrance(
              index: index,
              child: GlassCard(
                padding: EdgeInsets.zero,
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: ActionItemTile(
                  item: item,
                  busy: _busy.contains(item.id),
                  onToggle: (value) => _toggle(item, value),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _ProgressHeader extends StatelessWidget {
  const _ProgressHeader({required this.items, required this.done});

  final List<ActionItem> items;
  final int done;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final today = DateTime.now();
    final open = items.where((item) => !item.completed).toList();
    final overdue = open.where((item) => dueBucket(item.dueDate, today) == DueBucket.overdue).length;
    final thisWeek = open.where((item) => dueBucket(item.dueDate, today) == DueBucket.thisWeek).length;
    final summary = open.isEmpty
        ? 'All caught up. Nice work.'
        : [
            if (overdue > 0) '$overdue overdue',
            if (thisWeek > 0) '$thisWeek due this week',
            if (overdue == 0 && thisWeek == 0) 'Nothing due this week',
          ].join(' · ');

    return GlassCard(
      child: Row(
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(end: items.isEmpty ? 0 : done / items.length),
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) => _ProgressRing(value: value),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$done of ${items.length} done', style: theme.textTheme.titleLarge),
                const SizedBox(height: 2),
                Text(
                  summary,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: overdue > 0 ? scheme.error : scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressRing extends StatelessWidget {
  const _ProgressRing({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: '${(value * 100).round()} percent done',
      child: SizedBox(
        width: 64,
        height: 64,
        child: CustomPaint(
          painter: _RingPainter(
            value: value,
            track: scheme.onSurface.withValues(alpha: 0.08),
            colors: [scheme.primary, scheme.tertiary],
          ),
          child: Center(
            child: Text(
              '${(value * 100).round()}%',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.value, required this.track, required this.colors});

  final double value;
  final Color track;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 7.0;
    final rect = (Offset.zero & size).deflate(stroke / 2);
    canvas.drawArc(
      rect,
      0,
      2 * math.pi,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = track,
    );
    if (value <= 0) return;
    canvas.drawArc(
      rect,
      -math.pi / 2,
      2 * math.pi * value,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..shader = SweepGradient(
          startAngle: -math.pi / 2,
          endAngle: 3 * math.pi / 2,
          colors: colors,
          transform: const GradientRotation(-math.pi / 2),
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) => oldDelegate.value != value || oldDelegate.colors != colors;
}
