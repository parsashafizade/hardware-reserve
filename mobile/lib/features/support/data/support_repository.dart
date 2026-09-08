import 'package:dio/dio.dart';

import 'support_models.dart';

class SupportRepository {
  const SupportRepository(this._dio);

  static const Duration _messageTimeout = Duration(seconds: 110);

  final Dio _dio;

  Future<SupportConversation> createConversation({
    String? title,
    String? category,
  }) async {
    final data = <String, Object?>{};
    if (title != null) data['title'] = title;
    if (category != null) data['category'] = category;
    final response = await _dio.post<Object?>(
      '/support/conversations',
      data: data,
    );
    return SupportConversation.fromJson(response.data);
  }

  Future<CursorPage<SupportConversation>> getConversations({
    String? cursor,
    int pageSize = 20,
  }) async {
    _checkPageSize(pageSize, maximum: 50);
    final response = await _dio.get<Object?>(
      '/support/conversations',
      queryParameters: <String, Object?>{
        if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
        'pageSize': pageSize,
      },
    );
    return CursorPage<SupportConversation>.fromJson(
      response.data,
      SupportConversation.fromJson,
    );
  }

  Future<SupportMessageHistory> getMessages(
    String conversationId, {
    String? cursor,
    int pageSize = 50,
  }) async {
    _checkPageSize(pageSize, maximum: 100);
    final response = await _dio.get<Object?>(
      '${_conversationPath(conversationId)}/messages',
      queryParameters: <String, Object?>{
        if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
        'pageSize': pageSize,
      },
    );
    return SupportMessageHistory.fromJson(response.data);
  }

  /// Sends an idempotent support message.
  ///
  /// If delivery is ambiguous, retry with the same [clientMessageId]. The
  /// backend returns the original message with `isDuplicate` set to true.
  Future<SendSupportMessageResponse> sendMessage(
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
    return SendSupportMessageResponse.fromJson(response.data);
  }

  Future<SupportConversation> requestAdmin(String conversationId) async {
    final response = await _dio.post<Object?>(
      '${_conversationPath(conversationId)}/request-admin',
    );
    return SupportConversation.fromJson(response.data);
  }

  Future<SupportUnreadCount> markRead(String conversationId) async {
    final response = await _dio.post<Object?>(
      '${_conversationPath(conversationId)}/read',
    );
    return SupportUnreadCount.fromJson(response.data);
  }

  Future<SupportUnreadCount> getUnreadCount() async {
    final response = await _dio.get<Object?>('/support/unread-count');
    return SupportUnreadCount.fromJson(response.data);
  }

  static String _conversationPath(String conversationId) {
    final id = conversationId.trim();
    if (id.isEmpty) {
      throw ArgumentError.value(
        conversationId,
        'conversationId',
        'Conversation ID cannot be empty.',
      );
    }
    return '/support/conversations/${Uri.encodeComponent(id)}';
  }

  static void _checkPageSize(int pageSize, {required int maximum}) {
    if (pageSize < 1 || pageSize > maximum) {
      throw RangeError.range(pageSize, 1, maximum, 'pageSize');
    }
  }
}
