enum UserNotificationType {
  reservationCreated('ReservationCreated'),
  paymentConfirmed('PaymentConfirmed'),
  reservationStartsSoon('ReservationStartsSoon'),
  reservationStarted('ReservationStarted'),
  reservationEndsSoon('ReservationEndsSoon'),
  reservationCompleted('ReservationCompleted'),
  serviceDetailsAssigned('ServiceDetailsAssigned'),
  supportReply('SupportReply'),
  adminMessage('AdminMessage'),
  reservationCancelled('ReservationCancelled'),
  unknown('Unknown');

  const UserNotificationType(this.wireValue);

  final String wireValue;

  static UserNotificationType fromWireValue(String value) {
    for (final type in values) {
      if (type.wireValue == value) {
        return type;
      }
    }
    return UserNotificationType.unknown;
  }
}

enum UserNotificationSource {
  system('System'),
  admin('Admin'),
  unknown('Unknown');

  const UserNotificationSource(this.wireValue);

  final String wireValue;

  static UserNotificationSource fromWireValue(String value) {
    for (final source in values) {
      if (source.wireValue == value) {
        return source;
      }
    }
    return UserNotificationSource.unknown;
  }
}

class UserNotificationModel {
  const UserNotificationModel({
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

  factory UserNotificationModel.fromJson(Object? json) {
    final object = _requiredObject(json, 'notification');
    return UserNotificationModel(
      id: _requiredNonEmptyString(object['id'], 'id'),
      type: UserNotificationType.fromWireValue(
        _requiredNonEmptyString(object['type'], 'type'),
      ),
      source: UserNotificationSource.fromWireValue(
        _requiredNonEmptyString(object['source'], 'source'),
      ),
      resourceLabel: _nullableString(object['resourceLabel'], 'resourceLabel'),
      title: _nullableString(object['title'], 'title'),
      message: _nullableString(object['message'], 'message'),
      reservationId: _nullableInt(object['reservationId'], 'reservationId'),
      supportConversationId: _nullableString(
        object['supportConversationId'],
        'supportConversationId',
      ),
      eventTime: _nullableUtcDateTime(object['eventTime'], 'eventTime'),
      createdAt: _requiredUtcDateTime(object['createdAt'], 'createdAt'),
      readAt: _nullableUtcDateTime(object['readAt'], 'readAt'),
    );
  }

  final String id;
  final UserNotificationType type;
  final UserNotificationSource source;
  final String? resourceLabel;
  final String? title;
  final String? message;
  final int? reservationId;
  final String? supportConversationId;
  final DateTime? eventTime;
  final DateTime createdAt;
  final DateTime? readAt;

  bool get isRead => readAt != null;

  UserNotificationModel copyWith({DateTime? readAt}) {
    return UserNotificationModel(
      id: id,
      type: type,
      source: source,
      resourceLabel: resourceLabel,
      title: title,
      message: message,
      reservationId: reservationId,
      supportConversationId: supportConversationId,
      eventTime: eventTime,
      createdAt: createdAt,
      readAt: readAt ?? this.readAt,
    );
  }
}

class NotificationPageModel {
  const NotificationPageModel({
    required this.items,
    required this.nextCursor,
    required this.hasMore,
  });

  factory NotificationPageModel.fromJson(Object? json) {
    final object = _requiredObject(json, 'notification page');
    final rawItems = object['items'];
    if (rawItems is! List) {
      throw const FormatException(
        'Notification page items must be a JSON array.',
      );
    }

    final nextCursor = _nullableString(object['nextCursor'], 'nextCursor');
    final hasMore = _requiredBool(object['hasMore'], 'hasMore');
    if (hasMore && (nextCursor == null || nextCursor.isEmpty)) {
      throw const FormatException(
        'A notification page with more items must include nextCursor.',
      );
    }

    return NotificationPageModel(
      items: List<UserNotificationModel>.unmodifiable(
        rawItems.map(UserNotificationModel.fromJson),
      ),
      nextCursor: nextCursor,
      hasMore: hasMore,
    );
  }

  final List<UserNotificationModel> items;

  /// An opaque backend cursor. Clients must only pass it back verbatim.
  final String? nextCursor;
  final bool hasMore;
}

class NotificationUnreadCountModel {
  const NotificationUnreadCountModel({required this.unreadCount});

  factory NotificationUnreadCountModel.fromJson(Object? json) {
    final object = _requiredObject(json, 'notification unread count');
    final unreadCount = _requiredInt(object['unreadCount'], 'unreadCount');
    if (unreadCount < 0) {
      throw const FormatException('unreadCount cannot be negative.');
    }
    return NotificationUnreadCountModel(unreadCount: unreadCount);
  }

  final int unreadCount;
}

Map<String, Object?> _requiredObject(Object? value, String description) {
  if (value is! Map) {
    throw FormatException('$description must be a JSON object.');
  }

  final result = <String, Object?>{};
  for (final entry in value.entries) {
    if (entry.key is! String) {
      throw FormatException('$description contains a non-string key.');
    }
    result[entry.key as String] = entry.value;
  }
  return result;
}

String _requiredNonEmptyString(Object? value, String field) {
  if (value is String && value.isNotEmpty) {
    return value;
  }
  throw FormatException('$field must be a non-empty string.');
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

bool _requiredBool(Object? value, String field) {
  if (value is bool) {
    return value;
  }
  throw FormatException('$field must be a boolean.');
}

DateTime _requiredUtcDateTime(Object? value, String field) {
  final raw = _requiredNonEmptyString(value, field).trim();
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
    throw FormatException('$field must be an ISO-8601 timestamp.');
  }
  return parsed.toUtc();
}

DateTime? _nullableUtcDateTime(Object? value, String field) {
  return value == null ? null : _requiredUtcDateTime(value, field);
}
