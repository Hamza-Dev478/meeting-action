class ActionItem {
  const ActionItem({
    required this.id,
    required this.suggestionId,
    required this.meetingId,
    required this.meetingTitle,
    required this.description,
    required this.sourceQuote,
    required this.edited,
    required this.completed,
    required this.acceptedByName,
    this.owner,
    this.dueDate,
    this.originalDescription,
  });

  final int id;
  final int suggestionId;
  final int meetingId;
  final String meetingTitle;
  final String description;
  final String? owner;
  final String? dueDate;

  /// The excerpt from the notes the AI cited; kept even when the item was edited.
  final String sourceQuote;
  final bool edited;
  final String? originalDescription;
  final bool completed;
  final String acceptedByName;

  ActionItem copyWith({bool? completed}) => ActionItem(
    id: id,
    suggestionId: suggestionId,
    meetingId: meetingId,
    meetingTitle: meetingTitle,
    description: description,
    owner: owner,
    dueDate: dueDate,
    sourceQuote: sourceQuote,
    edited: edited,
    originalDescription: originalDescription,
    completed: completed ?? this.completed,
    acceptedByName: acceptedByName,
  );

  factory ActionItem.fromJson(Map<String, dynamic> json) {
    final meeting = json['meeting'] as Map<String, dynamic>;
    final original = json['original'] as Map<String, dynamic>?;
    return ActionItem(
      id: json['id'] as int,
      suggestionId: json['suggestion_id'] as int,
      meetingId: meeting['id'] as int,
      meetingTitle: meeting['title'] as String,
      description: json['description'] as String,
      owner: json['owner'] as String?,
      dueDate: json['due_date'] as String?,
      sourceQuote: json['source_quote'] as String,
      edited: json['edited'] as bool? ?? false,
      originalDescription: original?['description'] as String?,
      completed: json['completed'] as bool? ?? false,
      acceptedByName: json['accepted_by_name'] as String? ?? '',
    );
  }
}
