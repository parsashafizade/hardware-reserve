class SupportRealtimeNotification {
  const SupportRealtimeNotification({
    required this.notificationId,
    required this.conversationId,
    required this.messageId,
    required this.sequenceNumber,
    required this.eventType,
    required this.occurredAt,
  });

  final String notificationId;
  final String conversationId;
  final String? messageId;
  final int? sequenceNumber;
  final String eventType;
  final DateTime occurredAt;

  factory SupportRealtimeNotification.fromJson(Object? json) {
    final object = _asJsonObject(json, 'support realtime notification');
    return SupportRealtimeNotification(
      notificationId: _requiredString(
        object['notificationId'],
        'notificationId',
      ),
      conversationId: _requiredString(
        object['conversationId'],
        'conversationId',
      ),
      messageId: _nullableString(object['messageId'], 'messageId'),
      sequenceNumber: _nullableInt(object['sequenceNumber'], 'sequenceNumber'),
      eventType: _requiredString(object['eventType'], 'eventType'),
      occurredAt: _requiredDateTime(object['occurredAt'], 'occurredAt'),
    );
  }
}

class RealtimeUserNotification {
  const RealtimeUserNotification({
    required this.id,
    required this.type,
    required this.source,
    required this.resourceLabel,
    required this.title,
    required this.message,
    required this.reservationId,
    required this.supportConversationId,
    required this.eventTime,
    required this.createdAt,
    required this.readAt,
  });

  final String id;
  final String type;
  final String source;
  final String? resourceLabel;
  final String? title;
  final String? message;
  final int? reservationId;
  final String? supportConversationId;
  final DateTime? eventTime;
  final DateTime createdAt;
  final DateTime? readAt;

  factory RealtimeUserNotification.fromJson(Object? json) {
    final object = _asJsonObject(json, 'realtime user notification');
    return RealtimeUserNotification(
      id: _requiredString(object['id'], 'id'),
      type: _requiredString(object['type'], 'type'),
      source: _requiredString(object['source'], 'source'),
      resourceLabel: _nullableString(object['resourceLabel'], 'resourceLabel'),
      title: _nullableString(object['title'], 'title'),
      message: _nullableString(object['message'], 'message'),
      reservationId: _nullableInt(object['reservationId'], 'reservationId'),
      supportConversationId: _nullableString(
        object['supportConversationId'],
        'supportConversationId',
      ),
      eventTime: _nullableDateTime(object['eventTime'], 'eventTime'),
      createdAt: _requiredDateTime(object['createdAt'], 'createdAt'),
      readAt: _nullableDateTime(object['readAt'], 'readAt'),
    );
  }
}

class NotificationReadStateEvent {
  const NotificationReadStateEvent({
    required this.eventId,
    required this.notificationId,
    required this.unreadCount,
    required this.occurredAt,
  });

  final String eventId;
  final String? notificationId;
  final int unreadCount;
  final DateTime occurredAt;

  factory NotificationReadStateEvent.fromJson(Object? json) {
    final object = _asJsonObject(json, 'notification read state event');
    return NotificationReadStateEvent(
      eventId: _requiredString(object['eventId'], 'eventId'),
      notificationId: _nullableString(
        object['notificationId'],
        'notificationId',
      ),
      unreadCount: _requiredInt(object['unreadCount'], 'unreadCount'),
      occurredAt: _requiredDateTime(object['occurredAt'], 'occurredAt'),
    );
  }
}

Map<String, dynamic> _asJsonObject(Object? value, String description) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
  throw FormatException('$description must be a JSON object.');
}

String _requiredString(Object? value, String field) {
  if (value is String) {
    return value;
  }
  throw FormatException('$field must be a string.');
}

String? _nullableString(Object? value, String field) {
  if (value == null || value is String) {
    return value as String?;
  }
  throw FormatException('$field must be a string or null.');
}

int _requiredInt(Object? value, String field) {
  if (value is int) {
    return value;
  }
  if (value is num && value.isFinite && value == value.roundToDouble()) {
    return value.toInt();
  }
  throw FormatException('$field must be an integer.');
}

int? _nullableInt(Object? value, String field) {
  return value == null ? null : _requiredInt(value, field);
}

DateTime _requiredDateTime(Object? value, String field) {
  final raw = _requiredString(value, field);
  try {
    return DateTime.parse(raw).toUtc();
  } on FormatException {
    throw FormatException('$field must be an ISO-8601 timestamp.');
  }
}

DateTime? _nullableDateTime(Object? value, String field) {
  return value == null ? null : _requiredDateTime(value, field);
}
