import 'package:flutter/material.dart';

import '../api/api_exception.dart';
import '../app_scope.dart';
import '../models/meeting.dart';
import '../util/dates.dart';
import '../widgets/account_menu.dart';
import '../widgets/glass.dart';
import '../widgets/glass_page.dart';
import '../widgets/state_views.dart';
import 'create_meeting_screen.dart';
import 'meeting_detail_screen.dart';

class MeetingsScreen extends StatefulWidget {
  const MeetingsScreen({super.key});

  @override
  State<MeetingsScreen> createState() => _MeetingsScreenState();
}

class _MeetingsScreenState extends State<MeetingsScreen> {
  List<MeetingSummary>? _meetings;
  ApiException? _error;
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
      final meetings = await AppScope.apiOf(context).meetings();
      if (mounted) setState(() => _meetings = meetings);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _open(MeetingSummary meeting) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MeetingDetailScreen(meetingId: meeting.id, title: meeting.title),
      ),
    );
    if (mounted) _load();
  }

  Future<void> _create() async {
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const CreateMeetingScreen()));
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final meetings = _meetings;
    final fab = GlassButton(onPressed: _create, icon: Icons.add, label: 'New meeting');
    const actions = [AccountMenu()];

    if (meetings == null) {
      return GlassPage(
        title: 'Meetings',
        actions: actions,
        floatingActionButton: fab,
        body: _error != null
            ? ErrorView(message: _error!.message, onRetry: _load)
            : const LoadingView(message: 'Loading meetings…'),
      );
    }
    if (meetings.isEmpty) {
      return GlassPage(
        title: 'Meetings',
        actions: actions,
        floatingActionButton: fab,
        onRefresh: _load,
        body: const Center(
          child: EmptyView(
            icon: Icons.event_note_outlined,
            title: 'No meetings yet',
            message: 'Add a meeting and paste its notes to get AI-suggested action items.',
          ),
        ),
      );
    }
    return GlassPage(
      title: 'Meetings',
      actions: actions,
      floatingActionButton: fab,
      onRefresh: _load,
      children: [
        if (_error != null) StatusBanner(tone: BannerTone.error, message: _error!.message),
        for (final (index, meeting) in meetings.indexed)
          Entrance(
            index: index,
            child: _MeetingCard(meeting: meeting, onTap: () => _open(meeting)),
          ),
      ],
    );
  }
}

class _MeetingCard extends StatelessWidget {
  const _MeetingCard({required this.meeting, required this.onTap});

  final MeetingSummary meeting;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return GlassCard(
      key: Key('meeting-${meeting.id}'),
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DateBadge(date: meeting.createdAt),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                HeroTitle(tag: 'meeting-${meeting.id}', text: meeting.title, style: theme.textTheme.titleMedium!),
                const SizedBox(height: 2),
                Text(
                  '${formatDate(meeting.createdAt)} · ${meeting.authorName}',
                  style: theme.textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
                ),
                if (meeting.notesPreview.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    meeting.notesPreview,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: scheme.outline),
        ],
      ),
    );
  }
}

class _DateBadge extends StatelessWidget {
  const _DateBadge({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    return Container(
      width: 48,
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [primary.withValues(alpha: 0.22), primary.withValues(alpha: 0.08)],
        ),
        border: Border.all(color: primary.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          Text(
            monthAbbreviation(date).toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              color: primary,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
          Text('${date.day}', style: theme.textTheme.titleLarge?.copyWith(color: primary, height: 1.1)),
        ],
      ),
    );
  }
}
