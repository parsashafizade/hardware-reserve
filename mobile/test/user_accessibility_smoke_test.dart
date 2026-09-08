import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hardware_reserve/app/hardware_reserve_app.dart';
import 'package:hardware_reserve/core/localization/locale_controller.dart';
import 'package:hardware_reserve/core/network/api_providers.dart';
import 'package:hardware_reserve/core/storage/secure_session_store.dart';
import 'package:hardware_reserve/features/auth/data/auth_models.dart';
import 'package:hardware_reserve/features/catalog/data/server_model.dart';
import 'package:hardware_reserve/features/catalog/data/server_repository.dart';
import 'package:hardware_reserve/features/home/data/dashboard_models.dart';
import 'package:hardware_reserve/features/home/data/dashboard_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('authenticated Persian shell supports large mobile text', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 700);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(() {
      tester.view.reset();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });

    SharedPreferences.setMockInitialValues(<String, Object>{});
    final preferences = await SharedPreferences.getInstance();
    final now = DateTime.now().toUtc();
    final store = _MemorySessionStore(
      AuthResponse(
        accessToken: 'access',
        accessTokenExpiresAt: now.add(const Duration(hours: 1)),
        refreshToken: 'refresh',
        refreshTokenExpiresAt: now.add(const Duration(days: 14)),
        user: const AuthenticatedUser(
          id: 4,
          fullName: 'کاربر آزمایشی',
          email: 'user@example.com',
          role: 'User',
        ),
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          sharedPreferencesProvider.overrideWithValue(preferences),
          secureSessionStoreProvider.overrideWithValue(store),
          serverRepositoryProvider.overrideWithValue(_EmptyRepository()),
          dashboardRepositoryProvider.overrideWithValue(
            _EmptyDashboardRepository(),
          ),
        ],
        child: const HardwareReserveApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _MemorySessionStore extends SecureSessionStore {
  _MemorySessionStore(this.session);

  AuthResponse? session;

  @override
  Future<AuthResponse?> read() async => session;

  @override
  Future<void> write(AuthResponse value) async => session = value;

  @override
  Future<void> clear() async => session = null;
}

class _EmptyRepository extends ServerRepository {
  _EmptyRepository() : super(Dio());

  @override
  Future<List<ServerModel>> getServers({
    ServerFilters filters = const ServerFilters(),
  }) async => const <ServerModel>[];
}

class _EmptyDashboardRepository extends DashboardRepository {
  _EmptyDashboardRepository() : super(Dio());

  @override
  Future<DashboardSummaryModel> getSummary() async => DashboardSummaryModel(
    serverTimeUtc: DateTime.utc(2026, 8, 22),
    primaryState: 'DISCOVERY',
    primaryReservation: null,
    metrics: const DashboardMetricsModel(
      totalReservations: 0,
      pendingPayment: 0,
      active: 0,
      upcoming: 0,
      completed: 0,
    ),
  );
}
