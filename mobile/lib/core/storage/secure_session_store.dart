import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../features/auth/data/auth_models.dart';

class SecureSessionStore {
  SecureSessionStore({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(),
            iOptions: IOSOptions(
              accessibility: KeychainAccessibility.unlocked_this_device,
            ),
          );

  static const _sessionKey = 'hardware_reserve.auth_session.v1';

  final FlutterSecureStorage _storage;

  Future<AuthResponse?> read() async {
    final encoded = await _storage.read(key: _sessionKey);
    if (encoded == null || encoded.isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(encoded);
      return AuthResponse.fromJson(
        requireJsonObject(decoded, context: 'Stored authentication session'),
      );
    } on FormatException {
      await clear();
      return null;
    }
  }

  Future<void> write(AuthResponse session) {
    final encoded = jsonEncode(session.toJson());
    return _storage.write(key: _sessionKey, value: encoded);
  }

  Future<void> clear() => _storage.delete(key: _sessionKey);
}
