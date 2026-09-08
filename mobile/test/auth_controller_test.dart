import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hardware_reserve/core/network/api_failure.dart';
import 'package:hardware_reserve/core/storage/secure_session_store.dart';
import 'package:hardware_reserve/features/auth/application/auth_controller.dart';
import 'package:hardware_reserve/features/auth/data/auth_models.dart';
import 'package:hardware_reserve/features/auth/data/auth_repository.dart';

void main() {
  test('concurrent access-token requests share one rotating refresh', () async {
    final repository = _RefreshRepository();
    final store = _MemorySessionStore();
    final controller = AuthController(repository, store);
    final current = _session(access: 'old-access', refresh: 'old-refresh');
    final rotated = _session(access: 'new-access', refresh: 'new-refresh');
    await controller.acceptSession(current);

    final first = controller.validAccessToken(forceRefresh: true);
    final second = controller.validAccessToken(forceRefresh: true);

    expect(repository.refreshCalls, 1);
    repository.pending.complete(rotated);
    expect(await Future.wait([first, second]), ['new-access', 'new-access']);
    expect(store.session?.refreshToken, 'new-refresh');
    expect(controller.state.session?.accessToken, 'new-access');
  });

  test('definitive refresh rejection clears secure session', () async {
    final repository = _RefreshRepository(
      error: const ApiFailure(
        kind: ApiFailureKind.unauthorized,
        statusCode: 401,
        code: 'INVALID_REFRESH_TOKEN',
        message: 'Invalid refresh token.',
      ),
    );
    final store = _MemorySessionStore();
    final controller = AuthController(repository, store);
    await controller.acceptSession(_session());

    await expectLater(
      controller.validAccessToken(forceRefresh: true),
      throwsA(isA<ApiFailure>()),
    );

    expect(store.session, isNull);
    expect(controller.state.phase, AuthPhase.guest);
  });

  test('transport refresh failure retains the stored session', () async {
    final repository = _RefreshRepository(
      error: DioException.connectionError(
        requestOptions: RequestOptions(path: '/auth/refresh'),
        reason: 'offline',
      ),
    );
    final store = _MemorySessionStore();
    final controller = AuthController(repository, store);
    final current = _session();
    await controller.acceptSession(current);

    await expectLater(
      controller.validAccessToken(forceRefresh: true),
      throwsA(isA<DioException>()),
    );

    expect(store.session, same(current));
    expect(controller.state.phase, AuthPhase.authenticated);
  });

  test('logout cannot be undone by a late rotating refresh', () async {
    final repository = _RefreshRepository();
    final store = _MemorySessionStore();
    final controller = AuthController(repository, store);
    await controller.acceptSession(_session());

    final refresh = controller.validAccessToken(forceRefresh: true);
    await controller.logout();
    repository.pending.complete(
      _session(access: 'late-access', refresh: 'late-refresh'),
    );

    await expectLater(
      refresh,
      throwsA(
        isA<ApiFailure>().having(
          (failure) => failure.code,
          'code',
          'SESSION_CHANGED',
        ),
      ),
    );
    expect(controller.state.phase, AuthPhase.guest);
    expect(store.session, isNull);
  });

  test('late restoration cannot overwrite a newer accepted session', () async {
    final repository = _RefreshRepository();
    final store = _DelayedReadSessionStore();
    final controller = AuthController(repository, store);
    final restore = controller.restore();
    final newer = _session(access: 'new-access', refresh: 'new-refresh');

    await controller.acceptSession(newer);
    store.pendingRead.complete(
      _session(access: 'stored-access', refresh: 'stored-refresh'),
    );
    await restore;

    expect(controller.state.session, same(newer));
    expect(store.session, same(newer));
  });

  test('a stale 401 reuses an already-rotated access token', () async {
    final repository = _RefreshRepository();
    final store = _MemorySessionStore();
    final controller = AuthController(repository, store);
    await controller.acceptSession(
      _session(access: 'old-access', refresh: 'old-refresh'),
    );
    await controller.acceptSession(
      _session(access: 'new-access', refresh: 'new-refresh'),
    );

    final token = await controller.recoverAccessTokenAfterUnauthorized(
      rejectedAccessToken: 'old-access',
      expectedUserId: 9,
    );

    expect(token, 'new-access');
    expect(repository.refreshCalls, 0);
  });

  test(
    'secure deletion failure still removes authenticated UI state',
    () async {
      final repository = _RefreshRepository();
      final store = _MemorySessionStore(throwOnClear: true);
      final controller = AuthController(repository, store);
      await controller.acceptSession(_session());

      await expectLater(controller.logout(), throwsA(isA<StateError>()));

      expect(controller.state.phase, AuthPhase.guest);
      expect(controller.state.restoreWarning, isA<StateError>());
    },
  );
}

AuthResponse _session({String access = 'access', String refresh = 'refresh'}) {
  final now = DateTime.now().toUtc();
  return AuthResponse(
    accessToken: access,
    accessTokenExpiresAt: now.add(const Duration(minutes: 20)),
    refreshToken: refresh,
    refreshTokenExpiresAt: now.add(const Duration(days: 14)),
    user: const AuthenticatedUser(
      id: 9,
      fullName: 'Test User',
      email: 'test@example.com',
      role: 'User',
    ),
  );
}

class _RefreshRepository extends AuthRepository {
  _RefreshRepository({this.error}) : super(Dio());

  final Object? error;
  final Completer<AuthResponse> pending = Completer<AuthResponse>();
  int refreshCalls = 0;

  @override
  Future<AuthResponse> refresh(RefreshTokenRequest request) {
    refreshCalls++;
    if (error case final failure?) return Future<AuthResponse>.error(failure);
    return pending.future;
  }

  @override
  Future<MessageResponse> logout(LogoutRequest request) async {
    return const MessageResponse(message: 'Logged out.');
  }
}

class _MemorySessionStore extends SecureSessionStore {
  _MemorySessionStore({this.throwOnClear = false});

  final bool throwOnClear;
  AuthResponse? session;

  @override
  Future<AuthResponse?> read() async => session;

  @override
  Future<void> write(AuthResponse value) async => session = value;

  @override
  Future<void> clear() async {
    if (throwOnClear) throw StateError('Secure storage unavailable.');
    session = null;
  }
}

class _DelayedReadSessionStore extends _MemorySessionStore {
  final Completer<AuthResponse?> pendingRead = Completer<AuthResponse?>();

  @override
  Future<AuthResponse?> read() => pendingRead.future;
}
