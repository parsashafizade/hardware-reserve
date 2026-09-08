import 'dart:convert';

import 'package:dio/dio.dart';

import 'auth_models.dart';

class AuthRepository {
  AuthRepository(this._dio);

  final Dio _dio;

  Future<CaptchaChallengeResponse> getCaptcha() async {
    final response = await _dio.get<Object?>('/auth/captcha');
    return CaptchaChallengeResponse.fromJson(
      _responseObject(response, '/auth/captcha'),
    );
  }

  Future<RegisterResponse> register(RegisterRequest request) async {
    final response = await _dio.post<Object?>(
      '/auth/register',
      data: request.toJson(),
    );
    return RegisterResponse.fromJson(
      _responseObject(response, '/auth/register'),
    );
  }

  Future<AuthResponse> verifyEmail(VerifyEmailRequest request) async {
    final response = await _dio.post<Object?>(
      '/auth/verify-email',
      data: request.toJson(),
    );
    return AuthResponse.fromJson(
      _responseObject(response, '/auth/verify-email'),
    );
  }

  Future<MessageResponse> resendVerificationCode(
    ResendVerificationCodeRequest request,
  ) async {
    final response = await _dio.post<Object?>(
      '/auth/resend-verification-code',
      data: request.toJson(),
    );
    return MessageResponse.fromJson(
      _responseObject(response, '/auth/resend-verification-code'),
    );
  }

  Future<AuthResponse> login(LoginRequest request) async {
    final response = await _dio.post<Object?>(
      '/auth/login',
      data: request.toJson(),
    );
    return AuthResponse.fromJson(_responseObject(response, '/auth/login'));
  }

  Future<AuthResponse> refresh(RefreshTokenRequest request) async {
    final response = await _dio.post<Object?>(
      '/auth/refresh',
      data: request.toJson(),
    );
    return AuthResponse.fromJson(_responseObject(response, '/auth/refresh'));
  }

  Future<MessageResponse> logout(LogoutRequest request) async {
    final response = await _dio.post<Object?>(
      '/auth/logout',
      data: request.toJson(),
    );
    return MessageResponse.fromJson(_responseObject(response, '/auth/logout'));
  }

  Future<MessageResponse> forgotPassword(ForgotPasswordRequest request) async {
    final response = await _dio.post<Object?>(
      '/auth/forgot-password',
      data: request.toJson(),
    );
    return MessageResponse.fromJson(
      _responseObject(response, '/auth/forgot-password'),
    );
  }

  Future<VerifyPasswordResetCodeResponse> verifyPasswordResetCode(
    VerifyPasswordResetCodeRequest request,
  ) async {
    final response = await _dio.post<Object?>(
      '/auth/verify-password-reset-code',
      data: request.toJson(),
    );
    return VerifyPasswordResetCodeResponse.fromJson(
      _responseObject(response, '/auth/verify-password-reset-code'),
    );
  }

  Future<AuthResponse> resetPassword(ResetPasswordRequest request) async {
    final response = await _dio.post<Object?>(
      '/auth/reset-password',
      data: request.toJson(),
    );
    return AuthResponse.fromJson(
      _responseObject(response, '/auth/reset-password'),
    );
  }
}

Map<String, dynamic> _responseObject(
  Response<Object?> response,
  String endpoint,
) {
  Object? data = response.data;
  if (data is String) {
    try {
      data = jsonDecode(data);
    } on FormatException catch (error) {
      throw FormatException(
        'The response from $endpoint was not valid JSON: ${error.message}',
      );
    }
  }

  return requireJsonObject(data, context: 'Response from $endpoint');
}
