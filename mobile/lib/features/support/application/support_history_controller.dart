import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/support_models.dart';
import '../data/support_repository.dart';
import '../realtime/support_realtime_models.dart';
import '../realtime/support_realtime_service.dart';

const Object _notSet = Object();

class SupportHistoryState {
  const SupportHistoryState({
    this.conversations = const <SupportConversation>[],
    this.unreadMessages = 0,
    this.nextCursor,
    this.hasMore = false,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.isCreating = false,
    this.error,
    this.paginationError,
  });

  final List<SupportConversation> conversations;
  final int unreadMessages;
  final String? nextCursor;
  final bool hasMore;
  final bool isLoading;
  final bool isLoadingMore;
  final bool isCreating;
  final Object? error;
  final Object? paginationError;

  SupportHistoryState copyWith({
    List<SupportConversation>? conversations,
    int? unreadMessages,
    Object? nextCursor = _notSet,
    bool? hasMore,
    bool? isLoading,
    bool? isLoadingMore,
    bool? isCreating,
    Object? error = _notSet,
    Object? paginationError = _notSet,
  }) {
    return SupportHistoryState(
      conversations: conversations ?? this.conversations,
      unreadMessages: unreadMessages ?? this.unreadMessages,
      nextCursor: identical(nextCursor, _notSet)
          ? this.nextCursor
          : nextCursor as String?,
      hasMore: hasMore ?? this.hasMore,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      isCreating: isCreating ?? this.isCreating,
      error: identical(error, _notSet) ? this.error : error,
      paginationError: identical(paginationError, _notSet)
          ? this.paginationError
          : paginationError,
    );
  }
}

class SupportHistoryController extends StateNotifier<SupportHistoryState> {
  SupportHistoryController(
    this._repository,
    this._realtime, {
    this.receivesAdminBroadcasts = false,
  }) : _realtimeState = _realtime.state,
       super(const SupportHistoryState());

  static const int _pageSize = 20;

  final SupportRepository _repository;
  final SupportRealtimeService _realtime;
  final bool receivesAdminBroadcasts;
  StreamSubscription<SupportRealtimeNotification>? _eventSubscription;
  StreamSubscription<SupportRealtimeConnectionState>? _connectionSubscription;
  Timer? _eventRefreshTimer;
  Timer? _syncTimer;
  SupportRealtimeConnectionState _realtimeState;
  int _loadGeneration = 0;
  bool _isForeground = true;

  Future<void> initialize() async {
    _eventSubscription = _realtime.supportEvents.listen((event) {
      final belongsToPersonalInbox = state.conversations.any(
        (conversation) => conversation.id == event.conversationId,
      );
      if (!receivesAdminBroadcasts || belongsToPersonalInbox) {
        _debounceAuthoritativeRefresh();
      }
    });
    _connectionSubscription = _realtime.connectionStates.listen(
      _handleConnectionState,
    );
    unawaited(_ensureRealtimeStarted());
    await load();
    _scheduleSync();
  }

  Future<void> load() async {
    final generation = ++_loadGeneration;
    state = state.copyWith(isLoading: true, error: null, paginationError: null);

    try {
      final page = await _repository.getConversations(pageSize: _pageSize);
      if (!mounted || generation != _loadGeneration) {
        return;
      }
      state = state.copyWith(
        conversations: _mergeConversations(const [], page.items),
        nextCursor: page.nextCursor,
        hasMore: page.hasMore,
        isLoading: false,
      );
    } on Object catch (error) {
      if (!mounted || generation != _loadGeneration) {
        return;
      }
      state = state.copyWith(isLoading: false, error: error);
    }

    try {
      final unread = await _repository.getUnreadCount();
      if (mounted && generation == _loadGeneration) {
        state = state.copyWith(unreadMessages: unread.unreadMessages);
      }
    } on Object {
      // The conversation list remains useful if this secondary count fails.
    }
  }

  Future<void> loadMore() async {
    final cursor = state.nextCursor;
    if (state.isLoadingMore || !state.hasMore || cursor == null) {
      return;
    }

    state = state.copyWith(isLoadingMore: true, paginationError: null);
    try {
      final page = await _repository.getConversations(
        cursor: cursor,
        pageSize: _pageSize,
      );
      if (!mounted) {
        return;
      }
      state = state.copyWith(
        conversations: _mergeConversations(state.conversations, page.items),
        nextCursor: page.nextCursor,
        hasMore: page.hasMore,
        isLoadingMore: false,
      );
    } on Object catch (error) {
      if (mounted) {
        state = state.copyWith(isLoadingMore: false, paginationError: error);
      }
    }
  }

  /// Stops periodic reconciliation while the application is backgrounded.
  void onAppPaused() {
    _isForeground = false;
    _eventRefreshTimer?.cancel();
    _syncTimer?.cancel();
  }

  /// Restarts realtime delivery and refreshes the authoritative inbox state.
  Future<void> onAppResumed() async {
    if (!mounted) return;
    _isForeground = true;
    await _ensureRealtimeStarted();
    await load();
    _scheduleSync();
  }

  Future<SupportConversation> createConversation({String? category}) async {
    if (state.isCreating) {
      throw StateError('A support conversation is already being created.');
    }

    state = state.copyWith(isCreating: true);
    try {
      final normalizedCategory = category?.trim();
      final conversation = await _repository.createConversation(
        category: normalizedCategory == null || normalizedCategory.isEmpty
            ? null
            : normalizedCategory,
      );
      if (mounted) {
        state = state.copyWith(
          conversations: _mergeConversations(
            state.conversations,
            <SupportConversation>[conversation],
          ),
          isCreating: false,
        );
      }
      return conversation;
    } on Object {
      if (mounted) {
        state = state.copyWith(isCreating: false);
      }
      rethrow;
    }
  }

  void _debounceAuthoritativeRefresh() {
    if (!mounted || !_isForeground) {
      return;
    }
    _eventRefreshTimer?.cancel();
    _eventRefreshTimer = Timer(const Duration(milliseconds: 250), () {
      if (mounted) {
        unawaited(load());
      }
    });
  }

  Future<void> _ensureRealtimeStarted() async {
    if (!mounted || _realtime.isConnected) {
      return;
    }
    try {
      await _realtime.start();
    } on Object {
      // Periodic HTTP reads remain authoritative and retry the hub later.
    }
  }

  void _handleConnectionState(SupportRealtimeConnectionState connectionState) {
    if (!mounted) {
      return;
    }
    _realtimeState = connectionState;
    if (_isForeground &&
        connectionState == SupportRealtimeConnectionState.connected) {
      _debounceAuthoritativeRefresh();
    }
    _scheduleSync();
  }

  void _scheduleSync() {
    if (!mounted || !_isForeground) {
      return;
    }
    _syncTimer?.cancel();
    final delay = _realtimeState == SupportRealtimeConnectionState.connected
        ? const Duration(seconds: 30)
        : const Duration(seconds: 8);
    _syncTimer = Timer(delay, () async {
      if (!mounted || !_isForeground) {
        return;
      }
      if (!_realtime.isConnected) {
        await _ensureRealtimeStarted();
      }
      await load();
      _scheduleSync();
    });
  }

  @override
  void dispose() {
    _isForeground = false;
    _eventRefreshTimer?.cancel();
    _syncTimer?.cancel();
    unawaited(_eventSubscription?.cancel());
    unawaited(_connectionSubscription?.cancel());
    super.dispose();
  }
}

List<SupportConversation> _mergeConversations(
  Iterable<SupportConversation> current,
  Iterable<SupportConversation> incoming,
) {
  final byId = <String, SupportConversation>{};
  for (final conversation in current.followedBy(incoming)) {
    byId[conversation.id] = conversation;
  }

  final merged = byId.values.toList()
    ..sort((left, right) => right.updatedAt.compareTo(left.updatedAt));
  return List<SupportConversation>.unmodifiable(merged);
}
