enum SupportConversationStatus {
  aiActive('AI_ACTIVE'),
  waitingForAdmin('WAITING_FOR_ADMIN'),
  adminActive('ADMIN_ACTIVE'),
  resolved('RESOLVED'),
  closed('CLOSED'),
  unknown('UNKNOWN');

  const SupportConversationStatus(this.wireValue);

  final String wireValue;

  static SupportConversationStatus fromWireValue(String value) {
    return values.firstWhere(
      (status) => status.wireValue == value,
      orElse: () => SupportConversationStatus.unknown,
    );
  }
}

enum SupportParticipantType {
  user('USER'),
  ai('AI'),
  admin('ADMIN'),
  unknown('UNKNOWN');

  const SupportParticipantType(this.wireValue);

  final String wireValue;

  static SupportParticipantType fromWireValue(String value) {
    return values.firstWhere(
      (participant) => participant.wireValue == value,
      orElse: () => SupportParticipantType.unknown,
    );
  }
}

class CursorPage<T> {
  const CursorPage({
    required this.items,
    required this.nextCursor,
    required this.hasMore,
  });

  final List<T> items;
  final String? nextCursor;
  final bool hasMore;

  factory CursorPage.fromJson(
    Object? json,
    T Function(Object? json) itemFromJson,
  ) {
    final object = _asJsonObject(json, 'cursor page');
    final rawItems = object['items'];
    if (rawItems is! List<Object?>) {
      throw const FormatException('Cursor page items must be a JSON array.');
    }

    return CursorPage<T>(
      items: List<T>.unmodifiable(rawItems.map(itemFromJson)),
      nextCursor: _nullableString(object['nextCursor'], 'nextCursor'),
      hasMore: _requiredBool(object['hasMore'], 'hasMore'),
    );
  }
}

class SupportLastMessage {
  const SupportLastMessage({
    required this.sequenceNumber,
    required this.senderType,
    required this.preview,
    required this.sentAt,
  });

  final int sequenceNumber;
  final SupportParticipantType senderType;
  final String preview;
  final DateTime sentAt;

  factory SupportLastMessage.fromJson(Object? json) {
    final object = _asJsonObject(json, 'support last message');
    return SupportLastMessage(
      sequenceNumber: _requiredInt(object['sequenceNumber'], 'sequenceNumber'),
      senderType: SupportParticipantType.fromWireValue(
        _requiredString(object['senderType'], 'senderType'),
      ),
      preview: _requiredString(object['preview'], 'preview'),
      sentAt: _requiredDateTime(object['sentAt'], 'sentAt'),
    );
  }
}

class SupportConversation {
  const SupportConversation({
    required this.id,
    required this.title,
    required this.category,
    required this.status,
    required this.isAnonymous,
    required this.unreadCount,
    required this.createdAt,
    required this.updatedAt,
    required this.resolvedAt,
    required this.closedAt,
    required this.lastMessage,
  });

  final String id;
  final String title;
  final String? category;
  final SupportConversationStatus status;
  final bool isAnonymous;
  final int unreadCount;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? resolvedAt;
  final DateTime? closedAt;
  final SupportLastMessage? lastMessage;

  factory SupportConversation.fromJson(Object? json) {
    final object = _asJsonObject(json, 'support conversation');
    final rawLastMessage = object['lastMessage'];

    return SupportConversation(
      id: _requiredString(object['id'], 'id'),
      title: _requiredString(object['title'], 'title'),
      category: _nullableString(object['category'], 'category'),
      status: SupportConversationStatus.fromWireValue(
        _requiredString(object['status'], 'status'),
      ),
      isAnonymous: _requiredBool(object['isAnonymous'], 'isAnonymous'),
      unreadCount: _requiredInt(object['unreadCount'], 'unreadCount'),
      createdAt: _requiredDateTime(object['createdAt'], 'createdAt'),
      updatedAt: _requiredDateTime(object['updatedAt'], 'updatedAt'),
      resolvedAt: _nullableDateTime(object['resolvedAt'], 'resolvedAt'),
      closedAt: _nullableDateTime(object['closedAt'], 'closedAt'),
      lastMessage: rawLastMessage == null
          ? null
          : SupportLastMessage.fromJson(rawLastMessage),
    );
  }
}

class SupportMessage {
  const SupportMessage({
    required this.id,
    required this.conversationId,
    required this.sequenceNumber,
    required this.senderType,
    required this.senderDisplayName,
    required this.content,
    required this.contentFormat,
    required this.createdAt,
  });

  final String id;
  final String conversationId;
  final int sequenceNumber;
  final SupportParticipantType senderType;
  final String senderDisplayName;
  final String content;
  final String contentFormat;
  final DateTime createdAt;

  factory SupportMessage.fromJson(Object? json) {
    final object = _asJsonObject(json, 'support message');
    return SupportMessage(
      id: _requiredString(object['id'], 'id'),
      conversationId: _requiredString(
        object['conversationId'],
        'conversationId',
      ),
      sequenceNumber: _requiredInt(object['sequenceNumber'], 'sequenceNumber'),
      senderType: SupportParticipantType.fromWireValue(
        _requiredString(object['senderType'], 'senderType'),
      ),
      senderDisplayName: _requiredString(
        object['senderDisplayName'],
        'senderDisplayName',
      ),
      content: _requiredString(object['content'], 'content'),
      contentFormat: _requiredString(object['contentFormat'], 'contentFormat'),
      createdAt: _requiredDateTime(object['createdAt'], 'createdAt'),
    );
  }
}

class SupportMessageHistory {
  const SupportMessageHistory({
    required this.conversation,
    required this.messages,
  });

  final SupportConversation conversation;
  final CursorPage<SupportMessage> messages;

  factory SupportMessageHistory.fromJson(Object? json) {
    final object = _asJsonObject(json, 'support message history');
    return SupportMessageHistory(
      conversation: SupportConversation.fromJson(object['conversation']),
      messages: CursorPage<SupportMessage>.fromJson(
        object['messages'],
        SupportMessage.fromJson,
      ),
    );
  }
}

class SupportUnreadCount {
  const SupportUnreadCount({required this.unreadMessages});

  final int unreadMessages;

  factory SupportUnreadCount.fromJson(Object? json) {
    final object = _asJsonObject(json, 'support unread count');
    return SupportUnreadCount(
      unreadMessages: _requiredInt(object['unreadMessages'], 'unreadMessages'),
    );
  }
}

class SupportAutomationResult {
  const SupportAutomationResult({
    required this.status,
    required this.assistantMessage,
  });

  final String status;
  final SupportMessage? assistantMessage;

  factory SupportAutomationResult.fromJson(Object? json) {
    final object = _asJsonObject(json, 'support automation result');
    final rawAssistantMessage = object['assistantMessage'];
    return SupportAutomationResult(
      status: _requiredString(object['status'], 'status'),
      assistantMessage: rawAssistantMessage == null
          ? null
          : SupportMessage.fromJson(rawAssistantMessage),
    );
  }
}

class SendSupportMessageResponse {
  const SendSupportMessageResponse({
    required this.message,
    required this.conversation,
    required this.isDuplicate,
    required this.automation,
  });

  final SupportMessage message;
  final SupportConversation conversation;
  final bool isDuplicate;
  final SupportAutomationResult automation;

  factory SendSupportMessageResponse.fromJson(Object? json) {
    final object = _asJsonObject(json, 'send support message response');
    return SendSupportMessageResponse(
      message: SupportMessage.fromJson(object['message']),
      conversation: SupportConversation.fromJson(object['conversation']),
      isDuplicate: _requiredBool(object['isDuplicate'], 'isDuplicate'),
      automation: SupportAutomationResult.fromJson(object['automation']),
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

bool _requiredBool(Object? value, String field) {
  if (value is bool) {
    return value;
  }
  throw FormatException('$field must be a boolean.');
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
