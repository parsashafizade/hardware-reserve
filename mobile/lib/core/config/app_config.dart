import 'dart:io';

import 'package:flutter/foundation.dart';

class AppConfig {
  AppConfig._();

  static const _configuredApiBase = String.fromEnvironment('API_BASE_URL');

  static Uri get apiBaseUri {
    final fallback = Platform.isAndroid
        ? 'http://10.0.2.2:5239'
        : 'http://127.0.0.1:5239';
    final value = _configuredApiBase.trim().isEmpty
        ? fallback
        : _configuredApiBase.trim();
    final uri = Uri.parse(value);

    if (!uri.isAbsolute || (uri.scheme != 'https' && uri.scheme != 'http')) {
      throw StateError('API_BASE_URL must be an absolute HTTP(S) URL.');
    }
    if (uri.hasQuery || uri.hasFragment || uri.userInfo.isNotEmpty) {
      throw StateError(
        'API_BASE_URL cannot contain credentials, a query, or a fragment.',
      );
    }
    if (kReleaseMode && uri.scheme != 'https') {
      throw StateError('Release builds require an HTTPS API_BASE_URL.');
    }

    var normalized = value;
    while (normalized.endsWith('/')) {
      normalized = normalized.substring(0, normalized.length - 1);
    }
    return Uri.parse(normalized);
  }

  static String get apiBaseUrl => apiBaseUri.toString();

  static Uri resolveApiPath(String path) => apiBaseUri.resolve(path);
}
