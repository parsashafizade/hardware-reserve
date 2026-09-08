import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/admin_operations_models.dart';
import '../data/admin_operations_repository.dart';

class AdminUsersState {
  const AdminUsersState({
    this.items = const <AdminUserModel>[],
    this.query = '',
    this.page = 1,
    this.pageSize = AdminUsersController.pageSize,
    this.totalCount = 0,
    this.isLoading = false,
    this.isRefreshing = false,
    this.error,
  });

  final List<AdminUserModel> items;
  final String query;
  final int page;
  final int pageSize;
  final int totalCount;
  final bool isLoading;
  final bool isRefreshing;
  final Object? error;

  bool get hasPrevious => page > 1;
  bool get hasNext => page * pageSize < totalCount;
}

class AdminUsersController extends StateNotifier<AdminUsersState> {
  AdminUsersController(this._repository) : super(const AdminUsersState());

  static const int pageSize = 20;

  final AdminOperationsRepository _repository;
  int _generation = 0;

  Future<void> load() => _load(page: state.page);
  Future<void> refresh() => _load(page: state.page);
  Future<void> search(String query) => _load(query: query.trim(), page: 1);
  Future<void> clearSearch() => _load(query: '', page: 1);

  Future<AdminUserModel> createAdmin(CreateAdminRequestModel request) async {
    final created = await _repository.createAdmin(request);
    await _load(query: '', page: 1);
    return created;
  }

  Future<void> nextPage() {
    if (!state.hasNext || state.isLoading || state.isRefreshing) {
      return Future<void>.value();
    }
    return _load(page: state.page + 1);
  }

  Future<void> previousPage() {
    if (!state.hasPrevious || state.isLoading || state.isRefreshing) {
      return Future<void>.value();
    }
    return _load(page: state.page - 1);
  }

  Future<void> _load({String? query, required int page}) async {
    final generation = ++_generation;
    final nextQuery = query ?? state.query;
    final hasData = state.items.isNotEmpty;
    state = AdminUsersState(
      items: state.items,
      query: nextQuery,
      page: page,
      pageSize: pageSize,
      totalCount: state.totalCount,
      isLoading: !hasData,
      isRefreshing: hasData,
    );

    try {
      final result = await _repository.searchUsers(
        query: nextQuery,
        page: page,
        pageSize: pageSize,
      );
      if (!mounted || generation != _generation) return;
      state = AdminUsersState(
        items: result.items,
        query: nextQuery,
        page: result.page,
        pageSize: result.pageSize,
        totalCount: result.totalCount,
      );
    } on Object catch (error) {
      if (!mounted || generation != _generation) return;
      state = AdminUsersState(
        items: state.items,
        query: nextQuery,
        page: page,
        pageSize: pageSize,
        totalCount: state.totalCount,
        error: error,
      );
    }
  }
}
