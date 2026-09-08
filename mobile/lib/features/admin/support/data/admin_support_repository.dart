import 'package:dio/dio.dart';

import '../../../support/data/support_models.dart';
import 'admin_support_models.dart';

class AdminSupportRepository {
  const AdminSupportRepository(this._dio);

  static const Duration _messageTimeout = Duration(seconds: 110);
  static const Duration _suggestionTimeout = Duration(seconds: 110);

  final Dio _dio;

  Future<CursorPage<AdminSupportConversation>> getConversations({
    SupportConversationStatus? status,
    String? category,
    String? cursor,
    int pageSize = 30,
  }) async {
    _checkPageSize(pageSize, maximum: 50);
    final response = await _dio.get<Object?>(
      '/admin/support/conversations',
      queryParameters: <String, Object?>{
        if (status != null) 'status': status.wireValue,
        'category': ?_nonBlank(category),
        'cursor': ?_nonBlank(cursor),
        'pageSize': pageSize,
      },
    );
    return CursorPage<AdminSupportConversation>.fromJson(
      response.data,
      AdminSupportConversation.fromJson,
    );
  }

  Future<AdminSupportMessageHistory> getMessages(
    String conversationId, {
    String? cursor,
    int pageSize = 50,
  }) async {
    _checkPageSize(pageSize, maximum: 100);
    final response = await _dio.get<Object?>(
      '${_conversationPath(conversationId)}/messages',
      queryParameters: <String, Object?>{
        'cursor': ?_nonBlank(cursor),
        'pageSize': pageSize,
      },
    );
    return AdminSupportMessageHistory.fromJson(response.data);
  }

  Future<CursorPage<AdminSupportConversationEvent>> getEvents(
    String conversationId, {
    String? cursor,
    int pageSize = 30,
  }) async {
    _checkPageSize(pageSize, maximum: 100);
    final response = await _dio.get<Object?>(
      '${_conversationPath(conversationId)}/events',
      queryParameters: <String, Object?>{
        'cursor': ?_nonBlank(cursor),
        'pageSize': pageSize,
      },
    );
    return CursorPage<AdminSupportConversationEvent>.fromJson(
      response.data,
      AdminSupportConversationEvent.fromJson,
    );
  }

  Future<AdminSupportConversation> claim(String conversationId) async {
    final response = await _dio.post<Object?>(
      '${_conversationPath(conversationId)}/claim',
    );
    return AdminSupportConversation.fromJson(response.data);
  }

  /// Sends an idempotent Admin reply.
  ///
  /// An ambiguous failure must be retried with the same [clientMessageId] and
  /// exact [content]. The backend then returns the original message with
  /// `isDuplicate` set to true.
  Future<AdminSendSupportMessageResponse> sendMessage(
    String conversationId, {
    required String clientMessageId,
    required String content,
  }) async {
    final response = await _dio.post<Object?>(
      '${_conversationPath(conversationId)}/messages',
      data: <String, Object?>{
        'clientMessageId': clientMessageId,
        'content': content,
      },
      options: Options(receiveTimeout: _messageTimeout),
    );
    return AdminSendSupportMessageResponse.fromJson(response.data);
  }

  Future<int> markRead(String conversationId) async {
    final response = await _dio.post<Object?>(
      '${_conversationPath(conversationId)}/read',
    );
    return _unreadCount(response.data);
  }

  Future<int> getUnreadCount() async {
    final response = await _dio.get<Object?>('/admin/support/unread-count');
    return _unreadCount(response.data);
  }

  Future<AdminSupportConversation> resolve(String conversationId) async {
    final response = await _dio.post<Object?>(
      '${_conversationPath(conversationId)}/resolve',
    );
    return AdminSupportConversation.fromJson(response.data);
  }

  Future<AdminSupportConversation> close(String conversationId) async {
    final response = await _dio.post<Object?>(
      '${_conversationPath(conversationId)}/close',
    );
    return AdminSupportConversation.fromJson(response.data);
  }

  Future<AdminSupportConversation> updateTitle(
    String conversationId,
    String title,
  ) async {
    final response = await _dio.put<Object?>(
      '${_conversationPath(conversationId)}/title',
      data: <String, Object?>{'title': title.trim()},
    );
    return AdminSupportConversation.fromJson(response.data);
  }

  Future<AdminSupportSuggestedReply> generateSuggestedReply(
    String conversationId,
  ) async {
    final response = await _dio.post<Object?>(
      '${_conversationPath(conversationId)}/suggest-reply',
      options: Options(receiveTimeout: _suggestionTimeout),
    );
    return AdminSupportSuggestedReply.fromJson(response.data);
  }

  Future<List<AdminSupportQuickReply>> getQuickReplies({
    bool includeInactive = false,
  }) async {
    final response = await _dio.get<Object?>(
      '/admin/support/quick-replies',
      queryParameters: <String, Object?>{'includeInactive': includeInactive},
    );
    final raw = response.data;
    if (raw is! List) {
      throw const FormatException('Quick replies must be a JSON array.');
    }
    return List<AdminSupportQuickReply>.unmodifiable(
      raw.map(AdminSupportQuickReply.fromJson),
    );
  }

  Future<AdminSupportQuickReply> createQuickReply(
    UpsertAdminSupportQuickReplyRequest request,
  ) async {
    final response = await _dio.post<Object?>(
      '/admin/support/quick-replies',
      data: request.toJson(),
    );
    return AdminSupportQuickReply.fromJson(response.data);
  }

  Future<AdminSupportQuickReply> updateQuickReply(
    String quickReplyId,
    UpsertAdminSupportQuickReplyRequest request,
  ) async {
    final response = await _dio.put<Object?>(
      '/admin/support/quick-replies/${_pathId(quickReplyId, 'quickReplyId')}',
      data: request.toJson(),
    );
    return AdminSupportQuickReply.fromJson(response.data);
  }

  Future<void> deactivateQuickReply(String quickReplyId) async {
    await _dio.delete<Object?>(
      '/admin/support/quick-replies/${_pathId(quickReplyId, 'quickReplyId')}',
    );
  }

  static String _conversationPath(String conversationId) {
    return '/admin/support/conversations/${_pathId(conversationId, 'conversationId')}';
  }

  static String _pathId(String value, String name) {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(value, name, '$name cannot be empty.');
    }
    return Uri.encodeComponent(normalized);
  }

  static String? _nonBlank(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }

  static void _checkPageSize(int pageSize, {required int maximum}) {
    if (pageSize < 1 || pageSize > maximum) {
      throw RangeError.range(pageSize, 1, maximum, 'pageSize');
    }
  }

  static int _unreadCount(Object? json) {
    if (json is! Map) {
      throw const FormatException('Unread count must be a JSON object.');
    }
    final value = json['unreadMessages'];
    if (value is int && value >= 0) {
      return value;
    }
    if (value is num && value.isFinite && value == value.roundToDouble()) {
      final count = value.toInt();
      if (count >= 0) return count;
    }
    throw const FormatException(
      'unreadMessages must be a non-negative integer.',
    );
  }
}
