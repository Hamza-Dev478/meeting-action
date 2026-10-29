import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:meeting_action/api/api_client.dart';
import 'package:meeting_action/app_scope.dart';
import 'package:meeting_action/screens/actions_screen.dart';

http.Response jsonResponse(Object body, int status) =>
    http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json'});

Map<String, dynamic> actionJson(int id, String description, {String? dueDate, bool completed = false}) => {
  'id': id,
  'suggestion_id': id + 100,
  'meeting': {'id': 1, 'title': 'Release'},
  'description': description,
  'owner': 'Ari',
  'due_date': dueDate,
  'source_quote': 'Ari will $description.',
  'edited': false,
  'original': null,
  'completed': completed,
  'completed_at': completed ? '2026-10-29T10:05:00Z' : null,
  'accepted_by_name': 'Ari',
  'created_at': '2026-10-29T10:05:00Z',
};

void main() {
  testWidgets('loads every action once, shows progress and due groups, and filters without refetching', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final requests = <String>[];
    final items = [
      actionJson(1, 'send the overdue report', dueDate: '2020-01-15'),
      actionJson(2, 'book the review room'),
      actionJson(3, 'share the agenda', dueDate: '2020-01-10', completed: true),
    ];
    final api = ApiClient(
      baseUrl: Uri.parse('http://localhost:3000'),
      token: 'token',
      httpClient: MockClient((request) async {
        requests.add('${request.method} ${request.url.path}?${request.url.query}');
        if (request.method == 'GET' && request.url.path == '/api/v1/action_items') {
          return jsonResponse({'action_items': items}, 200);
        }
        if (request.method == 'PATCH' && request.url.path == '/api/v1/action_items/1') {
          return jsonResponse({
            'action_item': actionJson(1, 'send the overdue report', dueDate: '2020-01-15', completed: true),
          }, 200);
        }
        return jsonResponse({
          'error': {'code': 'not_found', 'message': 'Not found', 'retryable': false},
        }, 404);
      }),
    );

    await tester.pumpWidget(
      AppScope(
        api: api,
        child: const MaterialApp(home: ActionsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(requests, ['GET /api/v1/action_items?status=all']);
    expect(find.text('1 of 3 done'), findsOneWidget);
    expect(find.text('Overdue'), findsOneWidget);
    expect(find.text('No due date'), findsOneWidget);
    expect(find.text('send the overdue report'), findsOneWidget);
    expect(find.text('share the agenda'), findsNothing);

    await tester.tap(find.text('Completed'));
    await tester.pumpAndSettle();
    expect(find.text('share the agenda'), findsOneWidget);
    expect(find.text('send the overdue report'), findsNothing);
    expect(requests, hasLength(1), reason: 'switching filters uses the loaded list');

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('action-1-checkbox')));
    // Not pumpAndSettle: the progress ring animates for longer than the row lingers.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(requests.last, 'PATCH /api/v1/action_items/1?');
    expect(find.text('Marked complete'), findsOneWidget);
    expect(find.text('2 of 3 done'), findsOneWidget);
    expect(find.text('send the overdue report'), findsOneWidget, reason: 'the tick lands before the row leaves');

    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('send the overdue report'), findsNothing, reason: 'a completed item leaves the Open list');

    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(find.text('Marked complete'), findsNothing, reason: 'the Undo snack bar times out on its own');
  });
}
