import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hardware_reserve/app/role_navigation.dart';
import 'package:hardware_reserve/core/localization/app_localizations.dart';
import 'package:hardware_reserve/features/admin/data/admin_page_model.dart';
import 'package:hardware_reserve/features/admin/operations/application/admin_operations_providers.dart';
import 'package:hardware_reserve/features/admin/operations/application/admin_users_controller.dart';
import 'package:hardware_reserve/features/admin/operations/data/admin_operations_models.dart';
import 'package:hardware_reserve/features/admin/operations/data/admin_operations_repository.dart';
import 'package:hardware_reserve/features/admin/operations/presentation/admin_dashboard_screen.dart';
import 'package:hardware_reserve/features/auth/data/auth_models.dart';

void main() {
  const admin = AuthenticatedUser(
    id: 1,
    fullName: 'Admin',
    email: 'admin@test.local',
    role: 'Admin',
  );
  const user = AuthenticatedUser(
    id: 2,
    fullName: 'User',
    email: 'user@test.local',
    role: 'User',
  );

  test('role-aware startup sends Admins to the Admin experience', () {
    expect(authenticatedLandingPath(admin), '/admin');
    expect(
      authenticatedLandingPath(admin, requestedPath: '/reservations'),
      '/admin',
    );
    expect(
      authenticatedLandingPath(admin, requestedPath: '/admin/support'),
      '/admin/support',
    );
    expect(authenticatedLandingPath(user), '/');
    expect(
      authenticatedLandingPath(user, requestedPath: '/services'),
      '/services',
    );
    expect(authenticatedLandingPath(user, requestedPath: '/admin'), '/');
  });

  test('Admin creation request excludes confirmation and preserves password',
      () {
    const request = CreateAdminRequestModel(
      fullName: ' Second Admin ',
      email: ' SECOND@TEST.LOCAL ',
      password: ' password with spaces ',
    );
    expect(request.toJson(), <String, Object>{
      'fullName': 'Second Admin',
      'email': 'SECOND@TEST.LOCAL',
      'password': ' password with spaces ',
    });
    expect(request.toJson().containsKey('confirmPassword'), isFalse);
  });

  test('Admin creation controller refreshes the authoritative user list',
      () async {
    final repository = _Phase2Repository(_stats());
    final controller = AdminUsersController(repository);
    addTearDown(controller.dispose);

    final created = await controller.createAdmin(
      const CreateAdminRequestModel(
        fullName: 'Second Admin',
        email: 'second@test.local',
        password: 'Password-123',
      ),
    );

    expect(created.isAdmin, isTrue);
    expect(repository.createCalls, 1);
    expect(controller.state.items.single.email, 'second@test.local');
    expect(controller.state.query, isEmpty);
  });

  testWidgets('dashboard action badges show positive counts and hide zeros', (
    tester,
  ) async {
    await _pumpDashboard(tester, _stats(assignments: 3, support: 2));
    final positiveBadges = tester
        .widgetList<Badge>(find.byType(Badge))
        .where((badge) => badge.isLabelVisible)
        .toList();
    expect(positiveBadges, hasLength(2));
    expect(
      positiveBadges.map((badge) => (badge.label! as Text).data).toSet(),
      <String?>{'3', '2'},
    );

    await _pumpDashboard(tester, _stats(), key: const ValueKey('zero'));
    final zeroBadges = tester
        .widgetList<Badge>(find.byType(Badge))
        .where((badge) => badge.isLabelVisible)
        .toList();
    expect(zeroBadges, isEmpty);
  });
}

Future<void> _pumpDashboard(
  WidgetTester tester,
  AdminDashboardStatsModel stats, {
  Key? key,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      key: key,
      overrides: [
        adminOperationsRepositoryProvider.overrideWithValue(
          _Phase2Repository(stats),
        ),
      ],
      child: MaterialApp(
        locale: const Locale('en', 'US'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: AdminDashboardScreen(
          onOpenServers: () {},
          onOpenReservations: () {},
          onOpenUsers: () {},
          onOpenSupport: () {},
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

AdminDashboardStatsModel _stats({int assignments = 0, int support = 0}) =>
    AdminDashboardStatsModel(
      totalUsers: 4,
      totalServers: 2,
      totalPurchases: 1,
      activeReservations: 0,
      upcomingReservations: 0,
      startingSoonReservations: 0,
      endingSoonReservations: 0,
      pendingPayments: 0,
      unavailableServers: 0,
      maintenanceServers: 0,
      waitingSupportConversations: 0,
      pendingAssignmentReservations: assignments,
      supportAttentionConversations: support,
      recentAuditEvents: const <AdminAuditEventModel>[],
    );

class _Phase2Repository extends AdminOperationsRepository {
  _Phase2Repository(this.stats) : super(Dio());

  final AdminDashboardStatsModel stats;
  int createCalls = 0;
  AdminUserModel? created;

  @override
  Future<AdminDashboardStatsModel> getDashboardStats() async => stats;

  @override
  Future<AdminUserModel> createAdmin(CreateAdminRequestModel request) async {
    createCalls++;
    created = AdminUserModel(
      id: 10,
      fullName: request.fullName.trim(),
      email: request.email.trim(),
      role: 'Admin',
      createdAt: DateTime.utc(2026, 8, 23),
      isEmailVerified: true,
    );
    return created!;
  }

  @override
  Future<AdminPageModel<AdminUserModel>> searchUsers({
    String? query,
    int page = 1,
    int pageSize = 20,
  }) async =>
      AdminPageModel<AdminUserModel>(
        items: created == null
            ? const <AdminUserModel>[]
            : <AdminUserModel>[created!],
        page: page,
        pageSize: pageSize,
        totalCount: created == null ? 0 : 1,
      );
}
