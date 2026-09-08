import 'package:dio/dio.dart';

import 'notification_models.dart';

class NotificationRepository {
  const NotificationRepository(this._dio);

  final Dio _dio;

  Future<NotificationPageModel> getNotifications({
    String? cursor,
    int pageSize = 20,
  }) async {
    if (pageSize < 1 || pageSize > 50) {
      throw RangeError.range(pageSize, 1, 50, 'pageSize');
    }

    final query = <String, Object?>{'pageSize': pageSize};
    if (cursor != null) query['cursor'] = cursor;
    final response = await _dio.get<Object?>(
      '/notifications',
      queryParameters: query,
    );
    return NotificationPageModel.fromJson(response.data);
  }

  Future<NotificationUnreadCountModel> getUnreadCount() async {
    final response = await _dio.get<Object?>('/notifications/unread-count');
    return NotificationUnreadCountModel.fromJson(response.data);
  }

  Future<UserNotificationModel> markRead(String notificationId) async {
    final response = await _dio.post<Object?>(
      '${_notificationPath(notificationId)}/read',
    );
    return UserNotificationModel.fromJson(response.data);
  }

  Future<NotificationUnreadCountModel> markAllRead() async {
    final response = await _dio.post<Object?>('/notifications/read-all');
    return NotificationUnreadCountModel.fromJson(response.data);
  }

  static String _notificationPath(String notificationId) {
    if (notificationId.isEmpty) {
      throw ArgumentError.value(
        notificationId,
        'notificationId',
        'Notification ID cannot be empty.',
      );
    }
    return '/notifications/${Uri.encodeComponent(notificationId)}';
  }
}
