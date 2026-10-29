class Generation {
  const Generation({
    required this.id,
    required this.status,
    required this.suggestionCount,
    required this.rejectedCount,
    this.errorCode,
    this.errorMessage,
  });

  final int id;

  /// `running`, `succeeded` or `failed`.
  final String status;
  final int suggestionCount;
  final int rejectedCount;
  final String? errorCode;
  final String? errorMessage;

  bool get isRunning => status == 'running';
  bool get isFailed => status == 'failed';
  bool get isSucceeded => status == 'succeeded';

  factory Generation.fromJson(Map<String, dynamic> json) => Generation(
    id: json['id'] as int,
    status: json['status'] as String,
    suggestionCount: json['suggestion_count'] as int? ?? 0,
    rejectedCount: json['rejected_count'] as int? ?? 0,
    errorCode: json['error_code'] as String?,
    errorMessage: json['error_message'] as String?,
  );
}
