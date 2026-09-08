Map<String, dynamic> requireJsonObject(
  Object? value, {
  String context = 'JSON value',
}) {
  if (value is! Map) {
    throw FormatException('$context must be a JSON object.');
  }

  final result = <String, dynamic>{};
  for (final entry in value.entries) {
    if (entry.key is! String) {
      throw FormatException('$context contains a non-string key.');
    }
    result[entry.key as String] = entry.value;
  }
  return result;
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.isEmpty) {
    throw FormatException('Expected a non-empty string at "$key".');
  }
  return value;
}

int _requiredInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is int) {
    return value;
  }
  if (value is num && value.isFinite && value == value.truncateToDouble()) {
    return value.toInt();
  }
  throw FormatException('Expected an integer at "$key".');
}

bool _requiredBool(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is bool) {
    return value;
  }
  throw FormatException('Expected a boolean at "$key".');
}

DateTime _requiredUtcDateTime(Map<String, dynamic> json, String key) {
  final raw = _requiredString(json, key).trim();
  final timeSeparatorIndex = raw.lastIndexOf('T') > raw.lastIndexOf(' ')
      ? raw.lastIndexOf('T')
      : raw.lastIndexOf(' ');
  final offsetIndex = raw.lastIndexOf('+') > raw.lastIndexOf('-')
      ? raw.lastIndexOf('+')
      : raw.lastIndexOf('-');
  final hasExplicitZone =
      raw.endsWith('Z') ||
      raw.endsWith('z') ||
      (timeSeparatorIndex >= 0 && offsetIndex > timeSeparatorIndex);
  final parsed = DateTime.tryParse(hasExplicitZone ? raw : '${raw}Z');

  if (parsed == null) {
    throw FormatException('Expected an ISO-8601 timestamp at "$key".');
  }
  return parsed.toUtc();
}

String _utcJson(DateTime value) => value.toUtc().toIso8601String();

class CaptchaChallengeResponse {
  const CaptchaChallengeResponse({
    required this.captchaId,
    required this.a,
    required this.b,
  });

  factory CaptchaChallengeResponse.fromJson(Map<String, dynamic> json) {
    return CaptchaChallengeResponse(
      captchaId: _requiredString(json, 'captchaId'),
      a: _requiredInt(json, 'a'),
      b: _requiredInt(json, 'b'),
    );
  }

  final String captchaId;
  final int a;
  final int b;

  int get answer => a + b;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'captchaId': captchaId,
    'a': a,
    'b': b,
  };
}

class AuthenticatedUser {
  const AuthenticatedUser({
    required this.id,
    required this.fullName,
    required this.email,
    required this.role,
  });

  factory AuthenticatedUser.fromJson(Map<String, dynamic> json) {
    return AuthenticatedUser(
      id: _requiredInt(json, 'id'),
      fullName: _requiredString(json, 'fullName'),
      email: _requiredString(json, 'email'),
      role: _requiredString(json, 'role'),
    );
  }

  final int id;
  final String fullName;
  final String email;
  final String role;

  bool get isAdmin => role.toLowerCase() == 'admin';

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'fullName': fullName,
    'email': email,
    'role': role,
  };
}

class AuthResponse {
  const AuthResponse({
    required this.accessToken,
    required this.accessTokenExpiresAt,
    required this.refreshToken,
    required this.refreshTokenExpiresAt,
    required this.user,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    return AuthResponse(
      accessToken: _requiredString(json, 'accessToken'),
      accessTokenExpiresAt: _requiredUtcDateTime(json, 'accessTokenExpiresAt'),
      refreshToken: _requiredString(json, 'refreshToken'),
      refreshTokenExpiresAt: _requiredUtcDateTime(
        json,
        'refreshTokenExpiresAt',
      ),
      user: AuthenticatedUser.fromJson(
        requireJsonObject(json['user'], context: 'user'),
      ),
    );
  }

  final String accessToken;
  final DateTime accessTokenExpiresAt;
  final String refreshToken;
  final DateTime refreshTokenExpiresAt;
  final AuthenticatedUser user;

  bool accessTokenExpiresWithin(Duration duration, {DateTime? now}) {
    final currentTime = (now ?? DateTime.now()).toUtc();
    return !accessTokenExpiresAt.isAfter(currentTime.add(duration));
  }

  bool refreshTokenExpiresWithin(Duration duration, {DateTime? now}) {
    final currentTime = (now ?? DateTime.now()).toUtc();
    return !refreshTokenExpiresAt.isAfter(currentTime.add(duration));
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'accessToken': accessToken,
    'accessTokenExpiresAt': _utcJson(accessTokenExpiresAt),
    'refreshToken': refreshToken,
    'refreshTokenExpiresAt': _utcJson(refreshTokenExpiresAt),
    'user': user.toJson(),
  };
}

class LoginRequest {
  const LoginRequest({
    required this.identifier,
    required this.password,
    required this.captchaId,
    required this.captchaAnswer,
  });

  final String identifier;
  final String password;
  final String captchaId;
  final int captchaAnswer;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'identifier': identifier,
    'password': password,
    'captchaId': captchaId,
    'captchaAnswer': captchaAnswer,
  };
}

class RegisterRequest {
  const RegisterRequest({
    required this.fullName,
    required this.email,
    required this.password,
    required this.captchaId,
    required this.captchaAnswer,
  });

  final String fullName;
  final String email;
  final String password;
  final String captchaId;
  final int captchaAnswer;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'fullName': fullName,
    'email': email,
    'password': password,
    'captchaId': captchaId,
    'captchaAnswer': captchaAnswer,
  };
}

class RegisterResponse {
  const RegisterResponse({
    required this.email,
    required this.requiresEmailVerification,
    required this.message,
  });

  factory RegisterResponse.fromJson(Map<String, dynamic> json) {
    return RegisterResponse(
      email: _requiredString(json, 'email'),
      requiresEmailVerification: _requiredBool(
        json,
        'requiresEmailVerification',
      ),
      message: _requiredString(json, 'message'),
    );
  }

  final String email;
  final bool requiresEmailVerification;
  final String message;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'email': email,
    'requiresEmailVerification': requiresEmailVerification,
    'message': message,
  };
}

class VerifyEmailRequest {
  const VerifyEmailRequest({required this.email, required this.code});

  final String email;
  final String code;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'email': email,
    'code': code,
  };
}

class ResendVerificationCodeRequest {
  const ResendVerificationCodeRequest({required this.email});

  final String email;

  Map<String, dynamic> toJson() => <String, dynamic>{'email': email};
}

class RefreshTokenRequest {
  const RefreshTokenRequest({required this.refreshToken});

  final String refreshToken;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'refreshToken': refreshToken,
  };
}

class LogoutRequest {
  const LogoutRequest({required this.refreshToken});

  final String refreshToken;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'refreshToken': refreshToken,
  };
}

class ForgotPasswordRequest {
  const ForgotPasswordRequest({required this.email});

  final String email;

  Map<String, dynamic> toJson() => <String, dynamic>{'email': email};
}

class VerifyPasswordResetCodeRequest {
  const VerifyPasswordResetCodeRequest({
    required this.email,
    required this.code,
  });

  final String email;
  final String code;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'email': email,
    'code': code,
  };
}

class VerifyPasswordResetCodeResponse {
  const VerifyPasswordResetCodeResponse({
    required this.resetToken,
    required this.expiresAtUtc,
  });

  factory VerifyPasswordResetCodeResponse.fromJson(Map<String, dynamic> json) {
    return VerifyPasswordResetCodeResponse(
      resetToken: _requiredString(json, 'resetToken'),
      expiresAtUtc: _requiredUtcDateTime(json, 'expiresAtUtc'),
    );
  }

  final String resetToken;
  final DateTime expiresAtUtc;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'resetToken': resetToken,
    'expiresAtUtc': _utcJson(expiresAtUtc),
  };
}

class ResetPasswordRequest {
  const ResetPasswordRequest({
    required this.token,
    required this.newPassword,
    required this.confirmPassword,
  });

  final String token;
  final String newPassword;
  final String confirmPassword;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'token': token,
    'newPassword': newPassword,
    'confirmPassword': confirmPassword,
  };
}

class MessageResponse {
  const MessageResponse({required this.message});

  factory MessageResponse.fromJson(Map<String, dynamic> json) {
    return MessageResponse(message: _requiredString(json, 'message'));
  }

  final String message;

  Map<String, dynamic> toJson() => <String, dynamic>{'message': message};
}
