// Named public parameters intentionally initialize private implementation fields.
// ignore_for_file: prefer_initializing_formals

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/admin_operations_models.dart';
import '../data/admin_operations_repository.dart';

const Object _unset = Object();

class AdminReservationDetailState {
  const AdminReservationDetailState({
    this.order,
    this.isLoading = false,
    this.isRefreshing = false,
    this.isCancelling = false,
    this.isAssigningCredentials = false,
    this.error,
  });

  final AdminOrderModel? order;
  final bool isLoading;
  final bool isRefreshing;
  final bool isCancelling;
  final bool isAssigningCredentials;
  final Object? error;

  bool get isMutating => isCancelling || isAssigningCredentials;

  AdminReservationDetailState copyWith({
    Object? order = _unset,
    bool? isLoading,
    bool? isRefreshing,
    bool? isCancelling,
    bool? isAssigningCredentials,
    Object? error = _unset,
  }) {
    return AdminReservationDetailState(
      order: identical(order, _unset) ? this.order : order as AdminOrderModel?,
      isLoading: isLoading ?? this.isLoading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      isCancelling: isCancelling ?? this.isCancelling,
      isAssigningCredentials:
          isAssigningCredentials ?? this.isAssigningCredentials,
      error: identical(error, _unset) ? this.error : error,
    );
  }
}

class AdminReservationDetailController
    extends StateNotifier<AdminReservationDetailState> {
  AdminReservationDetailController({
    required int reservationId,
    required AdminOperationsRepository repository,
  }) : _reservationId = reservationId,
       _repository = repository,
       super(const AdminReservationDetailState());

  final int _reservationId;
  final AdminOperationsRepository _repository;
  int _loadGeneration = 0;

  Future<void> load() => _load();
  Future<void> refresh() => _load();

  Future<void> _load() async {
    final generation = ++_loadGeneration;
    final hasData = state.order != null;
    state = state.copyWith(
      isLoading: !hasData,
      isRefreshing: hasData,
      error: null,
    );
    try {
      final order = await _repository.getReservation(_reservationId);
      if (!mounted || generation != _loadGeneration) return;
      state = state.copyWith(
        order: order,
        isLoading: false,
        isRefreshing: false,
        error: null,
      );
    } on Object catch (error) {
      if (!mounted || generation != _loadGeneration) return;
      state = state.copyWith(
        isLoading: false,
        isRefreshing: false,
        error: error,
      );
    }
  }

  Future<AdminOrderModel?> cancelReservation() async {
    final order = state.order;
    if (order == null || state.isMutating) return null;
    state = state.copyWith(isCancelling: true, error: null);
    try {
      final updated = await _repository.cancelReservation(_reservationId);
      // Cancellation deliberately uses the secret-free list contract. Preserve
      // credentials already obtained from the protected detail request.
      final reconciled = updated.copyWith(
        assignedIp: order.assignedIp,
        assignedUsername: order.assignedUsername,
        assignedPassword: order.assignedPassword,
      );
      if (mounted) state = state.copyWith(order: reconciled);
      return reconciled;
    } on Object {
      // Cancellation can commit before a response is lost. Reconcile once and
      // never issue a second mutation automatically.
      try {
        final persisted = await _repository.getReservation(_reservationId);
        if (persisted.isCancelled) {
          if (mounted) state = state.copyWith(order: persisted);
          return persisted;
        }
      } on Object {
        // Preserve the original mutation error for the operator.
      }
      rethrow;
    } finally {
      if (mounted) state = state.copyWith(isCancelling: false);
    }
  }

  Future<bool> assignCredentials({
    required String assignedIp,
    required String assignedUsername,
    required String assignedPassword,
  }) async {
    final order = state.order;
    if (order == null || state.isMutating) return false;
    if (!order.isPaid) {
      throw StateError('Credentials require a paid reservation.');
    }

    final previouslyAssigned = order.credentialsAssigned;
    state = state.copyWith(isAssigningCredentials: true, error: null);
    try {
      final assigned = await _repository.assignCredentials(
        AssignCredentialsRequestModel(
          reservationId: _reservationId,
          assignedIp: assignedIp,
          assignedUsername: assignedUsername,
          assignedPassword: assignedPassword,
        ),
      );

      if (mounted) state = state.copyWith(order: assigned);
      return true;
    } on Object catch (error, stackTrace) {
      // If this was the first assignment, a false -> true persisted transition
      // safely resolves an ambiguous network result without resending secrets.
      if (!previouslyAssigned) {
        try {
          final persisted = await _repository.getReservation(_reservationId);
          if (persisted.credentialsAssigned) {
            if (mounted) state = state.copyWith(order: persisted);
            return true;
          }
        } on Object {
          // Preserve the original assignment error.
        }
      }
      Error.throwWithStackTrace(error, stackTrace);
    } finally {
      if (mounted) {
        state = state.copyWith(isAssigningCredentials: false);
      }
    }
  }
}
