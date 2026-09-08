import '../../../support/data/support_models.dart';

enum AdminSupportOwnerType {
  user('USER'),
  anonymous('ANONYMOUS'),
  unknown('UNKNOWN');

  const AdminSupportOwnerType(this.wireValue);

  final String wireValue;

  factory AdminSupportOwnerType.fromWireValue(String value) {
    return values.firstWhere(
      (type) => type.wireValue == value,
      orElse: () => AdminSupportOwnerType.unknown,
    );
  }
}

class AdminSupportOwner {
  const AdminSupportOwner({
    required this.type,
    required this.userId,
    required this.fullName,
    required this.email,
  });

  factory AdminSupportOwner.fromJson(Object? json) {
    final object = _asJsonObject(json, 'admin support owner');
    return AdminSupportOwner(
      type: AdminSupportOwnerType.fromWireValue(
        _requiredString(object['ownerType'], 'ownerType'),
      ),
      userId: _nullableInt(object['userId'], 'userId'),
      fullName: _nullableString(object['fullName'], 'fullName'),
      email: _nullableString(object['email'], 'email'),
    );
  }

  final AdminSupportOwnerType type;
  final int? userId;
  final String? fullName;
  final String? email;

  bool get isAnonymous => type == AdminSupportOwnerType.anonymous;
}

class AdminSupportConversation {
  const AdminSupportConversation({
    required this.summary,
    required this.owner,
    required this.isAssignedToCurrentAdmin,
    required this.isAssigned,
    required this.aiHandoffSummary,
    required this.aiHandoffReason,
    required this.aiHandoffGeneratedAt,
  });

  factory AdminSupportConversation.fromJson(Object? json) {
    final object = _asJsonObject(json, 'admin support conversation');
    return AdminSupportConversation(
      summary: SupportConversation.fromJson(object),
      owner: AdminSupportOwner.fromJson(object['owner']),
      isAssignedToCurrentAdmin: _requiredBool(
        object['isAssignedToCurrentAdmin'],
        'isAssignedToCurrentAdmin',
      ),
      isAssigned: _requiredBool(object['isAssigned'], 'isAssigned'),
      aiHandoffSummary: _nullableString(
        object['aiHandoffSummary'],
        'aiHandoffSummary',
      ),
      aiHandoffReason: _nullableString(
        object['aiHandoffReason'],
        'aiHandoffReason',
      ),
      aiHandoffGeneratedAt: _nullableDateTime(
        object['aiHandoffGeneratedAt'],
        'aiHandoffGeneratedAt',
      ),
    );
  }

  final SupportConversation summary;
  final AdminSupportOwner owner;
  final bool isAssignedToCurrentAdmin;
  final bool isAssigned;
  final String? aiHandoffSummary;
  final String? aiHandoffReason;
  final DateTime? aiHandoffGeneratedAt;

  String get id => summary.id;
  String get title => summary.title;
  String? get category => summary.category;
  SupportConversationStatus get status => summary.status;
  int get unreadCount => summary.unreadCount;
  DateTime get updatedAt => summary.updatedAt;
  SupportLastMessage? get lastMessage => summary.lastMessage;

  AdminSupportConversation withUnreadCount(int unreadCount) {
    return AdminSupportConversation(
      summary: SupportConversation(
        id: summary.id,
        title: summary.title,
        category: summary.category,
        status: summary.status,
        isAnonymous: summary.isAnonymous,
        unreadCount: unreadCount,
        createdAt: summary.createdAt,
        updatedAt: summary.updatedAt,
        resolvedAt: summary.resolvedAt,
        closedAt: summary.closedAt,
        lastMessage: summary.lastMessage,
      ),
      owner: owner,
      isAssignedToCurrentAdmin: isAssignedToCurrentAdmin,
      isAssigned: isAssigned,
      aiHandoffSummary: aiHandoffSummary,
      aiHandoffReason: aiHandoffReason,
      aiHandoffGeneratedAt: aiHandoffGeneratedAt,
    );
  }
}

class AdminSupportMessageHistory {
  const AdminSupportMessageHistory({
    required this.conversation,
    required this.messages,
  });

  factory AdminSupportMessageHistory.fromJson(Object? json) {
    final object = _asJsonObject(json, 'admin support message history');
    return AdminSupportMessageHistory(
      conversation: AdminSupportConversation.fromJson(object['conversation']),
      messages: CursorPage<SupportMessage>.fromJson(
        object['messages'],
        SupportMessage.fromJson,
      ),
    );
  }

  final AdminSupportConversation conversation;
  final CursorPage<SupportMessage> messages;
}

class AdminSendSupportMessageResponse {
  const AdminSendSupportMessageResponse({
    required this.message,
    required this.conversation,
    required this.isDuplicate,
  });

  factory AdminSendSupportMessageResponse.fromJson(Object? json) {
    final object = _asJsonObject(json, 'admin support send response');
    return AdminSendSupportMessageResponse(
      message: SupportMessage.fromJson(object['message']),
      conversation: AdminSupportConversation.fromJson(object['conversation']),
      isDuplicate: _requiredBool(object['isDuplicate'], 'isDuplicate'),
    );
  }

  final SupportMessage message;
  final AdminSupportConversation conversation;
  final bool isDuplicate;
}

class AdminSupportConversationEvent {
  const AdminSupportConversationEvent({
    required this.id,
    required this.eventType,
    required this.actorType,
    required this.previousStatus,
    required this.newStatus,
    required this.details,
    required this.occurredAt,
  });

  factory AdminSupportConversationEvent.fromJson(Object? json) {
    final object = _asJsonObject(json, 'admin support conversation event');
    return AdminSupportConversationEvent(
      id: _requiredString(object['id'], 'id'),
      eventType: _requiredString(object['eventType'], 'eventType'),
      actorType: _requiredString(object['actorType'], 'actorType'),
      previousStatus: _nullableStatus(
        object['previousStatus'],
        'previousStatus',
      ),
      newStatus: _nullableStatus(object['newStatus'], 'newStatus'),
      details: _nullableString(object['details'], 'details'),
      occurredAt: _requiredDateTime(object['occurredAt'], 'occurredAt'),
    );
  }

  final String id;
  final String eventType;
  final String actorType;
  final SupportConversationStatus? previousStatus;
  final SupportConversationStatus? newStatus;
  final String? details;
  final DateTime occurredAt;
}

class AdminSupportQuickReply {
  const AdminSupportQuickReply({
    required this.id,
    required this.title,
    required this.content,
    required this.category,
    required this.isActive,
    required this.sortOrder,
    required this.createdAt,
    required this.updatedAt,
  });

  factory AdminSupportQuickReply.fromJson(Object? json) {
    final object = _asJsonObject(json, 'admin support quick reply');
    return AdminSupportQuickReply(
      id: _requiredString(object['id'], 'id'),
      title: _requiredString(object['title'], 'title'),
      content: _requiredString(object['content'], 'content'),
      category: _nullableString(object['category'], 'category'),
      isActive: _requiredBool(object['isActive'], 'isActive'),
      sortOrder: _requiredInt(object['sortOrder'], 'sortOrder'),
      createdAt: _requiredDateTime(object['createdAt'], 'createdAt'),
      updatedAt: _requiredDateTime(object['updatedAt'], 'updatedAt'),
    );
  }

  final String id;
  final String title;
  final String content;
  final String? category;
  final bool isActive;
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;
}

class UpsertAdminSupportQuickReplyRequest {
  const UpsertAdminSupportQuickReplyRequest({
    required this.title,
    required this.content,
    required this.category,
    required this.isActive,
    required this.sortOrder,
  });

  final String title;
  final String content;
  final String? category;
  final bool isActive;
  final int sortOrder;

  Map<String, Object?> toJson() => <String, Object?>{
    'title': title.trim(),
    'content': content.trim(),
    'category': _normalizedOptional(category),
    'isActive': isActive,
    'sortOrder': sortOrder,
  };

  /// Mirrors the backend normalization used when a create response is lost.
  /// IDs are checked separately so a pre-existing duplicate is never treated
  /// as the result of the current request.
  bool matches(AdminSupportQuickReply reply) {
    return reply.title == title.trim() &&
        reply.content == _normalizedMessageContent(content) &&
        reply.category == _normalizedOptional(category) &&
        reply.isActive == isActive &&
        reply.sortOrder == sortOrder;
  }
}

class AdminSupportSuggestedReply {
  const AdminSupportSuggestedReply({
    required this.draft,
    required this.generatedAt,
  });

  factory AdminSupportSuggestedReply.fromJson(Object? json) {
    final object = _asJsonObject(json, 'admin support suggested reply');
    return AdminSupportSuggestedReply(
      draft: _requiredString(object['draft'], 'draft'),
      generatedAt: _requiredDateTime(object['generatedAt'], 'generatedAt'),
    );
  }

  final String draft;
  final DateTime generatedAt;
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

DateTime _requiredDateTime(Object? value, String field) {
  final raw = _requiredString(value, field).trim();
  final separator = raw.lastIndexOf('T') > raw.lastIndexOf(' ')
      ? raw.lastIndexOf('T')
      : raw.lastIndexOf(' ');
  final offset = raw.lastIndexOf('+') > raw.lastIndexOf('-')
      ? raw.lastIndexOf('+')
      : raw.lastIndexOf('-');
  final hasZone =
      raw.endsWith('Z') ||
      raw.endsWith('z') ||
      (separator >= 0 && offset > separator);
  final parsed = DateTime.tryParse(hasZone ? raw : '${raw}Z');
  if (parsed == null) {
    throw FormatException('$field must be an ISO-8601 timestamp.');
  }
  return parsed.toUtc();
}

DateTime? _nullableDateTime(Object? value, String field) {
  return value == null ? null : _requiredDateTime(value, field);
}

SupportConversationStatus? _nullableStatus(Object? value, String field) {
  if (value == null) {
    return null;
  }
  return SupportConversationStatus.fromWireValue(_requiredString(value, field));
}

String? _normalizedOptional(String? value) {
  final normalized = value?.trim();
  return normalized == null || normalized.isEmpty ? null : normalized;
}

String _normalizedMessageContent(String value) {
  return value.replaceAll('\u0000', '').trim();
}
