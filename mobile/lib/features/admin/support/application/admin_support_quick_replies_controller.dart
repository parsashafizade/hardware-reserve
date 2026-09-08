import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_failure.dart';
import '../data/admin_support_models.dart';
import '../data/admin_support_repository.dart';

const Object _notSet = Object();

class AdminSupportQuickRepliesState {
  const AdminSupportQuickRepliesState({
    this.replies = const <AdminSupportQuickReply>[],
    this.isLoading = false,
    this.isSaving = false,
    this.deactivatingIds = const <String>{},
    this.error,
    this.actionError,
  });

  final List<AdminSupportQuickReply> replies;
  final bool isLoading;
  final bool isSaving;
  final Set<String> deactivatingIds;
  final Object? error;
  final Object? actionError;

  List<AdminSupportQuickReply> get activeReplies =>
      List<AdminSupportQuickReply>.unmodifiable(
        replies.where((reply) => reply.isActive),
      );

  AdminSupportQuickRepliesState copyWith({
    List<AdminSupportQuickReply>? replies,
    bool? isLoading,
    bool? isSaving,
    Set<String>? deactivatingIds,
    Object? error = _notSet,
    Object? actionError = _notSet,
  }) {
    return AdminSupportQuickRepliesState(
      replies: replies ?? this.replies,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      deactivatingIds: deactivatingIds ?? this.deactivatingIds,
      error: identical(error, _notSet) ? this.error : error,
      actionError: identical(actionError, _notSet)
          ? this.actionError
          : actionError,
    );
  }
}

class AdminSupportQuickRepliesController
    extends StateNotifier<AdminSupportQuickRepliesState> {
  AdminSupportQuickRepliesController(this._repository)
    : super(const AdminSupportQuickRepliesState());

  final AdminSupportRepository _repository;
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    await load();
  }

  Future<void> load() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final replies = await _repository.getQuickReplies(includeInactive: true);
      if (!mounted) return;
      state = state.copyWith(replies: _sortReplies(replies), isLoading: false);
    } on Object catch (error) {
      if (mounted) state = state.copyWith(isLoading: false, error: error);
    }
  }

  Future<AdminSupportQuickReply> create(
    UpsertAdminSupportQuickReplyRequest request,
  ) async {
    if (state.isSaving) {
      throw StateError('A quick reply is already being saved.');
    }
    _validate(request);
    state = state.copyWith(isSaving: true, actionError: null);

    late final Set<String> knownIds;
    try {
      // Establish an authoritative pre-mutation baseline. The local list can
      // be stale or still loading, and must not make an older duplicate look
      // like the result of this create attempt.
      final baseline = await _repository.getQuickReplies(includeInactive: true);
      knownIds = <String>{for (final reply in baseline) reply.id};
      if (mounted) state = state.copyWith(replies: _sortReplies(baseline));
    } on Object catch (error, stackTrace) {
      if (mounted) state = state.copyWith(isSaving: false, actionError: error);
      Error.throwWithStackTrace(error, stackTrace);
    }

    try {
      final created = await _repository.createQuickReply(request);
      if (mounted) {
        state = state.copyWith(
          replies: _mergeReply(state.replies, created),
          isSaving: false,
        );
      }
      return created;
    } on Object catch (error, stackTrace) {
      if (_isAmbiguousMutationFailure(error)) {
        final reconciled = await _reconcileCreate(request, knownIds);
        if (reconciled != null) return reconciled;
      }
      if (mounted) state = state.copyWith(isSaving: false, actionError: error);
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  Future<AdminSupportQuickReply?> _reconcileCreate(
    UpsertAdminSupportQuickReplyRequest request,
    Set<String> knownIds,
  ) async {
    try {
      final authoritative = await _repository.getQuickReplies(
        includeInactive: true,
      );
      final candidates = authoritative
          .where(
            (reply) => !knownIds.contains(reply.id) && request.matches(reply),
          )
          .toList(growable: false);

      if (mounted) {
        state = state.copyWith(
          replies: _sortReplies(authoritative),
          isSaving: false,
        );
      }
      return candidates.length == 1 ? candidates.single : null;
    } on Object {
      // Preserve the original mutation failure when reconciliation cannot
      // establish exactly one newly-created authoritative record.
      return null;
    }
  }

  Future<AdminSupportQuickReply> update(
    String quickReplyId,
    UpsertAdminSupportQuickReplyRequest request,
  ) async {
    if (state.isSaving) {
      throw StateError('A quick reply is already being saved.');
    }
    _validate(request);
    state = state.copyWith(isSaving: true, actionError: null);
    try {
      final updated = await _repository.updateQuickReply(quickReplyId, request);
      if (mounted) {
        state = state.copyWith(
          replies: _mergeReply(state.replies, updated),
          isSaving: false,
        );
      }
      return updated;
    } on Object catch (error) {
      if (mounted) state = state.copyWith(isSaving: false, actionError: error);
      rethrow;
    }
  }

  Future<void> deactivate(String quickReplyId) async {
    if (state.deactivatingIds.contains(quickReplyId)) return;
    state = state.copyWith(
      deactivatingIds: Set<String>.unmodifiable(<String>{
        ...state.deactivatingIds,
        quickReplyId,
      }),
      actionError: null,
    );
    try {
      await _repository.deactivateQuickReply(quickReplyId);
      if (mounted) {
        state = state.copyWith(
          replies: List<AdminSupportQuickReply>.unmodifiable(
            state.replies.map(
              (reply) => reply.id == quickReplyId
                  ? AdminSupportQuickReply(
                      id: reply.id,
                      title: reply.title,
                      content: reply.content,
                      category: reply.category,
                      isActive: false,
                      sortOrder: reply.sortOrder,
                      createdAt: reply.createdAt,
                      updatedAt: DateTime.now().toUtc(),
                    )
                  : reply,
            ),
          ),
        );
      }
    } on Object catch (error) {
      if (mounted) state = state.copyWith(actionError: error);
      rethrow;
    } finally {
      if (mounted) {
        final pending = <String>{...state.deactivatingIds}
          ..remove(quickReplyId);
        state = state.copyWith(
          deactivatingIds: Set<String>.unmodifiable(pending),
        );
      }
    }
  }

  void clearActionError() {
    if (state.actionError != null) {
      state = state.copyWith(actionError: null);
    }
  }

  static void _validate(UpsertAdminSupportQuickReplyRequest request) {
    final title = request.title.trim();
    final content = request.content.trim();
    final category = request.category?.trim();
    if (title.isEmpty || title.length > 120) {
      throw ArgumentError.value(request.title, 'title', '1-120 characters');
    }
    if (content.isEmpty || content.length > 2000) {
      throw ArgumentError.value(
        request.content,
        'content',
        '1-2000 characters',
      );
    }
    if (category != null && category.length > 80) {
      throw ArgumentError.value(
        request.category,
        'category',
        '0-80 characters',
      );
    }
    if (request.sortOrder < 0 || request.sortOrder > 10000) {
      throw RangeError.range(request.sortOrder, 0, 10000, 'sortOrder');
    }
  }
}

bool _isAmbiguousMutationFailure(Object error) {
  final failure = ApiFailure.from(error);
  return failure.kind == ApiFailureKind.offline ||
      failure.kind == ApiFailureKind.timeout ||
      failure.kind == ApiFailureKind.server;
}

List<AdminSupportQuickReply> _sortReplies(
  Iterable<AdminSupportQuickReply> replies,
) {
  final sorted = replies.toList()
    ..sort((left, right) {
      final byActive = (right.isActive ? 1 : 0).compareTo(
        left.isActive ? 1 : 0,
      );
      if (byActive != 0) return byActive;
      final byOrder = left.sortOrder.compareTo(right.sortOrder);
      return byOrder != 0 ? byOrder : left.title.compareTo(right.title);
    });
  return List<AdminSupportQuickReply>.unmodifiable(sorted);
}

List<AdminSupportQuickReply> _mergeReply(
  Iterable<AdminSupportQuickReply> replies,
  AdminSupportQuickReply updated,
) {
  final byId = <String, AdminSupportQuickReply>{
    for (final reply in replies) reply.id: reply,
    updated.id: updated,
  };
  return _sortReplies(byId.values);
}
