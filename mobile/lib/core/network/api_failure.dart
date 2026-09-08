import 'dart:io';

import 'package:dio/dio.dart';

enum ApiFailureKind {
  validation,
  unauthorized,
  forbidden,
  timeout,
  offline,
  server,
  unknown,
}

class ApiFailure implements Exception {
  const ApiFailure({
    required this.kind,
    required this.message,
    this.statusCode,
    this.code,
    this.traceId,
    this.fieldErrors = const <String, List<String>>{},
  });

  factory ApiFailure.from(Object error) {
    if (error is ApiFailure) return error;
    if (error is! DioException) {
      return ApiFailure(
        kind: ApiFailureKind.unknown,
        message: error.toString(),
      );
    }

    final response = error.response;
    final status = response?.statusCode;
    final data = response?.data;
    final json = data is Map
        ? data.map((key, value) => MapEntry(key.toString(), value))
        : const <String, dynamic>{};
    final fields = <String, List<String>>{};
    final rawErrors = json['errors'];
    if (rawErrors is Map) {
      for (final entry in rawErrors.entries) {
        final value = entry.value;
        fields[entry.key.toString()] = value is List
            ? value.map((item) => item.toString()).toList(growable: false)
            : <String>[value.toString()];
      }
    }

    final kind = switch (status) {
      400 || 409 || 413 || 422 || 429 => ApiFailureKind.validation,
      401 => ApiFailureKind.unauthorized,
      403 => ApiFailureKind.forbidden,
      final int value when value >= 500 => ApiFailureKind.server,
      _
          when error.type == DioExceptionType.connectionTimeout ||
              error.type == DioExceptionType.receiveTimeout ||
              error.type == DioExceptionType.sendTimeout =>
        ApiFailureKind.timeout,
      _
          when error.type == DioExceptionType.connectionError ||
              error.error is SocketException =>
        ApiFailureKind.offline,
      _ => ApiFailureKind.unknown,
    };

    return ApiFailure(
      kind: kind,
      statusCode: status,
      code: json['code']?.toString(),
      traceId: json['traceId']?.toString(),
      message:
          json['message']?.toString() ?? error.message ?? 'Request failed.',
      fieldErrors: fields,
    );
  }

  final ApiFailureKind kind;
  final int? statusCode;
  final String? code;
  final String message;
  final String? traceId;
  final Map<String, List<String>> fieldErrors;

  bool get isDefinitiveSessionFailure =>
      statusCode == 401 && (code == null || code == 'INVALID_REFRESH_TOKEN');

  String? fieldMessage(String name) {
    final normalized = name.toLowerCase();
    for (final entry in fieldErrors.entries) {
      if (entry.key.toLowerCase() == normalized && entry.value.isNotEmpty) {
        return entry.value.first;
      }
    }
    return null;
  }

  @override
  String toString() => 'ApiFailure($statusCode, $code, $message)';
}
