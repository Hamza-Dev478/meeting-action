import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:meeting_action/api/api_client.dart';
import 'package:meeting_action/api/api_exception.dart';

http.Response jsonResponse(Object body, int status) =>
    http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json'});

void main() {
  final baseUrl = Uri.parse('http://localhost:3000');

  test('turns the API error envelope into an ApiException', () async {
    final client = ApiClient(
      baseUrl: baseUrl,
      token: 't',
      httpClient: MockClient(
        (_) async => jsonResponse({
          'error': {
            'code': 'invalid_ai_response',
            'message': 'The AI returned a response the app could not use.',
            'retryable': true,
          },
        }, 502),
      ),
    );

    final error = await client
        .generateSuggestions(1)
        .then<ApiException?>((_) => null)
        .catchError((Object e) => e as ApiException);

    expect(error, isNotNull);
    expect(error!.code, 'invalid_ai_response');
    expect(error.retryable, isTrue);
    expect(error.statusCode, 502);
    expect(error.message, contains('could not use'));
  });

  test('a 401 reports unauthorized and notifies the app', () async {
    var notified = false;
    final client = ApiClient(
      baseUrl: baseUrl,
      token: 'expired',
      onUnauthorized: () => notified = true,
      httpClient: MockClient(
        (_) async => jsonResponse({
          'error': {'code': 'unauthorized', 'message': 'Sign in again.', 'retryable': false},
        }, 401),
      ),
    );

    await expectLater(client.meetings(), throwsA(isA<ApiException>().having((e) => e.code, 'code', 'unauthorized')));
    expect(notified, isTrue);
  });

  test('a client-side timeout becomes a retryable timeout error', () async {
    final client = ApiClient(
      baseUrl: baseUrl,
      token: 't',
      requestTimeout: const Duration(milliseconds: 20),
      httpClient: MockClient((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 200));
        return jsonResponse({'meetings': []}, 200);
      }),
    );

    await expectLater(
      client.meetings(),
      throwsA(
        isA<ApiException>().having((e) => e.code, 'code', 'timeout').having((e) => e.retryable, 'retryable', isTrue),
      ),
    );
  });

  test('an unreachable server becomes a retryable network error', () async {
    final client = ApiClient(
      baseUrl: baseUrl,
      token: 't',
      httpClient: MockClient((_) async => throw http.ClientException('Connection refused')),
    );

    await expectLater(client.meetings(), throwsA(isA<ApiException>().having((e) => e.code, 'code', 'network_error')));
  });

  test('accepting sends the bearer token and the edited fields', () async {
    late http.Request captured;
    final client = ApiClient(
      baseUrl: baseUrl,
      token: 'secret-token',
      httpClient: MockClient((request) async {
        captured = request;
        return jsonResponse({
          'created': true,
          'action_item': {
            'id': 9,
            'suggestion_id': 3,
            'meeting': {'id': 1, 'title': 'Launch'},
            'description': 'Send the final checklist',
            'owner': null,
            'due_date': '2027-02-11',
            'source_quote': 'Maya will send the launch checklist by 2027-02-12.',
            'edited': true,
            'original': {'description': 'Send the launch checklist', 'owner': 'Maya', 'due_date': '2027-02-12'},
            'completed': false,
            'completed_at': null,
            'accepted_by_name': 'Maya Chen',
            'created_at': '2026-10-29T10:00:00Z',
          },
        }, 201);
      }),
    );

    final result = await client.acceptSuggestion(
      3,
      description: 'Send the final checklist',
      owner: '',
      dueDate: '2027-02-11',
    );

    expect(captured.method, 'POST');
    expect(captured.url.path, '/api/v1/suggestions/3/accept');
    expect(captured.headers['Authorization'], 'Bearer secret-token');
    expect(jsonDecode(captured.body), {
      'action_item': {'description': 'Send the final checklist', 'owner': '', 'due_date': '2027-02-11'},
    });
    expect(result.created, isTrue);
    expect(result.actionItem.edited, isTrue);
    expect(result.actionItem.dueDate, '2027-02-11');
    expect(result.actionItem.meetingTitle, 'Launch');
  });

  test('a payload the app cannot read becomes a bad_response error instead of a crash', () async {
    final client = ApiClient(
      baseUrl: baseUrl,
      token: 't',
      httpClient: MockClient(
        (_) async => jsonResponse({
          'meeting': {'id': 'not-a-number', 'title': 42},
        }, 200),
      ),
    );

    await expectLater(client.meeting(1), throwsA(isA<ApiException>().having((e) => e.code, 'code', 'bad_response')));
  });
}
