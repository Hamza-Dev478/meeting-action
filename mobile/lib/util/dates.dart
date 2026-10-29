const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

String _two(int n) => n.toString().padLeft(2, '0');

/// Due dates are date-only `YYYY-MM-DD` strings end to end.
String toIsoDate(DateTime date) => '${date.year.toString().padLeft(4, '0')}-${_two(date.month)}-${_two(date.day)}';

DateTime? parseIsoDate(String? value) {
  if (value == null) return null;
  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value);
  if (match == null) return null;
  return DateTime(int.parse(match[1]!), int.parse(match[2]!), int.parse(match[3]!));
}

/// `2027-02-12` -> `Feb 12, 2027`; unknown formats are shown unchanged.
String formatIsoDate(String value) {
  final date = parseIsoDate(value);
  return date == null ? value : formatDate(date);
}

String formatDate(DateTime date) => '${_months[date.month - 1]} ${date.day}, ${date.year}';

String monthAbbreviation(DateTime date) => _months[date.month - 1];

enum DueBucket { overdue, thisWeek, later, none }

/// Groups a `YYYY-MM-DD` due date relative to [today]: "this week" is today
/// and the next 7 days. Anything unparseable counts as having no date.
DueBucket dueBucket(String? value, DateTime today) {
  final date = parseIsoDate(value);
  if (date == null) return DueBucket.none;
  final start = DateTime(today.year, today.month, today.day);
  if (date.isBefore(start)) return DueBucket.overdue;
  if (!date.isAfter(DateTime(start.year, start.month, start.day + 7))) return DueBucket.thisWeek;
  return DueBucket.later;
}
