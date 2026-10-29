class Suggestion {
  const Suggestion({
    required this.id,
    required this.meetingId,
    required this.status,
    required this.description,
    required this.sourceQuote,
    this.owner,
    this.dueDate,
  });

  final int id;
  final int meetingId;
  final String status;
  final String description;
  final String? owner;

  /// Date-only `YYYY-MM-DD`, kept as text so it never shifts across time zones.
  final String? dueDate;
  final String sourceQuote;

  factory Suggestion.fromJson(Map<String, dynamic> json) => Suggestion(
    id: json['id'] as int,
    meetingId: json['meeting_id'] as int,
    status: json['status'] as String,
    description: json['description'] as String,
    owner: json['owner'] as String?,
    dueDate: json['due_date'] as String?,
    sourceQuote: json['source_quote'] as String,
  );
}
