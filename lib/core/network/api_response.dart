
class ApiResponse<T> {
  final bool success;
  final String message;
  final T? data;
  final List<String>? errors;
  final String? code;

  ApiResponse({
    required this.success,
    required this.message,
    this.data,
    this.errors,
    this.code,
  });

  factory ApiResponse.fromJson(
    Map<String, dynamic> json,
    T Function(dynamic json) fromJsonT,
  ) {
    return ApiResponse(
      success: json['success'] ?? false,
      message: json['message'] ?? '',
      data: json['data'] != null ? fromJsonT(json['data']) : null,
      errors: json['error'] != null ? List<String>.from(json['error']) : null,
      code: json['code'],
    );
  }
}

