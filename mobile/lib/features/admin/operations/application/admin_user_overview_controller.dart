// Named public parameters intentionally initialize private implementation fields.
// ignore_for_file: prefer_initializing_formals

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/admin_operations_models.dart';
import '../data/admin_operations_repository.dart';

class AdminUserOverviewState {
  const AdminUserOverviewState({
    this.user,
    this.isLoading = false,
    this.isRefreshing = false,
    this.error,
  });

  final AdminUserOverviewModel? user;
  final bool isLoading;
  final bool isRefreshing;
  final Object? error;
}

class AdminUserOverviewController
    extends StateNotifier<AdminUserOverviewState> {
  AdminUserOverviewController({
    required int userId,
    required AdminOperationsRepository repository,
  }) : _userId = userId,
       _repository = repository,
       super(const AdminUserOverviewState());

  final int _userId;
  final AdminOperationsRepository _repository;
  int _generation = 0;

  Future<void> load() => _load();
  Future<void> refresh() => _load();

  Future<void> _load() async {
    final generation = ++_generation;
    final hasData = state.user != null;
    state = AdminUserOverviewState(
      user: state.user,
      isLoading: !hasData,
      isRefreshing: hasData,
    );
    try {
      final user = await _repository.getUserOverview(_userId);
      if (!mounted || generation != _generation) return;
      state = AdminUserOverviewState(user: user);
    } on Object catch (error) {
      if (!mounted || generation != _generation) return;
      state = AdminUserOverviewState(user: state.user, error: error);
    }
  }
}
