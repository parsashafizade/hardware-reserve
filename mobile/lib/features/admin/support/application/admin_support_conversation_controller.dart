// Named public parameters intentionally initialize private implementation fields.
// ignore_for_file: prefer_initializing_formals

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../support/data/support_models.dart';
import '../../../support/realtime/support_realtime_models.dart';
import '../../../support/realtime/support_realtime_service.dart';
import '../data/admin_support_models.dart';
import '../data/admin_support_repository.dart';

typedef AdminClientMessageIdFactory = String Function();

const Object _notSet = Object();

enum AdminPendingSendStatus { sending, failed }

enum AdminSupportLifecycleAction { resolving, closing }

class AdminPendingSupportSend {
  const AdminPendingSupportSend({
    required this.clientMessageId,
    required this.content,
    required this.status,
    this.error,
  });

  final String clientMessageId;
  final String content;
  final AdminPendingSendStatus status;
  final Object? error;

  AdminPendingSupportSend copyWith({
    AdminPendingSendStatus? status,
    Object? error = _notSet,
  }) {
    return AdminPendingSupportSend(
      clientMessageId: clientMessageId,
      content: content,
      status: status ?? this.status,
      error: identical(error, _notSet) ? this.error : error,
    );
  }
}

class AdminSupportConversationState {
  const AdminSupportConversationState({
    this.conversation,
    this.messages = const <SupportMessage>[],
    this.events = const <AdminSupportConversationEvent>[],
    this.nextMessageCursor,
    this.nextEventCursor,
    this.hasMoreMessages = false,
    this.hasMoreEvents = false,
    this.isLoading = false,
    this.isLoadingOlderMessages = false,
    this.isLoadingOlderEvents = false,
    this.isReconciling = false,
    this.isClaiming = false,
    this.isUpdatingTitle = false,
    this.lifecycleAction,
    this.isSuggesting = false,
    this.suggestedReply,
    this.pendingSend,
    this.error,
    this.messagePaginationError,
    this.eventPaginationError,
    this.eventsError,
    this.actionError,
    this.realtimeState = SupportRealtimeConnectionState.disconnected,
  });

  final AdminSupportConversation? conversation;
  final List<SupportMessage> messages;
  final List<AdminSupportConversationEvent> events;
  final String? nextMessageCursor;
  final String? nextEventCursor;
  final bool hasMoreMessages;
  final bool hasMoreEvents;
  final bool isLoading;
  final bool isLoadingOlderMessages;
  final bool isLoadingOlderEvents;
  final bool isReconciling;
  final bool isClaiming;
  final bool isUpdatingTitle;
  final AdminSupportLifecycleAction? lifecycleAction;
  final bool isSuggesting;
  final AdminSupportSuggestedReply? suggestedReply;
  final AdminPendingSupportSend? pendingSend;
  final Object? error;
  final Object? messagePaginationError;
  final Object? eventPaginationError;
  final Object? eventsError;
  final Object? actionError;
  final SupportRealtimeConnectionState realtimeState;

  bool get canClaim =>
      conversation?.status == SupportConversationStatus.waitingForAdmin &&
      !(conversation?.isAssigned ?? false) &&
      !isClaiming;

  bool get canSend =>
      conversation?.status == SupportConversationStatus.adminActive &&
      (conversation?.isAssignedToCurrentAdmin ?? false) &&
      pendingSend == null;

  bool get canResolve =>
      lifecycleAction == null &&
      conversation?.status == SupportConversationStatus.adminActive &&
      (conversation?.isAssignedToCurrentAdmin ?? false);

  bool get canClose =>
      lifecycleAction == null &&
      (conversation?.isAssignedToCurrentAdmin ?? false) &&
      switch (conversation?.status) {
        SupportConversationStatus.adminActive ||
        SupportConversationStatus.resolved => true,
        SupportConversationStatus.aiActive ||
        SupportConversationStatus.waitingForAdmin ||
        SupportConversationStatus.closed ||
        SupportConversationStatus.unknown ||
        null => false,
      };

  AdminSupportConversationState copyWith({
    Object? conversation = _notSet,
    List<SupportMessage>? messages,
    List<AdminSupportConversationEvent>? events,
    Object? nextMessageCursor = _notSet,
    Object? nextEventCursor = _notSet,
    bool? hasMoreMessages,
    bool? hasMoreEvents,
    bool? isLoading,
    bool? isLoadingOlderMessages,
    bool? isLoadingOlderEvents,
    bool? isReconciling,
    bool? isClaiming,
    bool? isUpdatingTitle,
    Object? lifecycleAction = _notSet,
    bool? isSuggesting,
    Object? suggestedReply = _notSet,
    Object? pendingSend = _notSet,
    Object? error = _notSet,
    Object? messagePaginationError = _notSet,
    Object? eventPaginationError = _notSet,
    Object? eventsError = _notSet,
    Object? actionError = _notSet,
    SupportRealtimeConnectionState? realtimeState,
  }) {
    return AdminSupportConversationState(
      conversation: identical(conversation, _notSet)
          ? this.conversation
          : conversation as AdminSupportConversation?,
      messages: messages ?? this.messages,
      events: events ?? this.events,
      nextMessageCursor: identical(nextMessageCursor, _notSet)
          ? this.nextMessageCursor
          : nextMessageCursor as String?,
      nextEventCursor: identical(nextEventCursor, _notSet)
          ? this.nextEventCursor
          : nextEventCursor as String?,
      hasMoreMessages: hasMoreMessages ?? this.hasMoreMessages,
      hasMoreEvents: hasMoreEvents ?? this.hasMoreEvents,
      isLoading: isLoading ?? this.isLoading,
      isLoadingOlderMessages:
          isLoadingOlderMessages ?? this.isLoadingOlderMessages,
      isLoadingOlderEvents: isLoadingOlderEvents ?? this.isLoadingOlderEvents,
      isReconciling: isReconciling ?? this.isReconciling,
      isClaiming: isClaiming ?? this.isClaiming,
      isUpdatingTitle: isUpdatingTitle ?? this.isUpdatingTitle,
      lifecycleAction: identical(lifecycleAction, _notSet)
          ? this.lifecycleAction
          : lifecycleAction as AdminSupportLifecycleAction?,
      isSuggesting: isSuggesting ?? this.isSuggesting,
      suggestedReply: identical(suggestedReply, _notSet)
          ? this.suggestedReply
          : suggestedReply as AdminSupportSuggestedReply?,
      pendingSend: identical(pendingSend, _notSet)
          ? this.pendingSend
          : pendingSend as AdminPendingSupportSend?,
      error: identical(error, _notSet) ? this.error : error,
      messagePaginationError: identical(messagePaginationError, _notSet)
          ? this.messagePaginationError
          : messagePaginationError,
      eventPaginationError: identical(eventPaginationError, _notSet)
          ? this.eventPaginationError
          : eventPaginationError,
      eventsError: identical(eventsError, _notSet)
          ? this.eventsError
          : eventsError,
      actionError: identical(actionError, _notSet)
          ? this.actionError
          : actionError,
      realtimeState: realtimeState ?? this.realtimeState,
    );
  }
}

class AdminSupportConversationController
    extends StateNotifier<AdminSupportConversationState> {
  AdminSupportConversationController({
    required this.conversationId,
    required AdminSupportRepository repository,
    required SupportRealtimeService realtime,
    required AdminClientMessageIdFactory createClientMessageId,
  }) : _repository = repository,
       _realtime = realtime,
       _createClientMessageId = createClientMessageId,
       super(AdminSupportConversationState(realtimeState: realtime.state));

  static const int _messagePageSize = 50;
  static const int _eventPageSize = 30;

  final String conversationId;
  final AdminSupportRepository _repository;
  final SupportRealtimeService _realtime;
  final AdminClientMessageIdFactory _createClientMessageId;

  StreamSubscription<SupportRealtimeNotification>? _eventSubscription;
  StreamSubscription<SupportRealtimeConnectionState>? _connectionSubscription;
  Timer? _eventRefreshTimer;
  Timer? _syncTimer;
  Future<void>? _reconcileFuture;
  bool _disposed = false;
  bool _initialized = false;
  bool _markingRead = false;
  bool _isForeground = true;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    state = state.copyWith(isLoading: true, error: null);
    _eventSubscription = _realtime.supportEvents
        .where((event) => event.conversationId == conversationId)
        .listen((_) => _debounceReconcile());
    _connectionSubscription = _realtime.connectionStates.listen(
      _handleConnectionState,
    );
    try {
      await _realtime.subscribeToConversation(conversationId);
    } on Object {
      // REST authorization and state remain authoritative.
    }
    unawaited(_ensureRealtimeStarted());
    await _loadInitial();
    _scheduleSync();
  }

  Future<void> _loadInitial() async {
    try {
      final history = await _repository.getMessages(
        conversationId,
        pageSize: _messagePageSize,
      );
      if (_disposed) return;
      state = state.copyWith(
        conversation: history.conversation,
        messages: _mergeMessages(
          const <SupportMessage>[],
          history.messages.items,
        ),
        nextMessageCursor: history.messages.nextCursor,
        hasMoreMessages: history.messages.hasMore,
        isLoading: false,
      );
      unawaited(_markReadIfNeeded());
      await _loadInitialEvents();
    } on Object catch (error) {
      if (!_disposed) state = state.copyWith(isLoading: false, error: error);
    }
  }

  Future<void> _loadInitialEvents() async {
    try {
      final page = await _repository.getEvents(
        conversationId,
        pageSize: _eventPageSize,
      );
      if (_disposed) return;
      state = state.copyWith(
        events: _mergeEvents(
          const <AdminSupportConversationEvent>[],
          page.items,
        ),
        nextEventCursor: page.nextCursor,
        hasMoreEvents: page.hasMore,
        eventsError: null,
      );
    } on Object catch (error) {
      if (!_disposed) state = state.copyWith(eventsError: error);
    }
  }

  Future<void> reload() async {
    if (_disposed || state.isLoading) return;
    state = state.copyWith(isLoading: true, error: null);
    await _loadInitial();
  }

  Future<void> reconcile({bool reportError = false}) {
    final pending = _reconcileFuture;
    if (pending != null || _disposed) {
      return pending ?? Future<void>.value();
    }
    late final Future<void> operation;
    operation = _performReconcile(reportError: reportError).whenComplete(() {
      if (identical(_reconcileFuture, operation)) _reconcileFuture = null;
    });
    _reconcileFuture = operation;
    return operation;
  }

  Future<void> _performReconcile({required bool reportError}) async {
    state = reportError
        ? state.copyWith(isReconciling: true, actionError: null)
        : state.copyWith(isReconciling: true);
    try {
      final history = await _repository.getMessages(
        conversationId,
        pageSize: _messagePageSize,
      );
      if (_disposed) return;
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
        nextMessageCursor: state.messages.isEmpty || missedRange
            ? history.messages.nextCursor
            : state.nextMessageCursor,
        hasMoreMessages: state.messages.isEmpty || missedRange
            ? history.messages.hasMore
            : state.hasMoreMessages,
        isReconciling: false,
      );
      unawaited(_markReadIfNeeded());
      unawaited(_refreshEvents());
    } on Object catch (error) {
      if (!_disposed) {
        state = reportError
            ? state.copyWith(isReconciling: false, actionError: error)
            : state.copyWith(isReconciling: false);
      }
    }
  }

  Future<void> _refreshEvents() async {
    try {
      final page = await _repository.getEvents(
        conversationId,
        pageSize: _eventPageSize,
      );
      if (_disposed) return;
      state = state.copyWith(
        events: _mergeEvents(state.events, page.items),
        nextEventCursor: state.events.isEmpty
            ? page.nextCursor
            : state.nextEventCursor,
        hasMoreEvents: state.events.isEmpty
            ? page.hasMore
            : state.hasMoreEvents,
        eventsError: null,
      );
    } on Object catch (error) {
      if (!_disposed) state = state.copyWith(eventsError: error);
    }
  }

  Future<void> loadOlderMessages() async {
    final cursor = state.nextMessageCursor;
    if (_disposed ||
        state.isLoadingOlderMessages ||
        !state.hasMoreMessages ||
        cursor == null) {
      return;
    }
    state = state.copyWith(
      isLoadingOlderMessages: true,
      messagePaginationError: null,
    );
    try {
      final history = await _repository.getMessages(
        conversationId,
        cursor: cursor,
        pageSize: _messagePageSize,
      );
      if (_disposed) return;
      state = state.copyWith(
        conversation: history.conversation,
        messages: _mergeMessages(state.messages, history.messages.items),
        nextMessageCursor: history.messages.nextCursor,
        hasMoreMessages: history.messages.hasMore,
        isLoadingOlderMessages: false,
      );
    } on Object catch (error) {
      if (!_disposed) {
        state = state.copyWith(
          isLoadingOlderMessages: false,
          messagePaginationError: error,
        );
      }
    }
  }

  Future<void> loadOlderEvents() async {
    final cursor = state.nextEventCursor;
    if (_disposed ||
        state.isLoadingOlderEvents ||
        !state.hasMoreEvents ||
        cursor == null) {
      return;
    }
    state = state.copyWith(
      isLoadingOlderEvents: true,
      eventPaginationError: null,
    );
    try {
      final page = await _repository.getEvents(
        conversationId,
        cursor: cursor,
        pageSize: _eventPageSize,
      );
      if (_disposed) return;
      state = state.copyWith(
        events: _mergeEvents(state.events, page.items),
        nextEventCursor: page.nextCursor,
        hasMoreEvents: page.hasMore,
        isLoadingOlderEvents: false,
      );
    } on Object catch (error) {
      if (!_disposed) {
        state = state.copyWith(
          isLoadingOlderEvents: false,
          eventPaginationError: error,
        );
      }
    }
  }

  Future<void> claim() async {
    if (_disposed || !state.canClaim) return;
    state = state.copyWith(isClaiming: true, actionError: null);
    try {
      final conversation = await _repository.claim(conversationId);
      if (!_disposed) {
        state = state.copyWith(conversation: conversation, isClaiming: false);
        unawaited(reconcile());
      }
    } on Object catch (error) {
      if (!_disposed) {
        state = state.copyWith(isClaiming: false, actionError: error);
      }
    }
  }

  Future<void> updateTitle(String title) async {
    final normalized = title.trim();
    if (_disposed || state.isUpdatingTitle || normalized.isEmpty) return;
    if (normalized.length > 160) {
      state = state.copyWith(
        actionError: ArgumentError.value(
          title,
          'title',
          'Maximum 160 characters',
        ),
      );
      return;
    }
    state = state.copyWith(isUpdatingTitle: true, actionError: null);
    try {
      final conversation = await _repository.updateTitle(
        conversationId,
        normalized,
      );
      if (!_disposed) {
        state = state.copyWith(
          conversation: conversation,
          isUpdatingTitle: false,
        );
        unawaited(_refreshEvents());
      }
    } on Object catch (error) {
      if (!_disposed) {
        state = state.copyWith(isUpdatingTitle: false, actionError: error);
      }
    }
  }

  Future<void> resolve() =>
      _changeLifecycle(AdminSupportLifecycleAction.resolving);

  Future<void> close() => _changeLifecycle(AdminSupportLifecycleAction.closing);

  Future<void> _changeLifecycle(AdminSupportLifecycleAction action) async {
    if (_disposed || state.lifecycleAction != null) return;
    if (action == AdminSupportLifecycleAction.resolving && !state.canResolve) {
      return;
    }
    if (action == AdminSupportLifecycleAction.closing && !state.canClose) {
      return;
    }
    state = state.copyWith(lifecycleAction: action, actionError: null);
    try {
      final conversation = action == AdminSupportLifecycleAction.resolving
          ? await _repository.resolve(conversationId)
          : await _repository.close(conversationId);
      if (!_disposed) {
        state = state.copyWith(
          conversation: conversation,
          lifecycleAction: null,
        );
        unawaited(_refreshEvents());
      }
    } on Object catch (error) {
      if (!_disposed) {
        state = state.copyWith(lifecycleAction: null, actionError: error);
      }
    }
  }

  /// Requests a draft only. This method never sends or alters the composer.
  Future<void> generateSuggestedReply() async {
    if (_disposed || state.isSuggesting) return;
    state = state.copyWith(
      isSuggesting: true,
      suggestedReply: null,
      actionError: null,
    );
    try {
      final suggestion = await _repository.generateSuggestedReply(
        conversationId,
      );
      if (!_disposed) {
        state = state.copyWith(isSuggesting: false, suggestedReply: suggestion);
      }
    } on Object catch (error) {
      if (!_disposed) {
        state = state.copyWith(isSuggesting: false, actionError: error);
      }
    }
  }

  void dismissSuggestedReply() {
    if (state.suggestedReply != null) {
      state = state.copyWith(suggestedReply: null);
    }
  }

  Future<bool> send(String content) async {
    final normalized = content.trim();
    if (_disposed || !state.canSend || normalized.isEmpty) return false;
    if (normalized.length > 4000) {
      state = state.copyWith(
        actionError: ArgumentError.value(
          normalized.length,
          'content',
          'Support messages cannot exceed 4000 characters.',
        ),
      );
      return false;
    }
    final pending = AdminPendingSupportSend(
      clientMessageId: _createClientMessageId(),
      content: normalized,
      status: AdminPendingSendStatus.sending,
    );
    state = state.copyWith(pendingSend: pending, actionError: null);
    return _deliver(pending);
  }

  Future<bool> retryFailedSend() async {
    final pending = state.pendingSend;
    if (_disposed ||
        pending == null ||
        pending.status != AdminPendingSendStatus.failed ||
        state.conversation?.status != SupportConversationStatus.adminActive ||
        !(state.conversation?.isAssignedToCurrentAdmin ?? false)) {
      return false;
    }
    final retry = pending.copyWith(
      status: AdminPendingSendStatus.sending,
      error: null,
    );
    state = state.copyWith(pendingSend: retry, actionError: null);
    return _deliver(retry);
  }

  void discardFailedSend() {
    if (state.pendingSend?.status == AdminPendingSendStatus.failed) {
      state = state.copyWith(pendingSend: null);
    }
  }

  Future<bool> _deliver(AdminPendingSupportSend pending) async {
    try {
      final response = await _repository.sendMessage(
        conversationId,
        clientMessageId: pending.clientMessageId,
        content: pending.content,
      );
      if (_disposed) return false;
      state = state.copyWith(
        conversation: response.conversation,
        messages: _mergeMessages(state.messages, <SupportMessage>[
          response.message,
        ]),
        pendingSend: null,
        suggestedReply: null,
      );
      unawaited(_markReadIfNeeded());
      unawaited(reconcile());
      return true;
    } on Object catch (error) {
      if (!_disposed &&
          state.pendingSend?.clientMessageId == pending.clientMessageId) {
        state = state.copyWith(
          pendingSend: pending.copyWith(
            status: AdminPendingSendStatus.failed,
            error: error,
          ),
        );
      }
      return false;
    }
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
          conversation: state.conversation!.withUnreadCount(0),
        );
      }
    } on Object {
      // A later reconciliation safely retries this idempotent action.
    } finally {
      _markingRead = false;
    }
  }

  void clearActionError() {
    if (state.actionError != null) {
      state = state.copyWith(actionError: null);
    }
  }

  void onAppPaused() {
    _isForeground = false;
    _eventRefreshTimer?.cancel();
    _syncTimer?.cancel();
  }

  Future<void> onAppResumed() async {
    if (_disposed) return;
    _isForeground = true;
    await _ensureRealtimeStarted();
    if (!state.isLoading) await reconcile();
    _scheduleSync();
  }

  void _debounceReconcile() {
    if (_disposed || !_isForeground) return;
    _eventRefreshTimer?.cancel();
    _eventRefreshTimer = Timer(const Duration(milliseconds: 180), () {
      if (!_disposed && _isForeground) unawaited(reconcile());
    });
  }

  Future<void> _ensureRealtimeStarted() async {
    if (_disposed || _realtime.isConnected) return;
    try {
      await _realtime.start();
    } on Object {
      // Timed REST reconciliation retries the shared connection later.
    }
  }

  void _handleConnectionState(SupportRealtimeConnectionState connectionState) {
    if (_disposed) return;
    state = state.copyWith(realtimeState: connectionState);
    if (_isForeground &&
        connectionState == SupportRealtimeConnectionState.connected) {
      unawaited(reconcile());
    }
    _scheduleSync();
  }

  void _scheduleSync() {
    if (_disposed || !_isForeground) return;
    _syncTimer?.cancel();
    final delay =
        state.realtimeState == SupportRealtimeConnectionState.connected
        ? const Duration(seconds: 30)
        : const Duration(seconds: 8);
    _syncTimer = Timer(delay, () async {
      if (_disposed || !_isForeground) return;
      if (!_realtime.isConnected) await _ensureRealtimeStarted();
      await reconcile();
      _scheduleSync();
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _eventRefreshTimer?.cancel();
    _syncTimer?.cancel();
    unawaited(_eventSubscription?.cancel());
    unawaited(_connectionSubscription?.cancel());
    unawaited(
      _realtime.unsubscribeFromConversation(conversationId).catchError((_) {
        // Route and connection teardown can race safely.
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

List<AdminSupportConversationEvent> _mergeEvents(
  Iterable<AdminSupportConversationEvent> current,
  Iterable<AdminSupportConversationEvent> incoming,
) {
  final byId = <String, AdminSupportConversationEvent>{};
  for (final event in current.followedBy(incoming)) {
    byId[event.id] = event;
  }
  final merged = byId.values.toList()
    ..sort((left, right) => right.occurredAt.compareTo(left.occurredAt));
  return List<AdminSupportConversationEvent>.unmodifiable(merged);
}
