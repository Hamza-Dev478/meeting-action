import 'package:flutter/material.dart';

import '../api/api_exception.dart';
import '../app_scope.dart';
import '../widgets/glass.dart';
import '../widgets/glass_page.dart';
import '../widgets/state_views.dart';
import 'meeting_detail_screen.dart';

class CreateMeetingScreen extends StatefulWidget {
  const CreateMeetingScreen({super.key});

  static const titleMaxLength = 200;
  static const notesMaxLength = 20000;

  @override
  State<CreateMeetingScreen> createState() => _CreateMeetingScreenState();
}

class _CreateMeetingScreenState extends State<CreateMeetingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _notes = TextEditingController();
  bool _saving = false;
  ApiException? _error;

  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    super.dispose();
  }

  String? _serverError(String field) {
    final messages = _error?.details[field];
    return messages == null || messages.isEmpty ? null : messages.join(', ');
  }

  Future<void> _save() async {
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final meeting = await AppScope.apiOf(context).createMeeting(title: _title.text.trim(), notes: _notes.text);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => MeetingDetailScreen(meetingId: meeting.id, title: meeting.title),
        ),
      );
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Form(
      key: _formKey,
      child: GlassPage(
        title: 'New meeting',
        actions: [
          TextButton(
            key: const Key('save-meeting'),
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Save'),
          ),
        ],
        children: [
          if (_error != null && _error!.details.isEmpty) StatusBanner(tone: BannerTone.error, message: _error!.message),
          GlassCard(
            child: Column(
              children: [
                TextFormField(
                  key: const Key('meeting-title'),
                  controller: _title,
                  enabled: !_saving,
                  maxLength: CreateMeetingScreen.titleMaxLength,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(labelText: 'Title', errorText: _serverError('title')),
                  validator: (value) => (value ?? '').trim().isEmpty ? 'Add a title' : null,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  key: const Key('meeting-notes'),
                  controller: _notes,
                  enabled: !_saving,
                  minLines: 8,
                  maxLines: null,
                  maxLength: CreateMeetingScreen.notesMaxLength,
                  keyboardType: TextInputType.multiline,
                  decoration: InputDecoration(
                    labelText: 'Notes',
                    hintText: 'Paste the meeting notes. Use synthetic notes only.',
                    alignLabelWithHint: true,
                    errorText: _serverError('notes'),
                  ),
                  validator: (value) => (value ?? '').trim().isEmpty ? 'Paste the meeting notes' : null,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 8, 6, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.verified_outlined, size: 18, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'After saving, AI proposes action items. Each one quotes your notes, '
                    'and nothing becomes an action until you accept it.',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
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
