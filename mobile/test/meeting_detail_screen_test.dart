import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:meeting_action/api/api_client.dart';
import 'package:meeting_action/app_scope.dart';
import 'package:meeting_action/screens/meeting_detail_screen.dart';
import 'package:meeting_action/widgets/suggestion_card.dart';

const notes = 'Ari will prepare the release summary by 2027-03-10.';

http.Response jsonResponse(Object body, int status) =>
    http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json'});

Map<String, dynamic> meetingJson() => {
  'meeting': {
    'id': 1,
    'title': 'Release',
    'notes': notes,
    'notes_preview': notes,
    'author_name': 'Ari',
    'created_at': '2026-10-29T10:00:00Z',
  },
  'latest_generation': null,
  'suggestions': [],
  'action_items': [],
};

Map<String, dynamic> suggestionJson() => {
  'id': 7,
  'meeting_id': 1,
  'status': 'pending',
  'description': 'Prepare the release summary',
  'owner': 'Ari',
  'due_date': '2027-03-10',
  'source_quote': notes,
};

Map<String, dynamic> actionJson(String description) => {
  'id': 30,
  'suggestion_id': 7,
  'meeting': {'id': 1, 'title': 'Release'},
  'description': description,
  'owner': 'Ari',
  'due_date': '2027-03-10',
  'source_quote': notes,
  'edited': true,
  'original': {'description': 'Prepare the release summary', 'owner': 'Ari', 'due_date': '2027-03-10'},
  'completed': false,
  'completed_at': null,
  'accepted_by_name': 'Ari',
  'created_at': '2026-10-29T10:05:00Z',
};

void main() {
  testWidgets('a failed generation offers a retry; the retried suggestion can be edited and accepted', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    var generateCalls = 0;
    Map<String, dynamic>? acceptBody;
    final api = ApiClient(
      baseUrl: Uri.parse('http://localhost:3000'),
      token: 'token',
      httpClient: MockClient((request) async {
        final route = '${request.method} ${request.url.path}';
        switch (route) {
          case 'GET /api/v1/meetings/1':
            return jsonResponse(meetingJson(), 200);
          case 'POST /api/v1/meetings/1/suggestion_generations':
            generateCalls++;
            if (generateCalls == 1) {
              return jsonResponse({
                'error': {
                  'code': 'invalid_ai_response',
                  'message': 'The AI returned a response the app could not use. Nothing was saved. Try again.',
                  'retryable': true,
                },
              }, 502);
            }
            return jsonResponse({
              'generation': {'id': 2, 'status': 'succeeded', 'suggestion_count': 1, 'rejected_count': 0},
              'suggestions': [suggestionJson()],
            }, 201);
          case 'POST /api/v1/suggestions/7/accept':
            acceptBody = jsonDecode(request.body) as Map<String, dynamic>;
            final description = (acceptBody!['action_item'] as Map)['description'] as String;
            return jsonResponse({'created': true, 'action_item': actionJson(description)}, 201);
        }
        return jsonResponse({
          'error': {'code': 'not_found', 'message': 'Not found', 'retryable': false},
        }, 404);
      }),
    );

    await tester.pumpWidget(
      AppScope(
        api: api,
        child: const MaterialApp(home: MeetingDetailScreen(meetingId: 1, title: 'Release')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No suggestions yet'), findsOneWidget);

    await tester.tap(find.text('Generate suggestions'));
    await tester.pumpAndSettle();

    expect(find.textContaining('could not use'), findsOneWidget);
    expect(find.byType(SuggestionCard), findsNothing);

    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(generateCalls, 2);
    expect(find.byType(SuggestionCard), findsOneWidget);
    expect(find.textContaining('could not use'), findsNothing);
    expect(find.text('Prepare the release summary'), findsOneWidget);
    expect(find.textContaining(notes), findsWidgets);

    await tester.enterText(find.byKey(const Key('suggestion-7-description')), 'Prepare and send the release summary');
    await tester.ensureVisible(find.byKey(const Key('suggestion-7-accept')));
    await tester.tap(find.byKey(const Key('suggestion-7-accept')));
    await tester.pumpAndSettle();

    expect(acceptBody, {
      'action_item': {'description': 'Prepare and send the release summary', 'owner': 'Ari', 'due_date': '2027-03-10'},
    });
    expect(find.byType(SuggestionCard), findsNothing);
    expect(find.text('Prepare and send the release summary'), findsOneWidget);
  });

  testWidgets('a meeting whose last generation failed shows the failure and a retry', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    var generateCalls = 0;
    final failedMeeting = meetingJson()
      ..['latest_generation'] = {
        'id': 5,
        'status': 'failed',
        'suggestion_count': 0,
        'rejected_count': 0,
        'error_code': 'provider_timeout',
        'error_message': 'The AI provider did not respond in time.',
      };
    final api = ApiClient(
      baseUrl: Uri.parse('http://localhost:3000'),
      token: 'token',
      httpClient: MockClient((request) async {
        if (request.method == 'GET') return jsonResponse(failedMeeting, 200);
        generateCalls++;
        return jsonResponse({
          'generation': {'id': 6, 'status': 'succeeded', 'suggestion_count': 1, 'rejected_count': 0},
          'suggestions': [suggestionJson()],
        }, 201);
      }),
    );

    await tester.pumpWidget(
      AppScope(
        api: api,
        child: const MaterialApp(home: MeetingDetailScreen(meetingId: 1, title: 'Release')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('did not respond in time'), findsOneWidget);
    expect(find.text('All suggestions reviewed'), findsNothing);

    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(generateCalls, 1);
    expect(find.byType(SuggestionCard), findsOneWidget);
    expect(find.textContaining('did not respond in time'), findsNothing);
  });

  testWidgets('a failed reload after a stale accept is shown with a retry', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    const succeeded = {'id': 2, 'status': 'succeeded', 'suggestion_count': 1, 'rejected_count': 0};
    var getCalls = 0;
    final api = ApiClient(
      baseUrl: Uri.parse('http://localhost:3000'),
      token: 'token',
      httpClient: MockClient((request) async {
        if (request.method == 'GET') {
          getCalls++;
          if (getCalls == 1) {
            return jsonResponse(
              meetingJson()
                ..['latest_generation'] = succeeded
                ..['suggestions'] = [suggestionJson()],
              200,
            );
          }
          if (getCalls == 2) {
            return jsonResponse({
              'error': {'code': 'internal_error', 'message': 'Something went wrong on the server.', 'retryable': false},
            }, 500);
          }
          return jsonResponse(meetingJson()..['latest_generation'] = succeeded, 200);
        }
        return jsonResponse({
          'error': {
            'code': 'suggestion_not_pending',
            'message': 'This suggestion is superseded and can no longer be changed. Refresh the meeting.',
            'retryable': false,
          },
        }, 409);
      }),
    );

    await tester.pumpWidget(
      AppScope(
        api: api,
        child: const MaterialApp(home: MeetingDetailScreen(meetingId: 1, title: 'Release')),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('suggestion-7-accept')));
    await tester.pumpAndSettle();

    expect(getCalls, 2);
    expect(find.textContaining('Something went wrong on the server'), findsOneWidget);
    expect(find.byType(SuggestionCard), findsOneWidget, reason: 'stale data stays visible until a reload succeeds');

    await tester.tap(find.widgetWithText(TextButton, 'Try again'));
    await tester.pumpAndSettle();

    expect(getCalls, 3);
    expect(find.textContaining('Something went wrong on the server'), findsNothing);
    expect(find.byType(SuggestionCard), findsNothing);
  });
}
