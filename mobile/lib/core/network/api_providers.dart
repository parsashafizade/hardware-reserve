import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/account/data/profile_repository.dart';
import '../../features/account/data/email_change_repository.dart';
import '../../features/auth/application/auth_controller.dart';
import '../../features/auth/data/auth_repository.dart';
import '../../features/catalog/data/server_repository.dart';
import '../../features/home/data/dashboard_repository.dart';
import '../../features/reservations/data/reservation_repository.dart';
import '../../features/support/data/support_repository.dart';
import '../storage/secure_session_store.dart';
import 'api_failure.dart';
import 'dio_factory.dart';

final publicDioProvider = Provider<Dio>((ref) => DioFactory.create());

final secureSessionStoreProvider = Provider<SecureSessionStore>(
  (ref) => SecureSessionStore(),
);

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.watch(publicDioProvider)),
);

final authControllerProvider = StateNotifierProvider<AuthController, AuthState>(
  (ref) {
    final controller = AuthController(
      ref.watch(authRepositoryProvider),
      ref.watch(secureSessionStoreProvider),
    );
    unawaited(controller.restore());
    return controller;
  },
);

final authenticatedDioProvider = Provider<Dio>((ref) {
  final dio = DioFactory.create();
  final auth = ref.watch(authControllerProvider.notifier);

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        try {
          final token = await auth.validAccessToken();
          if (token == null) {
            return handler.reject(
              DioException(
                requestOptions: options,
                response: Response<Object?>(
                  requestOptions: options,
                  statusCode: 401,
                ),
                type: DioExceptionType.badResponse,
              ),
            );
          }
          options.headers['Authorization'] = 'Bearer $token';
          options.extra['_authAccessToken'] = token;
          options.extra['_authUserId'] = auth.currentUserId;
          handler.next(options);
        } on Object catch (error, stackTrace) {
          handler.reject(
            error is DioException
                ? error
                : DioException(
                    requestOptions: options,
                    error: error,
                    stackTrace: stackTrace,
                    type: DioExceptionType.unknown,
                  ),
          );
        }
      },
      onError: (error, handler) async {
        final request = error.requestOptions;
        if (error.response?.statusCode != 401 ||
            request.extra['_authRetried'] == true) {
          return handler.next(error);
        }

        try {
          final token = await auth.recoverAccessTokenAfterUnauthorized(
            rejectedAccessToken: request.extra['_authAccessToken'] as String?,
            expectedUserId: request.extra['_authUserId'] as int?,
          );
          if (token == null) return handler.next(error);
          if (request.data is FormData) {
            // FormData streams may already be finalized. Refresh the session,
            // but leave upload replay to the explicit user retry.
            return handler.next(error);
          }
          request.extra['_authRetried'] = true;
          request.headers['Authorization'] = 'Bearer $token';
          final response = await dio.fetch<Object?>(request);
          handler.resolve(response);
        } on Object catch (refreshError) {
          final failure = ApiFailure.from(refreshError);
          if (failure.isDefinitiveSessionFailure) await auth.invalidate();
          handler.next(
            refreshError is DioException
                ? refreshError
                : DioException(
                    requestOptions: request,
                    error: refreshError,
                    type: DioExceptionType.unknown,
                  ),
          );
        }
      },
    ),
  );
  return dio;
});

final serverRepositoryProvider = Provider<ServerRepository>(
  (ref) => ServerRepository(ref.watch(publicDioProvider)),
);

final reservationRepositoryProvider = Provider<ReservationRepository>(
  (ref) => ReservationRepository(ref.watch(authenticatedDioProvider)),
);

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => ProfileRepository(ref.watch(authenticatedDioProvider)),
);

final emailChangeRepositoryProvider = Provider<EmailChangeRepository>(
  (ref) => EmailChangeRepository(ref.watch(authenticatedDioProvider)),
);

final dashboardRepositoryProvider = Provider<DashboardRepository>(
  (ref) => DashboardRepository(ref.watch(authenticatedDioProvider)),
);

final supportRepositoryProvider = Provider<SupportRepository>(
  (ref) => SupportRepository(ref.watch(authenticatedDioProvider)),
);
