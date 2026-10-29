// Drives the real app UI against a running Rails API (and its PostgreSQL),
// without a simulator. Skipped unless LIVE_API_BASE_URL is defined:
//
//   cd backend && bin/rails server                      # API on :3000
//   bin/rails "ai:fake_mode[malformed_once]"            # optional: exercise the error path once
//   cd mobile && flutter test test/live_backend_test.dart --dart-define=LIVE_API_BASE_URL=http://localhost:3000
//
// It creates a real meeting for maya@acme.test in the development database
// ("Release readiness check-in · HH:MM:SS"). Reset the demo data afterwards
// with `bin/rails db:seed:replant`.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:meeting_action/app.dart';
import 'package:meeting_action/config.dart';
import 'package:meeting_action/session/session_store.dart';
import 'package:meeting_action/widgets/suggestion_card.dart';

const liveBaseUrl = String.fromEnvironment('LIVE_API_BASE_URL');

/// Lets real network I/O complete, pumping frames until [finder] matches.
Future<void> waitFor(WidgetTester tester, Finder finder, {Duration timeout = const Duration(seconds: 20)}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pump(const Duration(milliseconds: 50));
    if (finder.evaluate().isNotEmpty) {
      // Let route transitions and snack bar animations finish before the next tap.
      await tester.pump(const Duration(milliseconds: 600));
      return;
    }
  }
  final visible = find.byType(Text).evaluate().map((e) => (e.widget as Text).data).whereType<String>().join(' | ');
  fail('Timed out waiting for $finder. Visible text: $visible');
}

Future<void> tapAndWait(WidgetTester tester, Finder target, Finder expected) async {
  await tester.ensureVisible(target);
  await tester.tap(target);
  await waitFor(tester, expected);
}

void main() {
  testWidgets('sign in, create, generate, edit + accept, complete, restart', (tester) async {
    HttpOverrides.global = null; // flutter_test blocks real HTTP by default
    await tester.binding.setSurfaceSize(const Size(430, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final store = InMemorySessionStore();
    final config = AppConfig(apiBaseUrl: Uri.parse(liveBaseUrl));
    // Readable in the demo database, and unique per run so the test finds its own rows.
    final now = DateTime.now();
    final runId =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:'
        '${now.second.toString().padLeft(2, '0')}';
    final title = 'Release readiness check-in · $runId';
    final edited = 'Prepare and circulate the release summary · $runId';

    await tester.pumpWidget(MeetingActionApp(config: config, sessionStore: store, httpClient: http.Client()));
    await waitFor(tester, find.text('Sign in as a test user'));

    await tapAndWait(tester, find.byKey(const Key('sign-in-maya@acme.test')), find.text('New meeting'));

    await tapAndWait(tester, find.text('New meeting'), find.byKey(const Key('meeting-title')));
    await tester.enterText(find.byKey(const Key('meeting-title')), title);
    await tester.enterText(
      find.byKey(const Key('meeting-notes')),
      'Ari will prepare the release summary by 2027-03-10. Decision: update the onboarding guide.',
    );
    await tapAndWait(tester, find.byKey(const Key('save-meeting')), find.text('Generate suggestions'));

    await tester.tap(find.text('Generate suggestions'));
    await waitFor(
      tester,
      find.byType(SuggestionCard).evaluate().isNotEmpty
          ? find.byType(SuggestionCard)
          : find.byWidgetPredicate(
              (w) => w is SuggestionCard || (w is Text && (w.data ?? '').contains('could not use')),
            ),
    );
    if (find.textContaining('could not use').evaluate().isNotEmpty) {
      debugPrint('LIVE: first generation failed as injected; retrying');
      await tapAndWait(tester, find.text('Try again'), find.byType(SuggestionCard));
    }
    expect(find.byType(SuggestionCard), findsNWidgets(2));
    debugPrint('LIVE: 2 suggestions shown');

    final firstDescription = find
        .descendant(of: find.byType(SuggestionCard).first, matching: find.byType(TextField))
        .first;
    await tester.enterText(firstDescription, edited);
    final accept = find.descendant(of: find.byType(SuggestionCard).first, matching: find.text('Accept'));
    await tapAndWait(tester, accept, find.text('Added to actions'));
    expect(find.byType(SuggestionCard), findsOneWidget);
    debugPrint('LIVE: accepted edited suggestion');

    await tester.pageBack();
    await waitFor(tester, find.text(title));
    await tapAndWait(tester, find.text('Actions'), find.text(edited));

    final checkbox = find.descendant(
      of: find.ancestor(of: find.text(edited), matching: find.byType(ListTile)),
      matching: find.byType(Checkbox),
    );
    await tapAndWait(tester, checkbox, find.text('Marked complete'));
    debugPrint('LIVE: marked complete');

    // Restart: throw the widget tree away and start a new app with the same stored session.
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
      MeetingActionApp(key: UniqueKey(), config: config, sessionStore: store, httpClient: http.Client()),
    );
    await waitFor(tester, find.text('New meeting'));
    await tapAndWait(tester, find.text('Actions'), find.text('Completed'));
    await tapAndWait(tester, find.text('Completed'), find.text(edited));
    final restored = find.descendant(
      of: find.ancestor(of: find.text(edited), matching: find.byType(ListTile)),
      matching: find.byType(Checkbox),
    );
    expect(tester.widget<Checkbox>(restored).value, isTrue);
    debugPrint('LIVE: completed action still completed after restart');

    // Request timeouts are timers on the test's fake clock; run them out before the test ends.
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 90));
  }, skip: liveBaseUrl.isEmpty);
}
