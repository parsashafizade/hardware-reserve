import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_providers.dart';
import '../data/admin_operations_repository.dart';
import 'admin_dashboard_controller.dart';
import 'admin_reservation_detail_controller.dart';
import 'admin_reservations_controller.dart';
import 'admin_user_overview_controller.dart';
import 'admin_users_controller.dart';

final adminOperationsRepositoryProvider = Provider<AdminOperationsRepository>(
  (ref) => AdminOperationsRepository(ref.watch(authenticatedDioProvider)),
);

final adminDashboardControllerProvider =
    StateNotifierProvider.autoDispose<
      AdminDashboardController,
      AdminDashboardState
    >((ref) {
      final controller = AdminDashboardController(
        ref.watch(adminOperationsRepositoryProvider),
      );
      unawaited(controller.load());
      return controller;
    });

final adminReservationsControllerProvider =
    StateNotifierProvider.autoDispose<
      AdminReservationsController,
      AdminReservationsState
    >((ref) {
      final controller = AdminReservationsController(
        ref.watch(adminOperationsRepositoryProvider),
      );
      unawaited(controller.load());
      return controller;
    });

final adminReservationDetailControllerProvider = StateNotifierProvider
    .autoDispose
    .family<AdminReservationDetailController, AdminReservationDetailState, int>(
      (ref, reservationId) {
        final controller = AdminReservationDetailController(
          reservationId: reservationId,
          repository: ref.watch(adminOperationsRepositoryProvider),
        );
        unawaited(controller.load());
        return controller;
      },
    );

final adminUsersControllerProvider =
    StateNotifierProvider.autoDispose<AdminUsersController, AdminUsersState>((
      ref,
    ) {
      final controller = AdminUsersController(
        ref.watch(adminOperationsRepositoryProvider),
      );
      unawaited(controller.load());
      return controller;
    });

final adminUserOverviewControllerProvider = StateNotifierProvider.autoDispose
    .family<AdminUserOverviewController, AdminUserOverviewState, int>((
      ref,
      userId,
    ) {
      final controller = AdminUserOverviewController(
        userId: userId,
        repository: ref.watch(adminOperationsRepositoryProvider),
      );
      unawaited(controller.load());
      return controller;
    });
