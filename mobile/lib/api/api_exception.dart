/// An error the UI can show directly. [code] mirrors the API's error code,
/// plus client-side codes `timeout`, `network_error` and `bad_response`.
class ApiException implements Exception {
  const ApiException({
    required this.code,
    required this.message,
    this.retryable = false,
    this.statusCode,
    this.details = const {},
  });

  final String code;
  final String message;
  final bool retryable;
  final int? statusCode;

  /// Field errors from `validation_failed`, keyed by field name.
  final Map<String, List<String>> details;

  bool get isUnauthorized => code == 'unauthorized';

  /// The request may still be running on the server (client gave up waiting).
  bool get isClientTimeout => code == 'timeout';

  factory ApiException.fromResponse(int statusCode, Object? body) {
    final error = body is Map<String, dynamic> ? body['error'] : null;
    if (error is! Map<String, dynamic>) {
      return ApiException(
        code: 'bad_response',
        message: 'The server returned an unexpected response ($statusCode).',
        retryable: statusCode >= 500,
        statusCode: statusCode,
      );
    }
    final rawDetails = error['details'];
    final details = <String, List<String>>{};
    if (rawDetails is Map<String, dynamic>) {
      rawDetails.forEach((field, messages) {
        if (messages is List) details[field] = messages.map((m) => m.toString()).toList();
      });
    }
    return ApiException(
      code: error['code'] as String? ?? 'unknown_error',
      message: error['message'] as String? ?? 'Something went wrong.',
      retryable: error['retryable'] as bool? ?? false,
      statusCode: statusCode,
      details: details,
    );
  }

  @override
  String toString() => 'ApiException($code, $statusCode): $message';
}
