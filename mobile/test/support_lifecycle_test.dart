import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hardware_reserve/features/support/application/support_conversation_controller.dart';
import 'package:hardware_reserve/features/support/application/support_history_controller.dart';
import 'package:hardware_reserve/features/support/data/support_models.dart';
import 'package:hardware_reserve/features/support/data/support_repository.dart';
import 'package:hardware_reserve/features/support/realtime/support_realtime_models.dart';
import 'package:hardware_reserve/features/support/realtime/support_realtime_service.dart';

void main() {
  test(
    'conversation pauses event reads and reconciles immediately on resume',
    () async {
      final repository = _LifecycleSupportRepository();
      final realtime = _LifecycleRealtimeService();
      final controller = SupportConversationController(
        conversationId: 'conversation-1',
        repository: repository,
        realtime: realtime,
        createClientMessageId: () => 'client-message-id',
      );
      addTearDown(() async {
        controller.dispose();
        await realtime.dispose();
      });

      await controller.initialize();
      expect(repository.messageReads, 1);

      controller.onAppPaused();
      realtime.emit('paused-event');
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(repository.messageReads, 1);

      realtime.connected = false;
      await controller.onAppResumed();
      expect(realtime.startCalls, 2);
      expect(repository.messageReads, 2);
    },
  );

  test('history refreshes authoritative state immediately on resume', () async {
    final repository = _LifecycleSupportRepository();
    final realtime = _LifecycleRealtimeService();
    final controller = SupportHistoryController(repository, realtime);
    addTearDown(() async {
      controller.dispose();
      await realtime.dispose();
    });

    await controller.initialize();
    expect(repository.conversationReads, 1);
    expect(repository.unreadReads, 1);

    controller.onAppPaused();
    realtime.emit('paused-history-event');
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(repository.conversationReads, 1);

    realtime.connected = false;
    await controller.onAppResumed();
    expect(realtime.startCalls, 2);
    expect(repository.conversationReads, 2);
    expect(repository.unreadReads, 2);
  });
}

class _LifecycleSupportRepository extends SupportRepository {
  _LifecycleSupportRepository() : super(Dio());

  int messageReads = 0;
  int conversationReads = 0;
  int unreadReads = 0;

  @override
  Future<SupportMessageHistory> getMessages(
    String conversationId, {
    String? cursor,
    int pageSize = 50,
  }) async {
    messageReads++;
    return SupportMessageHistory(
      conversation: _conversation,
      messages: const CursorPage<SupportMessage>(
        items: <SupportMessage>[],
        nextCursor: null,
        hasMore: false,
      ),
    );
  }

  @override
  Future<CursorPage<SupportConversation>> getConversations({
    String? cursor,
    int pageSize = 20,
  }) async {
    conversationReads++;
    return CursorPage<SupportConversation>(
      items: <SupportConversation>[_conversation],
      nextCursor: null,
      hasMore: false,
    );
  }

  @override
  Future<SupportUnreadCount> getUnreadCount() async {
    unreadReads++;
    return const SupportUnreadCount(unreadMessages: 0);
  }
}

class _LifecycleRealtimeService extends SupportRealtimeService {
  _LifecycleRealtimeService()
    : super(
        hubUrl: 'https://api.example.com/hubs/support',
        accessTokenFactory: () async => 'access',
      );

  final StreamController<SupportRealtimeNotification> _events =
      StreamController<SupportRealtimeNotification>.broadcast();
  bool connected = false;
  int startCalls = 0;

  @override
  Stream<SupportRealtimeNotification> get supportEvents => _events.stream;

  @override
  bool get isConnected => connected;

  @override
  Future<void> start() async {
    startCalls++;
    connected = true;
  }

  @override
  Future<void> subscribeToConversation(String conversationId) async {}

  @override
  Future<void> unsubscribeFromConversation(String conversationId) async {}

  void emit(String notificationId) {
    _events.add(
      SupportRealtimeNotification(
        notificationId: notificationId,
        conversationId: 'conversation-1',
        messageId: null,
        sequenceNumber: null,
        eventType: 'MESSAGE_SENT',
        occurredAt: DateTime.utc(2026, 8, 22),
      ),
    );
  }

  @override
  Future<void> dispose() async {
    await _events.close();
    await super.dispose();
  }
}

final _conversation = SupportConversation(
  id: 'conversation-1',
  title: 'Reservation support',
  category: 'Reservations',
  status: SupportConversationStatus.aiActive,
  isAnonymous: false,
  unreadCount: 0,
  createdAt: DateTime.utc(2026, 8, 22),
  updatedAt: DateTime.utc(2026, 8, 22),
  resolvedAt: null,
  closedAt: null,
  lastMessage: null,
);
