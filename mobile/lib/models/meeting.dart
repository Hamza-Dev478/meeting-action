import 'action_item.dart';
import 'generation.dart';
import 'suggestion.dart';

class MeetingSummary {
  const MeetingSummary({
    required this.id,
    required this.title,
    required this.notesPreview,
    required this.authorName,
    required this.createdAt,
  });

  final int id;
  final String title;
  final String notesPreview;
  final String authorName;
  final DateTime createdAt;

  factory MeetingSummary.fromJson(Map<String, dynamic> json) => MeetingSummary(
    id: json['id'] as int,
    title: json['title'] as String,
    notesPreview: json['notes_preview'] as String? ?? '',
    authorName: json['author_name'] as String? ?? '',
    createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
  );
}

/// GET /meetings/:id: the meeting plus everything the review screen shows.
class MeetingDetail {
  const MeetingDetail({
    required this.id,
    required this.title,
    required this.notes,
    required this.suggestions,
    required this.actionItems,
    this.latestGeneration,
  });

  final int id;
  final String title;
  final String notes;
  final Generation? latestGeneration;

  /// Pending suggestions awaiting review.
  final List<Suggestion> suggestions;

  /// Actions already accepted from this meeting.
  final List<ActionItem> actionItems;

  factory MeetingDetail.fromJson(Map<String, dynamic> json) {
    final meeting = json['meeting'] as Map<String, dynamic>;
    final generation = json['latest_generation'];
    return MeetingDetail(
      id: meeting['id'] as int,
      title: meeting['title'] as String,
      notes: meeting['notes'] as String,
      latestGeneration: generation is Map<String, dynamic> ? Generation.fromJson(generation) : null,
      suggestions: (json['suggestions'] as List? ?? [])
          .map((s) => Suggestion.fromJson(s as Map<String, dynamic>))
          .toList(),
      actionItems: (json['action_items'] as List? ?? [])
          .map((a) => ActionItem.fromJson(a as Map<String, dynamic>))
          .toList(),
    );
  }
}

class GenerationResult {
  const GenerationResult({required this.generation, required this.suggestions});

  final Generation generation;
  final List<Suggestion> suggestions;
}

class AcceptResult {
  const AcceptResult({required this.actionItem, required this.created});

  final ActionItem actionItem;

  /// False when the suggestion had already been accepted (first acceptance wins).
  final bool created;
}
