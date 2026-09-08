import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_failure.dart';
import '../../../core/storage/secure_session_store.dart';
import '../data/auth_models.dart';
import '../data/auth_repository.dart';

enum AuthPhase { restoring, guest, authenticated }

class AuthState {
  const AuthState({required this.phase, this.session, this.restoreWarning});

  const AuthState.restoring() : this(phase: AuthPhase.restoring);
  const AuthState.guest({Object? warning})
    : this(phase: AuthPhase.guest, restoreWarning: warning);
  const AuthState.authenticated(AuthResponse session, {Object? warning})
    : this(
        phase: AuthPhase.authenticated,
        session: session,
        restoreWarning: warning,
      );

  final AuthPhase phase;
  final AuthResponse? session;
  final Object? restoreWarning;

  bool get isAuthenticated =>
      phase == AuthPhase.authenticated && session != null;
}

class AuthController extends StateNotifier<AuthState> {
  AuthController(this._repository, this._store)
    : super(const AuthState.restoring());

  static const _refreshLead = Duration(seconds: 60);
  static const _sessionChangedFailure = ApiFailure(
    kind: ApiFailureKind.unauthorized,
    statusCode: 401,
    code: 'SESSION_CHANGED',
    message: 'The authentication session changed while the request was active.',
  );
  final AuthRepository _repository;
  final SecureSessionStore _store;
  Future<void> _persistenceTail = Future<void>.value();
  Future<AuthResponse>? _refreshInFlight;
  int? _refreshEpoch;
  int _sessionEpoch = 0;

  int? get currentUserId => state.session?.user.id;

  Future<void> restore() async {
    final restoreEpoch = _sessionEpoch;
    try {
      final stored = await _store.read();
      if (restoreEpoch != _sessionEpoch) return;
      if (stored == null || stored.refreshTokenExpiresWithin(Duration.zero)) {
        await _clearLocalSessionIfCurrent(
          restoreEpoch,
          suppressStorageError: true,
        );
        return;
      }

      state = AuthState.authenticated(stored);
      if (stored.accessTokenExpiresWithin(_refreshLead)) {
        try {
          await refresh(force: true);
        } on Object catch (error) {
          final failure = ApiFailure.from(error);
          if (failure.isDefinitiveSessionFailure) {
            await _clearLocalSessionIfCurrent(
              restoreEpoch,
              warning: error,
              suppressStorageError: true,
            );
          } else if (restoreEpoch == _sessionEpoch) {
            state = AuthState.authenticated(stored, warning: error);
          }
        }
      }
    } on Object catch (error) {
      await _clearLocalSessionIfCurrent(
        restoreEpoch,
        warning: error,
        suppressStorageError: true,
      );
    }
  }

  Future<void> acceptSession(AuthResponse session) async {
    final accepted = await _acceptSessionIfCurrent(session, _sessionEpoch);
    if (!accepted) throw _sessionChangedFailure;
  }

  Future<AuthResponse> login(LoginRequest request) async {
    final session = await _repository.login(request);
    await acceptSession(session);
    return session;
  }

  Future<AuthResponse> verifyEmail(VerifyEmailRequest request) async {
    final session = await _repository.verifyEmail(request);
    await acceptSession(session);
    return session;
  }

  Future<AuthResponse> resetPassword(ResetPasswordRequest request) async {
    final session = await _repository.resetPassword(request);
    await acceptSession(session);
    return session;
  }

  Future<String?> validAccessToken({bool forceRefresh = false}) async {
    final session = state.session;
    if (session == null || session.refreshTokenExpiresWithin(Duration.zero)) {
      await _clearLocalSession();
      return null;
    }
    if (forceRefresh || session.accessTokenExpiresWithin(_refreshLead)) {
      return (await refresh(force: true)).accessToken;
    }
    return session.accessToken;
  }

  Future<String?> recoverAccessTokenAfterUnauthorized({
    required String? rejectedAccessToken,
    required int? expectedUserId,
  }) async {
    final session = state.session;
    if (session == null ||
        expectedUserId == null ||
        session.user.id != expectedUserId) {
      return null;
    }

    if (rejectedAccessToken != null &&
        session.accessToken != rejectedAccessToken) {
      return validAccessToken();
    }
    return validAccessToken(forceRefresh: true);
  }

  Future<AuthResponse> refresh({bool force = false}) {
    final current = state.session;
    if (current == null || current.refreshTokenExpiresWithin(Duration.zero)) {
      return Future<AuthResponse>.error(
        const ApiFailure(
          kind: ApiFailureKind.unauthorized,
          statusCode: 401,
          code: 'INVALID_REFRESH_TOKEN',
          message: 'The refresh token is unavailable or expired.',
        ),
      );
    }
    if (!force && !current.accessTokenExpiresWithin(_refreshLead)) {
      return Future<AuthResponse>.value(current);
    }

    final operationEpoch = _sessionEpoch;
    final existing = _refreshInFlight;
    if (existing != null && _refreshEpoch == operationEpoch) return existing;
    final operation = _performRefresh(current, operationEpoch);
    _refreshInFlight = operation;
    _refreshEpoch = operationEpoch;
    return operation.whenComplete(() {
      if (identical(_refreshInFlight, operation)) {
        _refreshInFlight = null;
        _refreshEpoch = null;
      }
    });
  }

  Future<AuthResponse> _performRefresh(
    AuthResponse current,
    int operationEpoch,
  ) async {
    try {
      final refreshed = await _repository.refresh(
        RefreshTokenRequest(refreshToken: current.refreshToken),
      );
      final accepted = await _acceptSessionIfCurrent(refreshed, operationEpoch);
      if (!accepted) throw _sessionChangedFailure;
      return refreshed;
    } on Object catch (error) {
      final failure = ApiFailure.from(error);
      if (failure.isDefinitiveSessionFailure) {
        await _clearLocalSessionIfCurrent(operationEpoch);
      }
      rethrow;
    }
  }

  Future<void> logout() async {
    final refreshToken = state.session?.refreshToken;
    final localClear = _clearLocalSession();
    try {
      if (refreshToken != null) {
        await _repository.logout(LogoutRequest(refreshToken: refreshToken));
      }
    } finally {
      await localClear;
    }
  }

  Future<void> invalidate() => _clearLocalSession();

  Future<bool> _acceptSessionIfCurrent(
    AuthResponse session,
    int expectedEpoch,
  ) async {
    if (expectedEpoch != _sessionEpoch) return false;

    final commitEpoch = ++_sessionEpoch;
    await _enqueuePersistence(() async {
      if (commitEpoch != _sessionEpoch) return;
      await _store.write(session);
      if (commitEpoch == _sessionEpoch) {
        state = AuthState.authenticated(session);
      }
    });
    return commitEpoch == _sessionEpoch;
  }

  Future<void> _clearLocalSession() async {
    await _clearLocalSessionIfCurrent(_sessionEpoch);
  }

  Future<bool> _clearLocalSessionIfCurrent(
    int expectedEpoch, {
    Object? warning,
    bool suppressStorageError = false,
  }) async {
    if (expectedEpoch != _sessionEpoch) return false;

    final clearEpoch = ++_sessionEpoch;
    state = AuthState.guest(warning: warning);
    try {
      await _enqueuePersistence(() async {
        if (clearEpoch == _sessionEpoch) await _store.clear();
      });
    } on Object catch (error) {
      if (clearEpoch == _sessionEpoch) {
        state = AuthState.guest(warning: error);
      }
      if (!suppressStorageError) rethrow;
    }
    return clearEpoch == _sessionEpoch;
  }

  Future<void> _enqueuePersistence(Future<void> Function() operation) {
    final next = _persistenceTail.then((_) => operation());
    _persistenceTail = next.then<void>(
      (_) {},
      onError: (Object error, StackTrace stackTrace) {},
    );
    return next;
  }
}
