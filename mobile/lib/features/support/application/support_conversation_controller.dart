import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/support_models.dart';
import '../data/support_repository.dart';
import '../realtime/support_realtime_models.dart';
import '../realtime/support_realtime_service.dart';

typedef ClientMessageIdFactory = String Function();

const Object _notSet = Object();

enum PendingSupportSendStatus { sending, failed }

class PendingSupportSend {
  const PendingSupportSend({
    required this.clientMessageId,
    required this.content,
    required this.status,
    this.error,
  });

  final String clientMessageId;
  final String content;
  final PendingSupportSendStatus status;
  final Object? error;

  PendingSupportSend copyWith({
    PendingSupportSendStatus? status,
    Object? error = _notSet,
  }) {
    return PendingSupportSend(
      clientMessageId: clientMessageId,
      content: content,
      status: status ?? this.status,
      error: identical(error, _notSet) ? this.error : error,
    );
  }
}

class SupportConversationState {
  const SupportConversationState({
    this.conversation,
    this.messages = const <SupportMessage>[],
    this.nextCursor,
    this.hasMore = false,
    this.isLoading = false,
    this.isLoadingOlder = false,
    this.isReconciling = false,
    this.isRequestingAdmin = false,
    this.error,
    this.paginationError,
    this.actionError,
    this.pendingSend,
    this.realtimeState = SupportRealtimeConnectionState.disconnected,
  });

  final SupportConversation? conversation;
  final List<SupportMessage> messages;
  final String? nextCursor;
  final bool hasMore;
  final bool isLoading;
  final bool isLoadingOlder;
  final bool isReconciling;
  final bool isRequestingAdmin;
  final Object? error;
  final Object? paginationError;
  final Object? actionError;
  final PendingSupportSend? pendingSend;
  final SupportRealtimeConnectionState realtimeState;

  bool get isClosed => conversation?.status == SupportConversationStatus.closed;

  bool get acceptsMessages => switch (conversation?.status) {
    SupportConversationStatus.aiActive ||
    SupportConversationStatus.waitingForAdmin ||
    SupportConversationStatus.adminActive ||
    SupportConversationStatus.resolved => true,
    SupportConversationStatus.closed ||
    SupportConversationStatus.unknown ||
    null => false,
  };

  bool get canSend => acceptsMessages && pendingSend == null;

  SupportConversationState copyWith({
    Object? conversation = _notSet,
    List<SupportMessage>? messages,
    Object? nextCursor = _notSet,
    bool? hasMore,
    bool? isLoading,
    bool? isLoadingOlder,
    bool? isReconciling,
    bool? isRequestingAdmin,
    Object? error = _notSet,
    Object? paginationError = _notSet,
    Object? actionError = _notSet,
    Object? pendingSend = _notSet,
    SupportRealtimeConnectionState? realtimeState,
  }) {
    return SupportConversationState(
      conversation: identical(conversation, _notSet)
          ? this.conversation
          : conversation as SupportConversation?,
      messages: messages ?? this.messages,
      nextCursor: identical(nextCursor, _notSet)
          ? this.nextCursor
          : nextCursor as String?,
      hasMore: hasMore ?? this.hasMore,
      isLoading: isLoading ?? this.isLoading,
      isLoadingOlder: isLoadingOlder ?? this.isLoadingOlder,
      isReconciling: isReconciling ?? this.isReconciling,
      isRequestingAdmin: isRequestingAdmin ?? this.isRequestingAdmin,
      error: identical(error, _notSet) ? this.error : error,
      paginationError: identical(paginationError, _notSet)
          ? this.paginationError
          : paginationError,
      actionError: identical(actionError, _notSet)
          ? this.actionError
          : actionError,
      pendingSend: identical(pendingSend, _notSet)
          ? this.pendingSend
          : pendingSend as PendingSupportSend?,
      realtimeState: realtimeState ?? this.realtimeState,
    );
  }
}

class SupportConversationController
    extends StateNotifier<SupportConversationState> {
  SupportConversationController({
    required this.conversationId,
    required SupportRepository repository,
    required SupportRealtimeService realtime,
    required ClientMessageIdFactory createClientMessageId,
  }) : // Public named parameters cannot use private initializing formals.
       // ignore: prefer_initializing_formals
       _repository = repository,
       _realtime = realtime,
       // ignore: prefer_initializing_formals
       _createClientMessageId = createClientMessageId,
       super(SupportConversationState(realtimeState: realtime.state));

  static const int _pageSize = 50;

  final String conversationId;
  final SupportRepository _repository;
  final SupportRealtimeService _realtime;
  final ClientMessageIdFactory _createClientMessageId;

  StreamSubscription<SupportRealtimeNotification>? _eventSubscription;
  StreamSubscription<SupportRealtimeConnectionState>? _connectionSubscription;
  Timer? _syncTimer;
  Future<void>? _reconcileFuture;
  bool _disposed = false;
  bool _markingRead = false;
  bool _isForeground = true;

  Future<void> initialize() async {
    state = state.copyWith(isLoading: true, error: null);
    _eventSubscription = _realtime.supportEvents
        .where((event) => event.conversationId == conversationId)
        .listen((_) {
          if (_isForeground) unawaited(reconcile());
        });
    _connectionSubscription = _realtime.connectionStates.listen(
      _handleConnectionState,
    );

    try {
      await _realtime.subscribeToConversation(conversationId);
    } on Object {
      // The ID remains usable over HTTP if the hub is unavailable.
    }
    unawaited(_ensureRealtimeStarted());

    try {
      final history = await _repository.getMessages(
        conversationId,
        pageSize: _pageSize,
      );
      if (_disposed) {
        return;
      }
      state = state.copyWith(
        conversation: history.conversation,
        messages: _mergeMessages(const [], history.messages.items),
        nextCursor: history.messages.nextCursor,
        hasMore: history.messages.hasMore,
        isLoading: false,
      );
      unawaited(_markReadIfNeeded());
    } on Object catch (error) {
      if (!_disposed) {
        state = state.copyWith(isLoading: false, error: error);
      }
    } finally {
      _scheduleSync();
    }
  }

  Future<void> reload() async {
    if (_disposed || state.isLoading) {
      return;
    }
    state = state.copyWith(isLoading: true, error: null);
    try {
      final history = await _repository.getMessages(
        conversationId,
        pageSize: _pageSize,
      );
      if (_disposed) {
        return;
      }
      state = state.copyWith(
        conversation: history.conversation,
        messages: _mergeMessages(const [], history.messages.items),
        nextCursor: history.messages.nextCursor,
        hasMore: history.messages.hasMore,
        isLoading: false,
      );
      unawaited(_markReadIfNeeded());
    } on Object catch (error) {
      if (!_disposed) {
        state = state.copyWith(isLoading: false, error: error);
      }
    }
  }

  /// Suspends advisory polling while the application is backgrounded.
  /// Persisted HTTP state remains authoritative when the app resumes.
  void onAppPaused() {
    _isForeground = false;
    _syncTimer?.cancel();
  }

  /// Restarts realtime delivery and immediately reconciles persisted state.
  Future<void> onAppResumed() async {
    if (_disposed) return;
    _isForeground = true;
    await _ensureRealtimeStarted();
    if (!state.isLoading) await reconcile();
    _scheduleSync();
  }

  Future<void> reconcile({bool reportError = false}) {
    final pending = _reconcileFuture;
    if (pending != null || _disposed) {
      return pending ?? Future<void>.value();
    }

    late final Future<void> future;
    future = _performReconciliation(reportError: reportError).whenComplete(() {
      if (identical(_reconcileFuture, future)) {
        _reconcileFuture = null;
      }
    });
    _reconcileFuture = future;
    return future;
  }

  Future<void> _performReconciliation({required bool reportError}) async {
    state = reportError
        ? state.copyWith(isReconciling: true, actionError: null)
        : state.copyWith(isReconciling: true);
    try {
      final history = await _repository.getMessages(
        conversationId,
        pageSize: _pageSize,
      );
      if (_disposed) {
        return;
      }

      final currentTail = state.messages.isEmpty
          ? null
          : state.messages.last.sequenceNumber;
      final incomingHead = history.messages.items.isEmpty
          ? null
          : history.messages.items.first.sequenceNumber;
      final missedRange =
          currentTail != null &&
          incomingHead != null &&
          incomingHead > currentTail + 1;

      state = state.copyWith(
        conversation: history.conversation,
        messages: _mergeMessages(state.messages, history.messages.items),
        nextCursor: state.messages.isEmpty || missedRange
            ? history.messages.nextCursor
            : state.nextCursor,
        hasMore: state.messages.isEmpty || missedRange
            ? history.messages.hasMore
            : state.hasMore,
        isReconciling: false,
      );
      unawaited(_markReadIfNeeded());
    } on Object catch (error) {
      if (!_disposed) {
        state = reportError
            ? state.copyWith(isReconciling: false, actionError: error)
            : state.copyWith(isReconciling: false);
      }
    }
  }

  Future<void> loadOlder() async {
    final cursor = state.nextCursor;
    if (_disposed || state.isLoadingOlder || !state.hasMore || cursor == null) {
      return;
    }

    state = state.copyWith(isLoadingOlder: true, paginationError: null);
    try {
      final history = await _repository.getMessages(
        conversationId,
        cursor: cursor,
        pageSize: _pageSize,
      );
      if (_disposed) {
        return;
      }
      state = state.copyWith(
        conversation: history.conversation,
        messages: _mergeMessages(state.messages, history.messages.items),
        nextCursor: history.messages.nextCursor,
        hasMore: history.messages.hasMore,
        isLoadingOlder: false,
      );
      unawaited(_markReadIfNeeded());
    } on Object catch (error) {
      if (!_disposed) {
        state = state.copyWith(isLoadingOlder: false, paginationError: error);
      }
    }
  }

  Future<void> requestAdmin() async {
    final conversation = state.conversation;
    if (_disposed ||
        state.isRequestingAdmin ||
        conversation?.status != SupportConversationStatus.aiActive) {
      return;
    }

    state = state.copyWith(isRequestingAdmin: true, actionError: null);
    try {
      final updated = await _repository.requestAdmin(conversationId);
      if (!_disposed) {
        state = state.copyWith(conversation: updated, isRequestingAdmin: false);
      }
    } on Object catch (error) {
      if (!_disposed) {
        state = state.copyWith(isRequestingAdmin: false, actionError: error);
      }
    }
  }

  Future<void> send(String content) async {
    final normalized = content.trim();
    if (_disposed || !state.canSend || normalized.isEmpty) {
      return;
    }
    if (normalized.length > 4000) {
      state = state.copyWith(
        actionError: ArgumentError.value(
          normalized.length,
          'content',
          'Support messages cannot exceed 4000 characters.',
        ),
      );
      return;
    }

    final pending = PendingSupportSend(
      clientMessageId: _createClientMessageId(),
      content: normalized,
      status: PendingSupportSendStatus.sending,
    );
    state = state.copyWith(pendingSend: pending, actionError: null);
    await _deliver(pending);
  }

  Future<void> retryFailedSend() async {
    final pending = state.pendingSend;
    if (_disposed ||
        pending == null ||
        pending.status != PendingSupportSendStatus.failed ||
        !state.acceptsMessages) {
      return;
    }

    final retry = pending.copyWith(
      status: PendingSupportSendStatus.sending,
      error: null,
    );
    state = state.copyWith(pendingSend: retry, actionError: null);
    await _deliver(retry);
  }

  void discardFailedSend() {
    if (state.pendingSend?.status == PendingSupportSendStatus.failed) {
      state = state.copyWith(pendingSend: null);
    }
  }

  Future<void> _deliver(PendingSupportSend pending) async {
    try {
      final response = await _repository.sendMessage(
        conversationId,
        clientMessageId: pending.clientMessageId,
        content: pending.content,
      );
      if (_disposed) {
        return;
      }
      final returnedMessages = <SupportMessage>[response.message];
      final assistantMessage = response.automation.assistantMessage;
      if (assistantMessage != null) {
        returnedMessages.add(assistantMessage);
      }
      state = state.copyWith(
        conversation: response.conversation,
        messages: _mergeMessages(state.messages, returnedMessages),
        pendingSend: null,
      );
      unawaited(_markReadIfNeeded());
      unawaited(reconcile());
    } on Object catch (error) {
      if (!_disposed &&
          state.pendingSend?.clientMessageId == pending.clientMessageId) {
        state = state.copyWith(
          pendingSend: pending.copyWith(
            status: PendingSupportSendStatus.failed,
            error: error,
          ),
        );
      }
    }
  }

  void clearActionError() {
    state = state.copyWith(actionError: null);
  }

  Future<void> _markReadIfNeeded() async {
    final conversation = state.conversation;
    if (_disposed ||
        _markingRead ||
        conversation == null ||
        conversation.unreadCount <= 0) {
      return;
    }

    _markingRead = true;
    try {
      await _repository.markRead(conversationId);
      if (!_disposed && state.conversation != null) {
        state = state.copyWith(
          conversation: _withUnreadCount(state.conversation!, 0),
        );
      }
    } on Object {
      // A later reconciliation or screen visit can safely retry this mutation.
    } finally {
      _markingRead = false;
    }
  }

  Future<void> _ensureRealtimeStarted() async {
    if (_disposed || _realtime.isConnected) {
      return;
    }
    try {
      await _realtime.start();
    } on Object {
      // Timed HTTP reconciliation remains available and retries the hub later.
    }
  }

  void _handleConnectionState(SupportRealtimeConnectionState connectionState) {
    if (_disposed) {
      return;
    }
    state = state.copyWith(realtimeState: connectionState);
    if (_isForeground &&
        connectionState == SupportRealtimeConnectionState.connected) {
      unawaited(reconcile());
    }
    _scheduleSync();
  }

  void _scheduleSync() {
    if (_disposed || !_isForeground) {
      return;
    }
    _syncTimer?.cancel();
    final delay =
        state.realtimeState == SupportRealtimeConnectionState.connected
        ? const Duration(seconds: 30)
        : const Duration(seconds: 8);
    _syncTimer = Timer(delay, () async {
      if (_disposed || !_isForeground) {
        return;
      }
      if (!_realtime.isConnected) {
        await _ensureRealtimeStarted();
      }
      await reconcile();
      _scheduleSync();
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _isForeground = false;
    _syncTimer?.cancel();
    unawaited(_eventSubscription?.cancel());
    unawaited(_connectionSubscription?.cancel());
    unawaited(
      _realtime.unsubscribeFromConversation(conversationId).catchError((_) {
        // Navigation and connection teardown can race safely.
      }),
    );
    super.dispose();
  }
}

List<SupportMessage> _mergeMessages(
  Iterable<SupportMessage> current,
  Iterable<SupportMessage> incoming,
) {
  final byId = <String, SupportMessage>{};
  for (final message in current.followedBy(incoming)) {
    byId[message.id] = message;
  }

  final merged = byId.values.toList()
    ..sort((left, right) {
      final bySequence = left.sequenceNumber.compareTo(right.sequenceNumber);
      return bySequence != 0
          ? bySequence
          : left.createdAt.compareTo(right.createdAt);
    });
  return List<SupportMessage>.unmodifiable(merged);
}

SupportConversation _withUnreadCount(
  SupportConversation conversation,
  int unreadCount,
) {
  return SupportConversation(
    id: conversation.id,
    title: conversation.title,
    category: conversation.category,
    status: conversation.status,
    isAnonymous: conversation.isAnonymous,
    unreadCount: unreadCount,
    createdAt: conversation.createdAt,
    updatedAt: conversation.updatedAt,
    resolvedAt: conversation.resolvedAt,
    closedAt: conversation.closedAt,
    lastMessage: conversation.lastMessage,
  );
}
