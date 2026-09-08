import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hardware_reserve/core/network/api_failure.dart';

void main() {
  test('empty framework 401 remains a definitive session failure', () {
    final options = RequestOptions(path: '/me');
    final failure = ApiFailure.from(
      DioException(
        requestOptions: options,
        type: DioExceptionType.badResponse,
        response: Response<void>(requestOptions: options, statusCode: 401),
      ),
    );

    expect(failure.kind, ApiFailureKind.unauthorized);
    expect(failure.isDefinitiveSessionFailure, isTrue);
  });

  test('validation fields are parsed case-insensitively', () {
    final options = RequestOptions(path: '/reservations');
    final failure = ApiFailure.from(
      DioException(
        requestOptions: options,
        type: DioExceptionType.badResponse,
        response: Response<Object?>(
          requestOptions: options,
          statusCode: 409,
          data: {
            'traceId': 'trace-1',
            'code': 'RESERVATION_TIME_CONFLICT',
            'message': 'Conflict',
            'errors': {
              'StartTime': ['Choose another time'],
            },
          },
        ),
      ),
    );

    expect(failure.code, 'RESERVATION_TIME_CONFLICT');
    expect(failure.fieldMessage('startTime'), 'Choose another time');
  });
}
