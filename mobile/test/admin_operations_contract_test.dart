import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hardware_reserve/core/localization/app_localizations.dart';
import 'package:hardware_reserve/features/admin/data/admin_page_model.dart';
import 'package:hardware_reserve/features/admin/operations/application/admin_operations_providers.dart';
import 'package:hardware_reserve/features/admin/operations/application/admin_reservation_detail_controller.dart';
import 'package:hardware_reserve/features/admin/operations/application/admin_reservations_controller.dart';
import 'package:hardware_reserve/features/admin/operations/data/admin_operations_models.dart';
import 'package:hardware_reserve/features/admin/operations/data/admin_operations_repository.dart';
import 'package:hardware_reserve/features/admin/operations/presentation/admin_reservations_screen.dart';

void main() {
  test('Admin page and order preserve the exact shared API contract', () {
    final page = AdminPageModel<AdminOrderModel>.fromJson(<String, Object?>{
      'items': <Object?>[_orderJson(credentialsAssigned: true)],
      'page': 2,
      'pageSize': 20,
      'totalCount': 44,
    }, parseItem: AdminOrderModel.fromJson);

    expect(page.page, 2);
    expect(page.hasPrevious, isTrue);
    expect(page.hasNext, isTrue);
    expect(page.totalPages, 3);
    expect(page.items.single.credentialsAssigned, isTrue);
    expect(page.items.single.assignmentStatus, AdminAssignmentStatus.assigned);
    expect(page.items.single.hasReadableCredentials, isFalse);
    expect(page.items.single.startTime.isUtc, isTrue);
    expect(page.items.single.isPaid, isTrue);
  });

  test('Admin pages fail closed when provisioning state is absent', () {
    final order = _orderJson(credentialsAssigned: false)
      ..remove('credentialsAssigned');

    expect(() => AdminOrderModel.fromJson(order), throwsFormatException);
  });

  test('Admin pages reject contradictory assignment state', () {
    final order = _orderJson(credentialsAssigned: true)
      ..['assignmentStatus'] = 'NotAssigned';

    expect(() => AdminOrderModel.fromJson(order), throwsFormatException);
  });

  test(
    'credentials request uses backend field names without normalization',
    () {
      const request = AssignCredentialsRequestModel(
        reservationId: 42,
        assignedIp: ' 203.0.113.10 ',
        assignedUsername: ' root ',
        assignedPassword: ' pass with spaces ',
      );

      expect(request.toJson(), <String, Object>{
        'reservationId': 42,
        'assignedIp': '203.0.113.10',
        'assignedUsername': 'root',
        'assignedPassword': ' pass with spaces ',
      });
    },
  );

  test('detail controller blocks duplicate credential submissions', () async {
    final repository = _CredentialRepository();
    final controller = AdminReservationDetailController(
      reservationId: 17,
      repository: repository,
    );
    addTearDown(controller.dispose);
    await controller.load();

    final first = controller.assignCredentials(
      assignedIp: '203.0.113.10',
      assignedUsername: 'operator',
      assignedPassword: 'secret',
    );
    final second = await controller.assignCredentials(
      assignedIp: '203.0.113.11',
      assignedUsername: 'duplicate',
      assignedPassword: 'duplicate',
    );

    expect(second, isFalse);
    expect(repository.assignCalls, 1);
    repository.pending.complete();
    expect(await first, isTrue);
    expect(controller.state.order?.credentialsAssigned, isTrue);
    expect(controller.state.order?.assignedIp, '203.0.113.10');
    expect(repository.lastRequest?.assignedPassword, 'secret');
  });

  test('assignment filter is forwarded alongside reservation status', () async {
    final repository = _ReservationFilterRepository();
    final controller = AdminReservationsController(repository);
    addTearDown(controller.dispose);

    await controller.applyFilters(
      query: ' user@example.com ',
      status: AdminReservationFilter.upcoming,
      assignmentStatus: AdminAssignmentFilter.needsAssignment,
    );

    expect(repository.query, 'user@example.com');
    expect(repository.status, AdminReservationFilter.upcoming);
    expect(repository.assignmentStatus, AdminAssignmentFilter.needsAssignment);
    expect(
      controller.state.assignmentStatus,
      AdminAssignmentFilter.needsAssignment,
    );
  });

  testWidgets('clear filters resets the visible assignment selection', (
    tester,
  ) async {
    final repository = _ReservationFilterRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          adminOperationsRepositoryProvider.overrideWithValue(repository),
        ],
        child: const MaterialApp(
          locale: Locale('en', 'US'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: AdminReservationsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byType(DropdownButtonFormField<AdminAssignmentFilter>),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Needs assignment').last);
    await tester.pumpAndSettle();
    expect(find.text('Needs assignment'), findsOneWidget);

    await tester.tap(find.byTooltip('Clear filters'));
    await tester.pumpAndSettle();

    expect(find.text('Needs assignment'), findsNothing);
    expect(repository.assignmentStatus, AdminAssignmentFilter.all);
  });
}

Map<String, Object?> _orderJson({required bool credentialsAssigned}) =>
    <String, Object?>{
      'reservationId': 17,
      'userId': 5,
      'userFullName': 'کاربر تست',
      'userEmail': 'user@example.com',
      'serverId': 9,
      'cpu': 'EPYC 9654',
      'gpu': 'RTX 4090',
      'ram': '128 GB',
      'storage': '2 TB NVMe',
      'os': 'Ubuntu 24.04',
      'startTime': '2026-08-22T08:00:00+03:30',
      'endTime': '2026-08-23T08:00:00Z',
      'totalPrice': 2500000,
      'reservationStatus': 'Paid',
      'paymentStatus': 'Completed',
      'credentialsAssigned': credentialsAssigned,
      'assignmentStatus': credentialsAssigned ? 'Assigned' : 'NotAssigned',
    };

class _CredentialRepository extends AdminOperationsRepository {
  _CredentialRepository() : super(Dio());

  final Completer<void> pending = Completer<void>();
  int assignCalls = 0;
  AssignCredentialsRequestModel? lastRequest;
  bool assigned = false;

  @override
  Future<AdminOrderModel> getReservation(int reservationId) async {
    return AdminOrderModel.fromJson(_orderJson(credentialsAssigned: assigned));
  }

  @override
  Future<AdminOrderModel> assignCredentials(
    AssignCredentialsRequestModel request,
  ) async {
    assignCalls++;
    lastRequest = request;
    await pending.future;
    assigned = true;
    return AdminOrderModel.fromJson(
      _orderJson(credentialsAssigned: true)..addAll(<String, Object?>{
        'assignedIp': request.assignedIp.trim(),
        'assignedUsername': request.assignedUsername.trim(),
        'assignedPassword': request.assignedPassword,
      }),
    );
  }
}

class _ReservationFilterRepository extends AdminOperationsRepository {
  _ReservationFilterRepository() : super(Dio());

  String? query;
  AdminReservationFilter? status;
  AdminAssignmentFilter? assignmentStatus;

  @override
  Future<AdminPageModel<AdminOrderModel>> getReservations({
    String? query,
    AdminReservationFilter status = AdminReservationFilter.all,
    AdminAssignmentFilter assignmentStatus = AdminAssignmentFilter.all,
    int page = 1,
    int pageSize = 20,
  }) async {
    this.query = query;
    this.status = status;
    this.assignmentStatus = assignmentStatus;
    return AdminPageModel<AdminOrderModel>(
      items: const <AdminOrderModel>[],
      page: page,
      pageSize: pageSize,
      totalCount: 0,
    );
  }
}
