class ApiResponse<T> {
  const ApiResponse({
    required this.success,
    this.data,
    this.error,
    String? message,
    this.meta,
  }) : _message = message;

  final bool success;
  final T? data;
  final dynamic error;
  final String? _message;
  final Map<String, dynamic>? meta;

  String? get message => _message ?? (error is String ? error as String : error?.toString());

  factory ApiResponse.fromJson(
    Map<String, dynamic> json,
    T Function(dynamic json)? fromJsonT,
  ) {
    return ApiResponse<T>(
      success: json['success'] as bool? ?? false,
      data: json['data'] != null && fromJsonT != null
          ? fromJsonT(json['data'])
          : json['data'] as T?,
      error: json['error'],
      message: json['message'] as String?,
      meta: json['meta'] as Map<String, dynamic>?,
    );
  }
}

class NetworkException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic details;

  const NetworkException(this.message, [this.statusCode, this.details]);

  @override
  String toString() => 'NetworkException($statusCode): $message';
}
