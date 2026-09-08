import 'package:dio/dio.dart';

import '../../auth/data/auth_models.dart';
import 'email_change_models.dart';

class EmailChangeRepository {
  const EmailChangeRepository(this._dio);
  final Dio _dio;

  Future<EmailChangeStatusModel?> getStatus() async {
    final response = await _dio.get<Object?>('/me/email-change');
    if (response.statusCode == 204 ||
        response.data == null ||
        response.data == '') {
      return null;
    }
    return EmailChangeStatusModel.fromJson(requireJsonObject(response.data));
  }

  Future<EmailChangeStatusModel> start(String newEmail) async {
    final response = await _dio.post<Object?>(
      '/me/email-change',
      data: <String, Object>{'newEmail': newEmail.trim()},
    );
    return EmailChangeStatusModel.fromJson(requireJsonObject(response.data));
  }

  Future<EmailChangeVerificationModel> verifyCurrent(String code) =>
      _verify('/me/email-change/verify-current', code);
  Future<EmailChangeVerificationModel> verifyNew(String code) =>
      _verify('/me/email-change/verify-new', code);

  Future<EmailChangeVerificationModel> _verify(String path, String code) async {
    final response = await _dio.post<Object?>(
      path,
      data: <String, Object>{'code': code.trim()},
    );
    return EmailChangeVerificationModel.fromJson(
      requireJsonObject(response.data),
    );
  }

  Future<EmailChangeStatusModel> resendCurrent() =>
      _statusPost('/me/email-change/resend-current');
  Future<EmailChangeStatusModel> resendNew() =>
      _statusPost('/me/email-change/resend-new');

  Future<EmailChangeStatusModel> _statusPost(String path) async {
    final response = await _dio.post<Object?>(path);
    return EmailChangeStatusModel.fromJson(requireJsonObject(response.data));
  }

  Future<void> cancel() => _dio.delete<void>('/me/email-change');
}
