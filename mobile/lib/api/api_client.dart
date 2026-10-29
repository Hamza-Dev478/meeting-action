import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/action_item.dart';
import '../models/app_user.dart';
import '../models/generation.dart';
import '../models/meeting.dart';
import '../models/suggestion.dart';
import 'api_exception.dart';

enum ActionFilter { open, completed, all }

/// Thin client for the Rails `/api/v1` endpoints. Every failure surfaces as
/// an [ApiException] with a message the UI can show as-is.
class ApiClient {
  ApiClient({
    required this.baseUrl,
    http.Client? httpClient,
    this.token,
    this.onUnauthorized,
    this.requestTimeout = const Duration(seconds: 15),
    this.generationTimeout = const Duration(seconds: 75),
  }) : _http = httpClient ?? http.Client();

  final Uri baseUrl;
  final http.Client _http;
  final Duration requestTimeout;

  /// Longer than the server's worst case (provider timeout plus one SDK retry),
  /// so a normal slow generation is not cut off by the app.
  final Duration generationTimeout;

  String? token;
  void Function()? onUnauthorized;

  Future<List<AppUser>> devUsers() async {
    final json = await _send('GET', '/dev/users');
    return _decode(() => _list(json['users'], AppUser.fromJson));
  }

  Future<Session> signIn(String email) async {
    final json = await _send('POST', '/dev/session', body: {'email': email});
    return _decode(
      () => Session(token: json['token'] as String, user: AppUser.fromJson(json['user'] as Map<String, dynamic>)),
    );
  }

  Future<AppUser> me() async {
    final json = await _send('GET', '/me');
    return _decode(() => AppUser.fromJson(json['user'] as Map<String, dynamic>));
  }

  Future<List<MeetingSummary>> meetings() async {
    final json = await _send('GET', '/meetings');
    return _decode(() => _list(json['meetings'], MeetingSummary.fromJson));
  }

  Future<MeetingDetail> createMeeting({required String title, required String notes}) async {
    final json = await _send(
      'POST',
      '/meetings',
      body: {
        'meeting': {'title': title, 'notes': notes},
      },
    );
    return _decode(() => MeetingDetail.fromJson(json));
  }

  Future<MeetingDetail> meeting(int id) async {
    final json = await _send('GET', '/meetings/$id');
    return _decode(() => MeetingDetail.fromJson(json));
  }

  Future<GenerationResult> generateSuggestions(int meetingId) async {
    final json = await _send('POST', '/meetings/$meetingId/suggestion_generations', timeout: generationTimeout);
    return _decode(
      () => GenerationResult(
        generation: Generation.fromJson(json['generation'] as Map<String, dynamic>),
        suggestions: _list(json['suggestions'], Suggestion.fromJson),
      ),
    );
  }

  /// [owner] and [dueDate] are sent as typed; an empty string clears the field.
  Future<AcceptResult> acceptSuggestion(
    int suggestionId, {
    required String description,
    String? owner,
    String? dueDate,
  }) async {
    final json = await _send(
      'POST',
      '/suggestions/$suggestionId/accept',
      body: {
        'action_item': {'description': description, 'owner': owner ?? '', 'due_date': dueDate ?? ''},
      },
    );
    return _decode(
      () => AcceptResult(
        actionItem: ActionItem.fromJson(json['action_item'] as Map<String, dynamic>),
        created: json['created'] as bool? ?? false,
      ),
    );
  }

  Future<Suggestion> dismissSuggestion(int suggestionId) async {
    final json = await _send('POST', '/suggestions/$suggestionId/dismiss');
    return _decode(() => Suggestion.fromJson(json['suggestion'] as Map<String, dynamic>));
  }

  Future<List<ActionItem>> actionItems(ActionFilter filter) async {
    final json = await _send('GET', '/action_items', query: {'status': filter.name});
    return _decode(() => _list(json['action_items'], ActionItem.fromJson));
  }

  Future<ActionItem> setCompleted(int actionItemId, bool completed) async {
    final json = await _send(
      'PATCH',
      '/action_items/$actionItemId',
      body: {
        'action_item': {'completed': completed},
      },
    );
    return _decode(() => ActionItem.fromJson(json['action_item'] as Map<String, dynamic>));
  }

  /// A response the app cannot read (for example after an incompatible API
  /// change) becomes an error the screens already know how to show, instead
  /// of an uncaught exception that leaves a spinner running forever.
  T _decode<T>(T Function() parse) {
    try {
      return parse();
    } on TypeError {
      throw _unreadable;
    } on FormatException {
      throw _unreadable;
    }
  }

  static const _unreadable = ApiException(
    code: 'bad_response',
    message: 'The server sent a response this version of the app cannot read. Try updating the app.',
  );

  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    Object? body,
    Map<String, String>? query,
    Duration? timeout,
  }) async {
    final uri = baseUrl.replace(
      path: '${baseUrl.path.replaceAll(RegExp(r'/$'), '')}/api/v1$path',
      queryParameters: query,
    );
    final request = http.Request(method, uri)
      ..headers['Accept'] = 'application/json'
      ..headers['X-Client'] = 'meeting-action-flutter/1';
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }

    final http.Response response;
    try {
      final streamed = await _http.send(request).timeout(timeout ?? requestTimeout);
      response = await http.Response.fromStream(streamed).timeout(timeout ?? requestTimeout);
    } on TimeoutException {
      throw const ApiException(
        code: 'timeout',
        message: 'The server took too long to answer. It may still finish, so refresh before trying again.',
        retryable: true,
      );
    } on http.ClientException {
      throw ApiException(
        code: 'network_error',
        message: 'Could not reach the server at $baseUrl. Check that the API is running.',
        retryable: true,
      );
    }

    Object? decoded;
    try {
      decoded = response.body.isEmpty ? <String, dynamic>{} : jsonDecode(response.body);
    } on FormatException {
      decoded = null;
    }

    if (response.statusCode >= 200 && response.statusCode < 300 && decoded is Map<String, dynamic>) {
      return decoded;
    }
    final error = ApiException.fromResponse(response.statusCode, decoded);
    if (error.isUnauthorized) onUnauthorized?.call();
    throw error;
  }

  static List<T> _list<T>(Object? raw, T Function(Map<String, dynamic>) parse) =>
      (raw as List? ?? []).map((item) => parse(item as Map<String, dynamic>)).toList();
}
