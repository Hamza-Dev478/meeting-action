import 'package:flutter_test/flutter_test.dart';
import 'package:meeting_action/util/dates.dart';

void main() {
  final today = DateTime(2026, 10, 30);

  test('due dates fall into overdue, this week, later, or none', () {
    expect(dueBucket('2026-10-29', today), DueBucket.overdue);
    expect(dueBucket('2026-10-30', today), DueBucket.thisWeek);
    expect(dueBucket('2026-11-06', today), DueBucket.thisWeek);
    expect(dueBucket('2026-11-07', today), DueBucket.later);
    expect(dueBucket(null, today), DueBucket.none);
    expect(dueBucket('next Friday', today), DueBucket.none);
  });
}
