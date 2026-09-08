import 'package:flutter_test/flutter_test.dart';
import 'package:hardware_reserve/features/notifications/data/notification_models.dart';

void main() {
  test(
    'service assignment notification keeps reservation deep-link metadata',
    () {
      final notification = UserNotificationModel.fromJson(<String, Object?>{
        'id': 'e3dd3771-45b1-49a2-b735-59331c0ec4dd',
        'type': 'ServiceDetailsAssigned',
        'source': 'System',
        'resourceLabel': 'Reservation #42',
        'title': null,
        'message': 'Your service is ready.',
        'reservationId': 42,
        'supportConversationId': null,
        'eventTime': '2026-08-23T08:30:00Z',
        'createdAt': '2026-08-23T08:30:01Z',
        'readAt': null,
      });

      expect(notification.type, UserNotificationType.serviceDetailsAssigned);
      expect(notification.reservationId, 42);
      expect(notification.message, isNot(contains('password')));
    },
  );
}
