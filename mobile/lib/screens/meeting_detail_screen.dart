import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api/api_exception.dart';
import '../app_scope.dart';
import '../models/action_item.dart';
import '../models/meeting.dart';
import '../models/suggestion.dart';
import '../widgets/action_item_tile.dart';
import '../widgets/generation_progress.dart';
import '../widgets/glass.dart';
import '../widgets/glass_page.dart';
import '../widgets/state_views.dart';
import '../widgets/suggestion_card.dart';

/// Meeting notes, AI suggestion review, and the actions accepted from it.
class MeetingDetailScreen extends StatefulWidget {
  const MeetingDetailScreen({super.key, required this.meetingId, required this.title});

  final int meetingId;
  final String title;

  @override
  State<MeetingDetailScreen> createState() => _MeetingDetailScreenState();
}

class _MeetingDetailScreenState extends State<MeetingDetailScreen> {
  MeetingDetail? _meeting;
  ApiException? _loadError;
  bool _loading = true;
  bool _generating = false;
  ApiException? _generationError;
  final Set<int> _togglingActions = {};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_meeting == null && _loadError == null && _loading) _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final meeting = await AppScope.apiOf(context).meeting(widget.meetingId);
      if (!mounted) return;
      setState(() => _meeting = meeting);
    } on ApiException catch (e) {
      if (mounted) setState(() => _loadError = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _refresh() async {
    setState(() => _generationError = null);
    await _load();
  }

  Future<void> _generate() async {
    final meeting = _meeting!;
    if (meeting.suggestions.isNotEmpty) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Replace suggestions?'),
          content: const Text('Suggestions you have not accepted yet will be replaced by a new set.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Regenerate')),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }

    setState(() {
      _generating = true;
      _generationError = null;
    });
    try {
      final result = await AppScope.apiOf(context).generateSuggestions(meeting.id);
      if (!mounted) return;
      setState(() {
        _meeting = MeetingDetail(
          id: meeting.id,
          title: meeting.title,
          notes: meeting.notes,
          latestGeneration: result.generation,
          suggestions: result.suggestions,
          actionItems: meeting.actionItems,
        );
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _generationError = e);
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  void _replace({List<Suggestion>? suggestions, List<ActionItem>? actionItems}) {
    final meeting = _meeting!;
    setState(() {
      _meeting = MeetingDetail(
        id: meeting.id,
        title: meeting.title,
        notes: meeting.notes,
        latestGeneration: meeting.latestGeneration,
        suggestions: suggestions ?? meeting.suggestions,
        actionItems: actionItems ?? meeting.actionItems,
      );
    });
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _accept(Suggestion suggestion, String description, String owner, String? dueDate) async {
    try {
      final result = await AppScope.apiOf(context)
          .acceptSuggestion(suggestion.id, description: description, owner: owner, dueDate: dueDate);
      if (!mounted) return;
      final meeting = _meeting!;
      _replace(
        suggestions: meeting.suggestions.where((s) => s.id != suggestion.id).toList(),
        actionItems: [...meeting.actionItems.where((a) => a.id != result.actionItem.id), result.actionItem],
      );
      if (result.created) HapticFeedback.lightImpact();
      _snack(result.created ? 'Added to actions' : 'This suggestion was already accepted');
    } on ApiException catch (e) {
      if (e.code != 'suggestion_not_pending') rethrow;
      if (!mounted) return;
      _snack(e.message);
      await _load();
    }
  }

  Future<void> _dismiss(Suggestion suggestion) async {
    try {
      await AppScope.apiOf(context).dismissSuggestion(suggestion.id);
      if (!mounted) return;
      _replace(suggestions: _meeting!.suggestions.where((s) => s.id != suggestion.id).toList());
    } on ApiException catch (e) {
      if (e.code != 'suggestion_not_pending') rethrow;
      if (!mounted) return;
      _snack(e.message);
      await _load();
    }
  }

  Future<void> _toggle(ActionItem item, bool completed) async {
    setState(() => _togglingActions.add(item.id));
    try {
      final updated = await AppScope.apiOf(context).setCompleted(item.id, completed);
      if (!mounted) return;
      _replace(actionItems: _meeting!.actionItems.map((a) => a.id == updated.id ? updated : a).toList());
    } on ApiException catch (e) {
      if (mounted) _snack(e.message);
    } finally {
      if (mounted) setState(() => _togglingActions.remove(item.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _meeting?.title ?? widget.title;
    final heroTag = 'meeting-${widget.meetingId}';
    final meeting = _meeting;
    if (meeting == null) {
      return GlassPage(
        title: title,
        heroTag: heroTag,
        body: _loadError != null
            ? ErrorView(message: _loadError!.message, onRetry: _load)
            : const LoadingView(message: 'Loading meeting…'),
      );
    }

    final theme = Theme.of(context);
    final generation = meeting.latestGeneration;
    final pending = meeting.suggestions.length;
    return GlassPage(
      title: title,
      heroTag: heroTag,
      onRefresh: _refresh,
      children: [
        // A reload can fail after the meeting was shown (pull to refresh, or the
        // automatic reload after a stale accept); keep the old data but say so.
        if (_loadError != null) ...[
          StatusBanner(
            tone: BannerTone.error,
            message: "Couldn't refresh this meeting. ${_loadError!.message}",
            actions: [TextButton(onPressed: _loading ? null : _load, child: const Text('Try again'))],
          ),
          const SizedBox(height: 4),
        ],
        GlassCard(
          padding: EdgeInsets.zero,
          child: ExpansionTile(
            leading: Icon(Icons.notes_rounded, color: theme.colorScheme.primary),
            title: const Text('Meeting notes'),
            initiallyExpanded: meeting.suggestions.isEmpty && meeting.actionItems.isEmpty,
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [SelectableText(meeting.notes, style: theme.textTheme.bodyMedium?.copyWith(height: 1.45))],
          ),
        ),
        const SizedBox(height: 18),
        // The button drops below the heading on narrow screens instead of overflowing.
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          runSpacing: 10,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(child: Text('Suggestions', style: theme.textTheme.titleLarge)),
                if (pending > 0) ...[const SizedBox(width: 8), _CountPill(count: pending)],
              ],
            ),
            GlassButton(
              onPressed: _generating ? null : _generate,
              busy: _generating,
              icon: Icons.auto_awesome,
              label: generation == null ? 'Generate suggestions' : 'Regenerate',
            ),
          ],
        ),
        const SizedBox(height: 10),
        AnimatedSize(
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ..._generationStatus(meeting),
              if (meeting.suggestions.isEmpty && !_generating)
                _noSuggestions(meeting)
              else
                for (final (index, suggestion) in meeting.suggestions.indexed)
                  Entrance(
                    key: ValueKey('suggestion-${suggestion.id}'),
                    index: index,
                    child: SuggestionCard(
                      suggestion: suggestion,
                      onAccept: (description, owner, dueDate) => _accept(suggestion, description, owner, dueDate),
                      onDismiss: () => _dismiss(suggestion),
                    ),
                  ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        Row(
          children: [
            Flexible(child: Text('Accepted actions', style: theme.textTheme.titleLarge)),
            if (meeting.actionItems.isNotEmpty) ...[
              const SizedBox(width: 8),
              _CountPill(count: meeting.actionItems.length),
            ],
          ],
        ),
        const SizedBox(height: 6),
        if (meeting.actionItems.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Nothing accepted from this meeting yet.',
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            ),
          )
        else
          GlassCard(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                for (final item in meeting.actionItems)
                  ActionItemTile(
                    item: item,
                    showMeeting: false,
                    busy: _togglingActions.contains(item.id),
                    onToggle: (value) => _toggle(item, value),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  List<Widget> _generationStatus(MeetingDetail meeting) {
    if (_generating) return const [GenerationProgress()];

    final error = _generationError;
    if (error != null) {
      // On a client timeout or an in-flight conflict the server may still be
      // working, so the safe next step is to refresh rather than to generate again.
      final refreshFirst = error.isClientTimeout || error.code == 'generation_in_progress';
      return [
        StatusBanner(
          tone: BannerTone.error,
          message: error.message,
          actions: [
            if (refreshFirst) TextButton(onPressed: _refresh, child: const Text('Refresh')),
            if (!refreshFirst && error.retryable) TextButton(onPressed: _generate, child: const Text('Try again')),
          ],
        ),
      ];
    }

    final generation = meeting.latestGeneration;
    if (generation != null && generation.isFailed) {
      // The last run failed, possibly after this app gave up waiting or was closed.
      return [
        StatusBanner(
          tone: BannerTone.error,
          message:
              'The last attempt to generate suggestions failed: '
              '${generation.errorMessage ?? 'unknown error'}',
          actions: [TextButton(onPressed: _generate, child: const Text('Try again'))],
        ),
      ];
    }
    if (generation != null && generation.isRunning) {
      return [
        StatusBanner(
          message: 'Suggestions are still being generated for this meeting.',
          actions: [TextButton(onPressed: _refresh, child: const Text('Refresh'))],
        ),
      ];
    }
    if (generation != null && generation.isSucceeded && generation.rejectedCount > 0) {
      final count = generation.rejectedCount;
      return [
        StatusBanner(
          message:
              '$count AI suggestion${count == 1 ? ' was' : 's were'} discarded because '
              '${count == 1 ? 'it was' : 'they were'} not supported by the notes.',
        ),
      ];
    }
    return const [];
  }

  Widget _noSuggestions(MeetingDetail meeting) {
    final generation = meeting.latestGeneration;
    if (generation == null) {
      return const EmptyView(
        icon: Icons.auto_awesome_outlined,
        title: 'No suggestions yet',
        message: 'Generate suggestions to have AI propose action items from these notes. You review each one first.',
      );
    }
    if (!generation.isSucceeded) {
      return const EmptyView(
        icon: Icons.auto_awesome_outlined,
        title: 'No suggestions yet',
        message: 'Suggestions will appear here once a generation succeeds.',
      );
    }
    if (generation.suggestionCount == 0) {
      return const EmptyView(
        icon: Icons.inbox_outlined,
        title: 'No commitments found',
        message: 'The AI did not find any agreed action items in these notes.',
      );
    }
    return const EmptyView(
      icon: Icons.task_alt,
      title: 'All suggestions reviewed',
      message: 'Nothing is waiting for review.',
    );
  }
}

class _CountPill extends StatelessWidget {
  const _CountPill({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: primary.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(999)),
      child: Text(
        '$count',
        style: theme.textTheme.labelMedium?.copyWith(color: primary, fontWeight: FontWeight.w700),
      ),
    );
  }
}
