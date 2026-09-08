import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/admin_operations_models.dart';
import '../data/admin_operations_repository.dart';

class AdminDashboardState {
  const AdminDashboardState({
    this.stats,
    this.isLoading = false,
    this.isRefreshing = false,
    this.error,
  });

  final AdminDashboardStatsModel? stats;
  final bool isLoading;
  final bool isRefreshing;
  final Object? error;
}

class AdminDashboardController extends StateNotifier<AdminDashboardState> {
  AdminDashboardController(this._repository)
    : super(const AdminDashboardState());

  final AdminOperationsRepository _repository;
  int _generation = 0;

  Future<void> load() => _load();
  Future<void> refresh() => _load();

  Future<void> _load() async {
    final generation = ++_generation;
    final hasData = state.stats != null;
    state = AdminDashboardState(
      stats: state.stats,
      isLoading: !hasData,
      isRefreshing: hasData,
    );
    try {
      final stats = await _repository.getDashboardStats();
      if (!mounted || generation != _generation) return;
      state = AdminDashboardState(stats: stats);
    } on Object catch (error) {
      if (!mounted || generation != _generation) return;
      state = AdminDashboardState(stats: state.stats, error: error);
    }
  }
}
