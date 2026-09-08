import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/admin_operations_models.dart';
import '../data/admin_operations_repository.dart';

class AdminReservationsState {
  const AdminReservationsState({
    this.items = const <AdminOrderModel>[],
    this.query = '',
    this.status = AdminReservationFilter.all,
    this.assignmentStatus = AdminAssignmentFilter.all,
    this.page = 1,
    this.pageSize = AdminReservationsController.pageSize,
    this.totalCount = 0,
    this.isLoading = false,
    this.isRefreshing = false,
    this.error,
  });

  final List<AdminOrderModel> items;
  final String query;
  final AdminReservationFilter status;
  final AdminAssignmentFilter assignmentStatus;
  final int page;
  final int pageSize;
  final int totalCount;
  final bool isLoading;
  final bool isRefreshing;
  final Object? error;

  bool get hasPrevious => page > 1;
  bool get hasNext => page * pageSize < totalCount;
}

class AdminReservationsController
    extends StateNotifier<AdminReservationsState> {
  AdminReservationsController(this._repository)
    : super(const AdminReservationsState());

  static const int pageSize = 20;

  final AdminOperationsRepository _repository;
  int _generation = 0;

  Future<void> load() => _load(page: state.page);
  Future<void> refresh() => _load(page: state.page);

  Future<void> applyFilters({
    required String query,
    required AdminReservationFilter status,
    required AdminAssignmentFilter assignmentStatus,
  }) {
    return _load(
      query: query.trim(),
      status: status,
      assignmentStatus: assignmentStatus,
      page: 1,
    );
  }

  Future<void> clearFilters() {
    return _load(
      query: '',
      status: AdminReservationFilter.all,
      assignmentStatus: AdminAssignmentFilter.all,
      page: 1,
    );
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

  Future<void> _load({
    String? query,
    AdminReservationFilter? status,
    AdminAssignmentFilter? assignmentStatus,
    required int page,
  }) async {
    final generation = ++_generation;
    final nextQuery = query ?? state.query;
    final nextStatus = status ?? state.status;
    final nextAssignmentStatus = assignmentStatus ?? state.assignmentStatus;
    final hasData = state.items.isNotEmpty;
    state = AdminReservationsState(
      items: state.items,
      query: nextQuery,
      status: nextStatus,
      assignmentStatus: nextAssignmentStatus,
      page: page,
      pageSize: pageSize,
      totalCount: state.totalCount,
      isLoading: !hasData,
      isRefreshing: hasData,
    );

    try {
      final result = await _repository.getReservations(
        query: nextQuery,
        status: nextStatus,
        assignmentStatus: nextAssignmentStatus,
        page: page,
        pageSize: pageSize,
      );
      if (!mounted || generation != _generation) return;
      state = AdminReservationsState(
        items: result.items,
        query: nextQuery,
        status: nextStatus,
        assignmentStatus: nextAssignmentStatus,
        page: result.page,
        pageSize: result.pageSize,
        totalCount: result.totalCount,
      );
    } on Object catch (error) {
      if (!mounted || generation != _generation) return;
      state = AdminReservationsState(
        items: state.items,
        query: nextQuery,
        status: nextStatus,
        assignmentStatus: nextAssignmentStatus,
        page: page,
        pageSize: pageSize,
        totalCount: state.totalCount,
        error: error,
      );
    }
  }
}
