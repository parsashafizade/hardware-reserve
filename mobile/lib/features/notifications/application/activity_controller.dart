import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/notification_models.dart';
import '../data/notification_repository.dart';

const Object _notSet = Object();

class ActivityState {
  const ActivityState({
    this.notifications = const <UserNotificationModel>[],
    this.unreadCount = 0,
    this.nextCursor,
    this.hasMore = false,
    this.isLoading = false,
    this.isRefreshing = false,
    this.isLoadingMore = false,
    this.isMarkingAllRead = false,
    this.markingReadIds = const <String>{},
    this.error,
    this.paginationError,
    this.actionError,
  });

  final List<UserNotificationModel> notifications;
  final int unreadCount;
  final String? nextCursor;
  final bool hasMore;
  final bool isLoading;
  final bool isRefreshing;
  final bool isLoadingMore;
  final bool isMarkingAllRead;
  final Set<String> markingReadIds;
  final Object? error;
  final Object? paginationError;
  final Object? actionError;

  ActivityState copyWith({
    List<UserNotificationModel>? notifications,
    int? unreadCount,
    Object? nextCursor = _notSet,
    bool? hasMore,
    bool? isLoading,
    bool? isRefreshing,
    bool? isLoadingMore,
    bool? isMarkingAllRead,
    Set<String>? markingReadIds,
    Object? error = _notSet,
    Object? paginationError = _notSet,
    Object? actionError = _notSet,
  }) {
    return ActivityState(
      notifications: notifications ?? this.notifications,
      unreadCount: unreadCount ?? this.unreadCount,
      nextCursor: identical(nextCursor, _notSet)
          ? this.nextCursor
          : nextCursor as String?,
      hasMore: hasMore ?? this.hasMore,
      isLoading: isLoading ?? this.isLoading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      isMarkingAllRead: isMarkingAllRead ?? this.isMarkingAllRead,
      markingReadIds: markingReadIds ?? this.markingReadIds,
      error: identical(error, _notSet) ? this.error : error,
      paginationError: identical(paginationError, _notSet)
          ? this.paginationError
          : paginationError,
      actionError: identical(actionError, _notSet)
          ? this.actionError
          : actionError,
    );
  }
}

class ActivityController extends StateNotifier<ActivityState> {
  ActivityController(this._repository) : super(const ActivityState());

  static const int pageSize = 20;

  final NotificationRepository _repository;
  int _loadGeneration = 0;

  Future<void> load() => _loadFirstPage();

  Future<void> refresh() => _loadFirstPage();

  Future<void> _loadFirstPage() async {
    final generation = ++_loadGeneration;
    final hasExistingItems = state.notifications.isNotEmpty;
    state = state.copyWith(
      isLoading: !hasExistingItems,
      isRefreshing: hasExistingItems,
      isLoadingMore: false,
      error: null,
      paginationError: null,
    );

    try {
      final page = await _repository.getNotifications(pageSize: pageSize);
      if (!mounted || generation != _loadGeneration) {
        return;
      }

      final visibleUnreadCount = page.items
          .where((notification) => !notification.isRead)
          .length;
      var unreadCount = math.max(state.unreadCount, visibleUnreadCount);
      try {
        final unread = await _repository.getUnreadCount();
        unreadCount = unread.unreadCount;
      } on Object {
        // The activity page remains usable; a later refresh reconciles the badge.
      }

      if (!mounted || generation != _loadGeneration) {
        return;
      }
      state = state.copyWith(
        notifications: _mergeNotifications(const [], page.items),
        unreadCount: unreadCount,
        nextCursor: page.nextCursor,
        hasMore: page.hasMore,
        isLoading: false,
        isRefreshing: false,
      );
    } on Object catch (error) {
      if (!mounted || generation != _loadGeneration) {
        return;
      }
      state = state.copyWith(
        isLoading: false,
        isRefreshing: false,
        error: error,
      );
    }
  }

  Future<void> loadMore() async {
    final cursor = state.nextCursor;
    if (state.isLoading ||
        state.isRefreshing ||
        state.isLoadingMore ||
        !state.hasMore ||
        cursor == null) {
      return;
    }

    final generation = _loadGeneration;
    state = state.copyWith(isLoadingMore: true, paginationError: null);
    try {
      final page = await _repository.getNotifications(
        cursor: cursor,
        pageSize: pageSize,
      );
      if (!mounted || generation != _loadGeneration) {
        return;
      }
      state = state.copyWith(
        notifications: _mergeNotifications(state.notifications, page.items),
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

  Future<void> markRead(UserNotificationModel notification) async {
    if (notification.isRead || state.markingReadIds.contains(notification.id)) {
      return;
    }

    state = state.copyWith(
      markingReadIds: Set<String>.unmodifiable(<String>{
        ...state.markingReadIds,
        notification.id,
      }),
      actionError: null,
    );
    try {
      final updated = await _repository.markRead(notification.id);
      if (!mounted) {
        return;
      }
      state = state.copyWith(
        notifications: _replaceNotification(state.notifications, updated),
        unreadCount: math.max(0, state.unreadCount - 1),
      );
    } on Object catch (error) {
      if (mounted) {
        state = state.copyWith(actionError: error);
      }
    } finally {
      if (mounted) {
        final pending = <String>{...state.markingReadIds}
          ..remove(notification.id);
        state = state.copyWith(
          markingReadIds: Set<String>.unmodifiable(pending),
        );
      }
    }
  }

  Future<void> markAllRead() async {
    if (state.unreadCount == 0 || state.isMarkingAllRead) {
      return;
    }

    state = state.copyWith(isMarkingAllRead: true, actionError: null);
    try {
      final result = await _repository.markAllRead();
      if (!mounted) {
        return;
      }
      final readAt = DateTime.now().toUtc();
      state = state.copyWith(
        notifications: List<UserNotificationModel>.unmodifiable(
          state.notifications.map(
            (notification) => notification.isRead
                ? notification
                : notification.copyWith(readAt: readAt),
          ),
        ),
        unreadCount: result.unreadCount,
        isMarkingAllRead: false,
      );
    } on Object catch (error) {
      if (mounted) {
        state = state.copyWith(isMarkingAllRead: false, actionError: error);
      }
    }
  }

  void clearActionError() {
    if (state.actionError != null) {
      state = state.copyWith(actionError: null);
    }
  }
}

List<UserNotificationModel> _mergeNotifications(
  Iterable<UserNotificationModel> current,
  Iterable<UserNotificationModel> incoming,
) {
  final byId = <String, UserNotificationModel>{};
  for (final notification in current.followedBy(incoming)) {
    byId[notification.id] = notification;
  }
  final merged = byId.values.toList()
    ..sort((left, right) => right.createdAt.compareTo(left.createdAt));
  return List<UserNotificationModel>.unmodifiable(merged);
}

List<UserNotificationModel> _replaceNotification(
  List<UserNotificationModel> current,
  UserNotificationModel updated,
) {
  return List<UserNotificationModel>.unmodifiable(
    current.map(
      (notification) => notification.id == updated.id ? updated : notification,
    ),
  );
}
