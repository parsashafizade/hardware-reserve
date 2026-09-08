import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hardware_reserve/features/support/application/support_conversation_controller.dart';
import 'package:hardware_reserve/features/support/data/support_models.dart';
import 'package:hardware_reserve/features/support/data/support_repository.dart';
import 'package:hardware_reserve/features/support/realtime/support_realtime_service.dart';

void main() {
  test('failed support send retries the exact UUID and content', () async {
    final repository = _RetrySupportRepository();
    final realtime = _FakeRealtimeService();
    final controller = SupportConversationController(
      conversationId: 'conversation-1',
      repository: repository,
      realtime: realtime,
      createClientMessageId: () => 'fixed-client-message-id',
    );
    addTearDown(() async {
      controller.dispose();
      await realtime.dispose();
    });

    await controller.initialize();
    await controller.send('لطفاً reservation ID: HR-20491 را بررسی کنید.');

    expect(
      controller.state.pendingSend?.status,
      PendingSupportSendStatus.failed,
    );
    expect(repository.calls, hasLength(1));

    await controller.retryFailedSend();

    expect(repository.calls, hasLength(2));
    expect(repository.calls[0], repository.calls[1]);
    expect(repository.calls.singleOrNull, isNull);
    expect(controller.state.pendingSend, isNull);
    expect(controller.state.messages.single.id, 'message-1');
  });
}

class _RetrySupportRepository extends SupportRepository {
  _RetrySupportRepository() : super(Dio());

  final List<(String, String)> calls = <(String, String)>[];
  final SupportConversation conversation = _conversation();

  @override
  Future<SupportMessageHistory> getMessages(
    String conversationId, {
    String? cursor,
    int pageSize = 50,
  }) async {
    return SupportMessageHistory(
      conversation: conversation,
      messages: const CursorPage<SupportMessage>(
        items: <SupportMessage>[],
        nextCursor: null,
        hasMore: false,
      ),
    );
  }

  @override
  Future<SendSupportMessageResponse> sendMessage(
    String conversationId, {
    required String clientMessageId,
    required String content,
  }) async {
    calls.add((clientMessageId, content));
    if (calls.length == 1) {
      throw DioException.connectionError(
        requestOptions: RequestOptions(path: '/support/messages'),
        reason: 'ambiguous transport failure',
      );
    }

    return SendSupportMessageResponse(
      message: SupportMessage(
        id: 'message-1',
        conversationId: conversationId,
        sequenceNumber: 1,
        senderType: SupportParticipantType.user,
        senderDisplayName: 'You',
        content: content,
        contentFormat: 'PLAIN_TEXT',
        createdAt: DateTime.utc(2026, 8, 20),
      ),
      conversation: conversation,
      isDuplicate: true,
      automation: const SupportAutomationResult(
        status: 'SKIPPED',
        assistantMessage: null,
      ),
    );
  }
}

class _FakeRealtimeService extends SupportRealtimeService {
  _FakeRealtimeService()
    : super(
        hubUrl: 'https://api.example.com/hubs/support',
        accessTokenFactory: () async => 'access',
      );

  @override
  bool get isConnected => true;

  @override
  Future<void> start() async {}

  @override
  Future<void> subscribeToConversation(String conversationId) async {}

  @override
  Future<void> unsubscribeFromConversation(String conversationId) async {}
}

SupportConversation _conversation() => SupportConversation(
  id: 'conversation-1',
  title: 'Reservation support',
  category: 'Reservations',
  status: SupportConversationStatus.aiActive,
  isAnonymous: false,
  unreadCount: 0,
  createdAt: DateTime.utc(2026, 8, 20),
  updatedAt: DateTime.utc(2026, 8, 20),
  resolvedAt: null,
  closedAt: null,
  lastMessage: null,
);
