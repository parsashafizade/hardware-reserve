import 'package:dio/dio.dart';

import '../config/app_config.dart';

class DioFactory {
  DioFactory._();

  static Dio create() {
    return Dio(
      BaseOptions(
        baseUrl: AppConfig.apiBaseUrl,
        connectTimeout: const Duration(seconds: 15),
        sendTimeout: const Duration(seconds: 20),
        receiveTimeout: const Duration(seconds: 25),
        headers: const <String, Object>{'Accept': 'application/json'},
        validateStatus: (status) =>
            status != null && status >= 200 && status < 300,
      ),
    );
  }
}
