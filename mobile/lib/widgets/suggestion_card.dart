import 'package:flutter/material.dart';

import '../api/api_exception.dart';
import '../models/suggestion.dart';
import '../util/dates.dart';
import 'glass.dart';
import 'source_quote.dart';

typedef AcceptCallback = Future<void> Function(String description, String owner, String? dueDate);

/// One AI suggestion under review. Fields are editable; nothing is saved until
/// the reviewer taps Accept. The supporting quote is shown but not editable.
class SuggestionCard extends StatefulWidget {
  const SuggestionCard({super.key, required this.suggestion, required this.onAccept, required this.onDismiss});

  final Suggestion suggestion;
  final AcceptCallback onAccept;
  final Future<void> Function() onDismiss;

  @override
  State<SuggestionCard> createState() => _SuggestionCardState();
}

class _SuggestionCardState extends State<SuggestionCard> {
  late final TextEditingController _description = TextEditingController(text: widget.suggestion.description);
  late final TextEditingController _owner = TextEditingController(text: widget.suggestion.owner ?? '');
  late String? _dueDate = widget.suggestion.dueDate;
  bool _busy = false;
  String? _error;
  Map<String, List<String>> _fieldErrors = const {};

  @override
  void dispose() {
    _description.dispose();
    _owner.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
      _fieldErrors = const {};
    });
    try {
      await action();
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _fieldErrors = e.details;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _accept() async {
    if (_description.text.trim().isEmpty) {
      setState(
        () => _fieldErrors = {
          'description': ["can't be empty"],
        },
      );
      return;
    }
    await _run(() => widget.onAccept(_description.text.trim(), _owner.text.trim(), _dueDate));
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final initial = parseIsoDate(_dueDate) ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 10),
    );
    if (picked != null) setState(() => _dueDate = toIsoDate(picked));
  }

  String? _fieldError(String field) {
    final messages = _fieldErrors[field];
    return messages == null || messages.isEmpty ? null : messages.join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final id = widget.suggestion.id;
    final theme = Theme.of(context);
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, size: 16, color: theme.colorScheme.primary),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  'AI suggestion · review before accepting',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.primary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            key: Key('suggestion-$id-description'),
            controller: _description,
            enabled: !_busy,
            maxLines: null,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(labelText: 'Action', errorText: _fieldError('description')),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  key: Key('suggestion-$id-owner'),
                  controller: _owner,
                  enabled: !_busy,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: 'Owner',
                    hintText: 'Not assigned',
                    errorText: _fieldError('owner'),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Due date',
                    errorText: _fieldError('due_date'),
                    suffixIcon: _dueDate == null
                        ? null
                        : IconButton(
                            tooltip: 'Clear due date',
                            icon: const Icon(Icons.clear),
                            onPressed: _busy ? null : () => setState(() => _dueDate = null),
                          ),
                  ),
                  child: InkWell(
                    key: Key('suggestion-$id-due-date'),
                    onTap: _busy ? null : _pickDate,
                    child: Text(
                      _dueDate == null ? 'No date' : formatIsoDate(_dueDate!),
                      style: _dueDate == null ? TextStyle(color: theme.hintColor) : null,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SourceQuote(widget.suggestion.sourceQuote),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
          ],
          const SizedBox(height: 8),
          // Wraps onto two lines rather than overflowing on very narrow screens.
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            runSpacing: 8,
            children: [
              TextButton(
                key: Key('suggestion-$id-dismiss'),
                onPressed: _busy ? null : () => _run(widget.onDismiss),
                child: const Text('Dismiss'),
              ),
              FilledButton.icon(
                key: Key('suggestion-$id-accept'),
                onPressed: _busy ? null : _accept,
                icon: _busy
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.check),
                label: const Text('Accept'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
