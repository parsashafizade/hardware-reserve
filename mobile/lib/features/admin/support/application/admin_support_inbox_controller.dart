import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../support/data/support_models.dart';
import '../../../support/realtime/support_realtime_models.dart';
import '../../../support/realtime/support_realtime_service.dart';
import '../data/admin_support_models.dart';
import '../data/admin_support_repository.dart';

const Object _notSet = Object();

class AdminSupportInboxState {
  const AdminSupportInboxState({
    this.conversations = const <AdminSupportConversation>[],
    this.unreadMessages = 0,
    this.statusFilter,
    this.categoryFilter,
    this.searchQuery = '',
    this.nextCursor,
    this.hasMore = false,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error,
    this.paginationError,
    this.realtimeState = SupportRealtimeConnectionState.disconnected,
  });

  final List<AdminSupportConversation> conversations;
  final int unreadMessages;
  final SupportConversationStatus? statusFilter;
  final String? categoryFilter;
  final String searchQuery;
  final String? nextCursor;
  final bool hasMore;
  final bool isLoading;
  final bool isLoadingMore;
  final Object? error;
  final Object? paginationError;
  final SupportRealtimeConnectionState realtimeState;

  List<AdminSupportConversation> get visibleConversations {
    final query = searchQuery.trim().toLowerCase();
    if (query.isEmpty) {
      return conversations;
    }
    return List<AdminSupportConversation>.unmodifiable(
      conversations.where((conversation) {
        final searchable = <String?>[
          conversation.title,
          conversation.category,
          conversation.owner.fullName,
          conversation.owner.email,
          conversation.lastMessage?.preview,
          conversation.owner.userId?.toString(),
        ].whereType<String>().join(' ').toLowerCase();
        return searchable.contains(query);
      }),
    );
  }

  AdminSupportInboxState copyWith({
    List<AdminSupportConversation>? conversations,
    int? unreadMessages,
    Object? statusFilter = _notSet,
    Object? categoryFilter = _notSet,
    String? searchQuery,
    Object? nextCursor = _notSet,
    bool? hasMore,
    bool? isLoading,
    bool? isLoadingMore,
    Object? error = _notSet,
    Object? paginationError = _notSet,
    SupportRealtimeConnectionState? realtimeState,
  }) {
    return AdminSupportInboxState(
      conversations: conversations ?? this.conversations,
      unreadMessages: unreadMessages ?? this.unreadMessages,
      statusFilter: identical(statusFilter, _notSet)
          ? this.statusFilter
          : statusFilter as SupportConversationStatus?,
      categoryFilter: identical(categoryFilter, _notSet)
          ? this.categoryFilter
          : categoryFilter as String?,
      searchQuery: searchQuery ?? this.searchQuery,
      nextCursor: identical(nextCursor, _notSet)
          ? this.nextCursor
          : nextCursor as String?,
      hasMore: hasMore ?? this.hasMore,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: identical(error, _notSet) ? this.error : error,
      paginationError: identical(paginationError, _notSet)
          ? this.paginationError
          : paginationError,
      realtimeState: realtimeState ?? this.realtimeState,
    );
  }
}

class AdminSupportInboxController
    extends StateNotifier<AdminSupportInboxState> {
  AdminSupportInboxController(this._repository, this._realtime)
    : super(AdminSupportInboxState(realtimeState: _realtime.state));

  static const int _pageSize = 30;

  final AdminSupportRepository _repository;
  final SupportRealtimeService _realtime;
  StreamSubscription<SupportRealtimeNotification>? _eventSubscription;
  StreamSubscription<SupportRealtimeConnectionState>? _connectionSubscription;
  Timer? _eventRefreshTimer;
  Timer? _syncTimer;
  int _loadGeneration = 0;
  bool _initialized = false;
  bool _isForeground = true;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    _eventSubscription = _realtime.supportEvents.listen((_) {
      _debounceAuthoritativeRefresh();
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
    state = state.copyWith(
      isLoading: true,
      isLoadingMore: false,
      error: null,
      paginationError: null,
    );

    try {
      final page = await _repository.getConversations(
        status: state.statusFilter,
        category: state.categoryFilter,
        pageSize: _pageSize,
      );
      if (!mounted || generation != _loadGeneration) return;
      state = state.copyWith(
        conversations: _sortConversations(page.items),
        nextCursor: page.nextCursor,
        hasMore: page.hasMore,
        isLoading: false,
      );
    } on Object catch (error) {
      if (!mounted || generation != _loadGeneration) return;
      state = state.copyWith(isLoading: false, error: error);
    }

    await _refreshUnread(generation);
  }

  Future<void> _refreshUnread([int? generation]) async {
    try {
      final count = await _repository.getUnreadCount();
      if (mounted && (generation == null || generation == _loadGeneration)) {
        state = state.copyWith(unreadMessages: count);
      }
    } on Object {
      // Per-conversation unread state remains usable until the next sync.
    }
  }

  Future<void> loadMore() async {
    final cursor = state.nextCursor;
    if (state.isLoading ||
        state.isLoadingMore ||
        !state.hasMore ||
        cursor == null) {
      return;
    }
    final generation = _loadGeneration;
    state = state.copyWith(isLoadingMore: true, paginationError: null);
    try {
      final page = await _repository.getConversations(
        status: state.statusFilter,
        category: state.categoryFilter,
        cursor: cursor,
        pageSize: _pageSize,
      );
      if (!mounted || generation != _loadGeneration) return;
      state = state.copyWith(
        conversations: _mergeConversations(state.conversations, page.items),
        nextCursor: page.nextCursor,
        hasMore: page.hasMore,
        isLoadingMore: false,
      );
    } on Object catch (error) {
      if (mounted && generation == _loadGeneration) {
        state = state.copyWith(isLoadingMore: false, paginationError: error);
      }
    }
  }

  Future<void> setStatusFilter(SupportConversationStatus? status) async {
    if (state.statusFilter == status) return;
    state = state.copyWith(statusFilter: status, nextCursor: null);
    await load();
  }

  Future<void> setCategoryFilter(String? category) async {
    final normalized = category?.trim();
    final value = normalized == null || normalized.isEmpty ? null : normalized;
    if (state.categoryFilter == value) return;
    state = state.copyWith(categoryFilter: value, nextCursor: null);
    await load();
  }

  void setSearchQuery(String query) {
    if (state.searchQuery != query) {
      state = state.copyWith(searchQuery: query);
    }
  }

  void onAppPaused() {
    _isForeground = false;
    _eventRefreshTimer?.cancel();
    _syncTimer?.cancel();
  }

  Future<void> onAppResumed() async {
    if (!mounted) return;
    _isForeground = true;
    await _ensureRealtimeStarted();
    await load();
    _scheduleSync();
  }

  void _debounceAuthoritativeRefresh() {
    if (!mounted || !_isForeground) return;
    _eventRefreshTimer?.cancel();
    _eventRefreshTimer = Timer(const Duration(milliseconds: 220), () {
      if (mounted && _isForeground) unawaited(load());
    });
  }

  Future<void> _ensureRealtimeStarted() async {
    if (!mounted || _realtime.isConnected) return;
    try {
      await _realtime.start();
    } on Object {
      // Persisted API state is authoritative and the sync timer retries.
    }
  }

  void _handleConnectionState(SupportRealtimeConnectionState connectionState) {
    if (!mounted) return;
    state = state.copyWith(realtimeState: connectionState);
    if (_isForeground &&
        connectionState == SupportRealtimeConnectionState.connected) {
      _debounceAuthoritativeRefresh();
    }
    _scheduleSync();
  }

  void _scheduleSync() {
    if (!mounted || !_isForeground) return;
    _syncTimer?.cancel();
    final delay =
        state.realtimeState == SupportRealtimeConnectionState.connected
        ? const Duration(seconds: 30)
        : const Duration(seconds: 8);
    _syncTimer = Timer(delay, () async {
      if (!mounted || !_isForeground) return;
      if (!_realtime.isConnected) await _ensureRealtimeStarted();
      await load();
      _scheduleSync();
    });
  }

  @override
  void dispose() {
    _eventRefreshTimer?.cancel();
    _syncTimer?.cancel();
    unawaited(_eventSubscription?.cancel());
    unawaited(_connectionSubscription?.cancel());
    super.dispose();
  }
}

List<AdminSupportConversation> _sortConversations(
  Iterable<AdminSupportConversation> conversations,
) {
  final sorted = conversations.toList()
    ..sort((left, right) => right.updatedAt.compareTo(left.updatedAt));
  return List<AdminSupportConversation>.unmodifiable(sorted);
}

List<AdminSupportConversation> _mergeConversations(
  Iterable<AdminSupportConversation> current,
  Iterable<AdminSupportConversation> incoming,
) {
  final byId = <String, AdminSupportConversation>{};
  for (final conversation in current.followedBy(incoming)) {
    byId[conversation.id] = conversation;
  }
  return _sortConversations(byId.values);
}
