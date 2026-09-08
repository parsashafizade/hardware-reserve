import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hardware_reserve/features/admin/support/application/admin_support_conversation_controller.dart';
import 'package:hardware_reserve/features/admin/support/application/admin_support_inbox_controller.dart';
import 'package:hardware_reserve/features/admin/support/application/admin_support_quick_replies_controller.dart';
import 'package:hardware_reserve/features/admin/support/data/admin_support_models.dart';
import 'package:hardware_reserve/features/admin/support/data/admin_support_repository.dart';
import 'package:hardware_reserve/features/support/data/support_models.dart';
import 'package:hardware_reserve/features/support/realtime/support_realtime_models.dart';
import 'package:hardware_reserve/features/support/realtime/support_realtime_service.dart';

void main() {
  test('admin inbox contract preserves cursor, owner, status, and UTC', () {
    final page = CursorPage<AdminSupportConversation>.fromJson(
      <String, Object?>{
        'items': <Object?>[
          _conversationJson(
            status: 'WAITING_FOR_ADMIN',
            isAssigned: false,
            isAssignedToCurrentAdmin: false,
          ),
        ],
        'nextCursor': 'opaque-cursor',
        'hasMore': true,
      },
      AdminSupportConversation.fromJson,
    );

    expect(page.nextCursor, 'opaque-cursor');
    expect(page.hasMore, isTrue);
    expect(page.items.single.status, SupportConversationStatus.waitingForAdmin);
    expect(page.items.single.owner.type, AdminSupportOwnerType.user);
    expect(page.items.single.updatedAt.isUtc, isTrue);
  });

  test('unknown Admin Support owner values remain neutral', () {
    final owner = AdminSupportOwner.fromJson(<String, Object?>{
      'ownerType': 'FUTURE_OWNER',
      'userId': null,
      'fullName': null,
      'email': null,
    });

    expect(owner.type, AdminSupportOwnerType.unknown);
    expect(owner.isAnonymous, isFalse);
  });

  test('unknown Support status disables Admin mutations', () {
    final state = AdminSupportConversationState(
      conversation: _conversation(status: SupportConversationStatus.unknown),
    );

    expect(state.canClaim, isFalse);
    expect(state.canSend, isFalse);
    expect(state.canResolve, isFalse);
    expect(state.canClose, isFalse);
  });

  test('Admin lifecycle actions require the current claim owner', () {
    final waiting = AdminSupportConversationState(
      conversation: _conversation(
        status: SupportConversationStatus.waitingForAdmin,
        isAssignedToCurrentAdmin: false,
      ),
    );
    final assignedActive = AdminSupportConversationState(
      conversation: _conversation(),
    );
    final assignedElsewhere = AdminSupportConversationState(
      conversation: _conversation(isAssignedToCurrentAdmin: false),
    );
    final assignedResolved = AdminSupportConversationState(
      conversation: _conversation(status: SupportConversationStatus.resolved),
    );

    expect(waiting.canResolve, isFalse);
    expect(waiting.canClose, isFalse);
    expect(assignedActive.canResolve, isTrue);
    expect(assignedActive.canClose, isTrue);
    expect(assignedElsewhere.canResolve, isFalse);
    expect(assignedElsewhere.canClose, isFalse);
    expect(assignedResolved.canResolve, isFalse);
    expect(assignedResolved.canClose, isTrue);
  });

  test('quick reply request uses the backend field names', () {
    const request = UpsertAdminSupportQuickReplyRequest(
      title: '  GPU answer  ',
      content: '  Please restart SSH.  ',
      category: '  Technical  ',
      isActive: true,
      sortOrder: 4,
    );

    expect(request.toJson(), <String, Object?>{
      'title': 'GPU answer',
      'content': 'Please restart SSH.',
      'category': 'Technical',
      'isActive': true,
      'sortOrder': 4,
    });
  });

  test('ambiguous quick reply create reconciles one new exact match', () async {
    final repository = _QuickReplyRepository(commitBeforeFailure: true);
    final controller = AdminSupportQuickRepliesController(repository);
    addTearDown(controller.dispose);
    await controller.initialize();

    final created = await controller.create(_quickReplyRequest);

    expect(created.id, 'new-reply');
    expect(repository.createCalls, 1);
    expect(repository.readCalls, 3);
    expect(
      controller.state.replies.map((reply) => reply.id),
      unorderedEquals(<String>['new-reply', 'existing-reply']),
    );
    expect(controller.state.actionError, isNull);
    expect(controller.state.isSaving, isFalse);
  });

  test(
    'ambiguous create never matches a pre-existing exact duplicate',
    () async {
      final repository = _QuickReplyRepository(
        initialReplies: <AdminSupportQuickReply>[
          _quickReply(id: 'existing-reply'),
        ],
      );
      final controller = AdminSupportQuickRepliesController(repository);
      addTearDown(controller.dispose);
      await controller.initialize();

      await expectLater(
        controller.create(_quickReplyRequest),
        throwsA(same(repository.failure)),
      );

      expect(repository.createCalls, 1);
      expect(repository.readCalls, 3);
      expect(controller.state.replies.single.id, 'existing-reply');
      expect(controller.state.actionError, same(repository.failure));
      expect(controller.state.isSaving, isFalse);
    },
  );

  test('validation failure does not trigger create reconciliation', () async {
    final requestOptions = RequestOptions(path: '/admin/support/quick-replies');
    final validationFailure = DioException.badResponse(
      requestOptions: requestOptions,
      response: Response<Object?>(
        requestOptions: requestOptions,
        statusCode: 400,
      ),
      statusCode: 400,
    );
    final repository = _QuickReplyRepository(failure: validationFailure);
    final controller = AdminSupportQuickRepliesController(repository);
    addTearDown(controller.dispose);
    await controller.initialize();

    await expectLater(
      controller.create(_quickReplyRequest),
      throwsA(same(validationFailure)),
    );

    expect(repository.createCalls, 1);
    expect(
      repository.readCalls,
      2,
      reason: 'Only initialization and the pre-mutation baseline may read.',
    );
  });

  test('failed admin send retries the exact UUID and content', () async {
    final repository = _AdminSupportRepository(failFirstSend: true);
    final realtime = _FakeRealtimeService();
    final controller = AdminSupportConversationController(
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
    expect(await controller.send('  لطفاً HR-20491 را بررسی کنید.  '), isFalse);
    expect(controller.state.pendingSend?.status, AdminPendingSendStatus.failed);

    expect(await controller.retryFailedSend(), isTrue);

    expect(repository.sendCalls, hasLength(2));
    expect(repository.sendCalls[0], repository.sendCalls[1]);
    expect(
      repository.sendCalls.singleOrNull,
      isNull,
      reason: 'There must be two equal calls, not one regenerated request.',
    );
    expect(repository.sendCalls.first.$1, 'fixed-client-message-id');
    expect(repository.sendCalls.first.$2, 'لطفاً HR-20491 را بررسی کنید.');
    expect(controller.state.pendingSend, isNull);
    expect(controller.state.messages.single.id, 'message-1');
  });

  test('AI suggestion remains an explicit unsent draft', () async {
    final repository = _AdminSupportRepository();
    final realtime = _FakeRealtimeService();
    final controller = AdminSupportConversationController(
      conversationId: 'conversation-1',
      repository: repository,
      realtime: realtime,
      createClientMessageId: () => 'unused-id',
    );
    addTearDown(() async {
      controller.dispose();
      await realtime.dispose();
    });

    await controller.initialize();
    await controller.generateSuggestedReply();

    expect(repository.suggestionCalls, 1);
    expect(repository.sendCalls, isEmpty);
    expect(controller.state.suggestedReply?.draft, 'متن پیشنهادی');
    expect(controller.state.messages, isEmpty);
  });

  test('admin conversation pauses polling and reconciles on resume', () async {
    final repository = _AdminSupportRepository();
    final realtime = _FakeRealtimeService();
    final controller = AdminSupportConversationController(
      conversationId: 'conversation-1',
      repository: repository,
      realtime: realtime,
      createClientMessageId: () => 'unused-id',
    );
    addTearDown(() async {
      controller.dispose();
      await realtime.dispose();
    });

    await controller.initialize();
    expect(repository.messageReads, 1);

    controller.onAppPaused();
    realtime.emit('paused-conversation-event');
    await Future<void>.delayed(const Duration(milliseconds: 220));
    expect(repository.messageReads, 1);

    realtime.connected = false;
    await controller.onAppResumed();
    expect(realtime.startCalls, 1);
    expect(repository.messageReads, 2);
  });

  test('admin inbox pauses polling and refreshes on resume', () async {
    final repository = _AdminSupportRepository();
    final realtime = _FakeRealtimeService();
    final controller = AdminSupportInboxController(repository, realtime);
    addTearDown(() async {
      controller.dispose();
      await realtime.dispose();
    });

    await controller.initialize();
    expect(repository.conversationReads, 1);
    expect(repository.unreadReads, 1);

    controller.onAppPaused();
    realtime.emit('paused-inbox-event');
    await Future<void>.delayed(const Duration(milliseconds: 260));
    expect(repository.conversationReads, 1);

    realtime.connected = false;
    await controller.onAppResumed();
    expect(realtime.startCalls, 1);
    expect(repository.conversationReads, 2);
    expect(repository.unreadReads, 2);
  });
}

class _AdminSupportRepository extends AdminSupportRepository {
  _AdminSupportRepository({this.failFirstSend = false}) : super(Dio());

  final bool failFirstSend;
  final List<(String, String)> sendCalls = <(String, String)>[];
  int suggestionCalls = 0;
  int messageReads = 0;
  int conversationReads = 0;
  int unreadReads = 0;

  AdminSupportConversation get conversation => _conversation();

  @override
  Future<AdminSupportMessageHistory> getMessages(
    String conversationId, {
    String? cursor,
    int pageSize = 50,
  }) async {
    messageReads++;
    return AdminSupportMessageHistory(
      conversation: conversation,
      messages: const CursorPage<SupportMessage>(
        items: <SupportMessage>[],
        nextCursor: null,
        hasMore: false,
      ),
    );
  }

  @override
  Future<CursorPage<AdminSupportConversation>> getConversations({
    SupportConversationStatus? status,
    String? category,
    String? cursor,
    int pageSize = 30,
  }) async {
    conversationReads++;
    return CursorPage<AdminSupportConversation>(
      items: <AdminSupportConversation>[conversation],
      nextCursor: null,
      hasMore: false,
    );
  }

  @override
  Future<int> getUnreadCount() async {
    unreadReads++;
    return 0;
  }

  @override
  Future<CursorPage<AdminSupportConversationEvent>> getEvents(
    String conversationId, {
    String? cursor,
    int pageSize = 30,
  }) async {
    return const CursorPage<AdminSupportConversationEvent>(
      items: <AdminSupportConversationEvent>[],
      nextCursor: null,
      hasMore: false,
    );
  }

  @override
  Future<AdminSendSupportMessageResponse> sendMessage(
    String conversationId, {
    required String clientMessageId,
    required String content,
  }) async {
    sendCalls.add((clientMessageId, content));
    if (failFirstSend && sendCalls.length == 1) {
      throw DioException.connectionError(
        requestOptions: RequestOptions(
          path: '/admin/support/conversations/$conversationId/messages',
        ),
        reason: 'ambiguous transport failure',
      );
    }
    return AdminSendSupportMessageResponse(
      message: SupportMessage(
        id: 'message-1',
        conversationId: conversationId,
        sequenceNumber: 1,
        senderType: SupportParticipantType.admin,
        senderDisplayName: 'Support Team',
        content: content,
        contentFormat: 'PLAIN_TEXT',
        createdAt: DateTime.utc(2026, 8, 22),
      ),
      conversation: conversation,
      isDuplicate: failFirstSend,
    );
  }

  @override
  Future<AdminSupportSuggestedReply> generateSuggestedReply(
    String conversationId,
  ) async {
    suggestionCalls++;
    return AdminSupportSuggestedReply(
      draft: 'متن پیشنهادی',
      generatedAt: DateTime.utc(2026, 8, 22),
    );
  }
}

const _quickReplyRequest = UpsertAdminSupportQuickReplyRequest(
  title: '  SSH issue  ',
  content: '  Restart\u0000 SSH.  ',
  category: '  Provisioning  ',
  isActive: true,
  sortOrder: 2,
);

class _QuickReplyRepository extends AdminSupportRepository {
  _QuickReplyRepository({
    this.commitBeforeFailure = false,
    List<AdminSupportQuickReply>? initialReplies,
    Object? failure,
  }) : replies = <AdminSupportQuickReply>[
         ...?initialReplies,
         if (initialReplies == null)
           _quickReply(id: 'existing-reply', title: 'Other'),
       ],
       failure =
           failure ??
           DioException.connectionError(
             requestOptions: RequestOptions(
               path: '/admin/support/quick-replies',
             ),
             reason: 'ambiguous transport failure',
           ),
       super(Dio());

  final bool commitBeforeFailure;
  final List<AdminSupportQuickReply> replies;
  final Object failure;
  int createCalls = 0;
  int readCalls = 0;

  @override
  Future<List<AdminSupportQuickReply>> getQuickReplies({
    bool includeInactive = false,
  }) async {
    readCalls++;
    return List<AdminSupportQuickReply>.unmodifiable(replies);
  }

  @override
  Future<AdminSupportQuickReply> createQuickReply(
    UpsertAdminSupportQuickReplyRequest request,
  ) async {
    createCalls++;
    if (commitBeforeFailure) {
      replies.add(_quickReply(id: 'new-reply'));
    }
    throw failure;
  }
}

AdminSupportQuickReply _quickReply({
  required String id,
  String title = 'SSH issue',
}) {
  return AdminSupportQuickReply(
    id: id,
    title: title,
    content: 'Restart SSH.',
    category: 'Provisioning',
    isActive: true,
    sortOrder: 2,
    createdAt: DateTime.utc(2026, 8, 22),
    updatedAt: DateTime.utc(2026, 8, 22),
  );
}

class _FakeRealtimeService extends SupportRealtimeService {
  _FakeRealtimeService()
    : super(
        hubUrl: 'https://api.example.com/hubs/support',
        accessTokenFactory: () async => 'access',
      );

  final StreamController<SupportRealtimeNotification> _events =
      StreamController<SupportRealtimeNotification>.broadcast();
  bool connected = true;
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
        eventType: 'MESSAGE_CREATED',
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

AdminSupportConversation _conversation({
  SupportConversationStatus status = SupportConversationStatus.adminActive,
  bool isAssignedToCurrentAdmin = true,
}) => AdminSupportConversation(
  summary: SupportConversation(
    id: 'conversation-1',
    title: 'Reservation support',
    category: 'Reservations',
    status: status,
    isAnonymous: false,
    unreadCount: 0,
    createdAt: DateTime.utc(2026, 8, 22),
    updatedAt: DateTime.utc(2026, 8, 22),
    resolvedAt: null,
    closedAt: null,
    lastMessage: null,
  ),
  owner: const AdminSupportOwner(
    type: AdminSupportOwnerType.user,
    userId: 42,
    fullName: 'کاربر تست',
    email: 'user@example.com',
  ),
  isAssignedToCurrentAdmin: isAssignedToCurrentAdmin,
  isAssigned: true,
  aiHandoffSummary: null,
  aiHandoffReason: null,
  aiHandoffGeneratedAt: null,
);

Map<String, Object?> _conversationJson({
  required String status,
  required bool isAssigned,
  required bool isAssignedToCurrentAdmin,
}) => <String, Object?>{
  'id': 'conversation-1',
  'title': 'Support',
  'category': 'Technical',
  'status': status,
  'isAnonymous': false,
  'unreadCount': 2,
  'createdAt': '2026-08-22T08:00:00',
  'updatedAt': '2026-08-22T08:05:00+03:30',
  'resolvedAt': null,
  'closedAt': null,
  'lastMessage': null,
  'owner': <String, Object?>{
    'ownerType': 'USER',
    'userId': 42,
    'fullName': 'کاربر تست',
    'email': 'user@example.com',
  },
  'isAssignedToCurrentAdmin': isAssignedToCurrentAdmin,
  'isAssigned': isAssigned,
  'aiHandoffSummary': null,
  'aiHandoffReason': null,
  'aiHandoffGeneratedAt': null,
};
