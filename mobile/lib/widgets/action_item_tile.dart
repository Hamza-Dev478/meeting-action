import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/action_item.dart';
import '../util/dates.dart';
import 'glass.dart';
import 'source_quote.dart';

class ActionItemTile extends StatelessWidget {
  const ActionItemTile({
    super.key,
    required this.item,
    required this.onToggle,
    this.busy = false,
    this.showMeeting = true,
  });

  final ActionItem item;
  final ValueChanged<bool> onToggle;
  final bool busy;
  final bool showMeeting;

  void _showDetails(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      builder: (context) {
        final theme = Theme.of(context);
        return Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
          child: GlassSurface(
            strong: true,
            grouped: false,
            borderRadius: const BorderRadius.all(Radius.circular(28)),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 5,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(item.description, style: theme.textTheme.titleLarge),
                  const SizedBox(height: 6),
                  Text(
                    'From "${item.meetingTitle}" · accepted by ${item.acceptedByName}',
                    style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                  if (item.edited && item.originalDescription != null) ...[
                    const SizedBox(height: 8),
                    Text('AI suggested: ${item.originalDescription}', style: theme.textTheme.bodySmall),
                  ],
                  const SizedBox(height: 16),
                  SourceQuote(item.sourceQuote),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _toggle(bool completed) {
    // A firmer tap for finishing something than for reopening it.
    completed ? HapticFeedback.mediumImpact() : HapticFeedback.selectionClick();
    onToggle(completed);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final bucket = item.completed ? DueBucket.none : dueBucket(item.dueDate, DateTime.now());
    final dueColor = switch (bucket) {
      DueBucket.overdue => scheme.error,
      DueBucket.thisWeek => scheme.tertiary,
      _ => scheme.onSurfaceVariant,
    };
    final chips = [
      if (item.owner != null) _Chip(icon: Icons.person_outline, label: item.owner!),
      if (item.dueDate != null)
        _Chip(
          icon: bucket == DueBucket.overdue ? Icons.warning_amber_rounded : Icons.event_outlined,
          label: '${bucket == DueBucket.overdue ? 'Overdue · ' : 'Due '}${formatIsoDate(item.dueDate!)}',
          color: dueColor,
        ),
      if (showMeeting) _Chip(icon: Icons.event_note_outlined, label: item.meetingTitle),
    ];

    return ListTile(
      key: Key('action-${item.id}'),
      onTap: () => _showDetails(context),
      contentPadding: const EdgeInsets.fromLTRB(8, 4, 12, 4),
      leading: SizedBox(
        width: 40,
        child: Center(
          child: busy
              ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
              : AnimatedScale(
                  scale: item.completed ? 1.18 : 1.08,
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutBack,
                  child: Checkbox(
                    key: Key('action-${item.id}-checkbox'),
                    value: item.completed,
                    onChanged: (value) => _toggle(value ?? false),
                  ),
                ),
        ),
      ),
      title: AnimatedDefaultTextStyle(
        duration: const Duration(milliseconds: 260),
        style: (theme.textTheme.bodyLarge ?? const TextStyle()).copyWith(
          fontWeight: FontWeight.w500,
          color: item.completed ? scheme.onSurfaceVariant : scheme.onSurface,
          decoration: item.completed ? TextDecoration.lineThrough : TextDecoration.none,
        ),
        child: Text(item.description),
      ),
      subtitle: chips.isEmpty
          ? null
          : Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Wrap(spacing: 6, runSpacing: 6, children: chips),
            ),
      trailing: item.edited
          ? Tooltip(
              message: 'Edited before accepting',
              child: Icon(Icons.edit_note, color: scheme.outline),
            )
          : null,
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.label, this.color});

  final IconData icon;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tone = color ?? theme.colorScheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: tone.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: tone),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(color: tone, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
