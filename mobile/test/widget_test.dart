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
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'first launch is Persian, RTL, responsive, and can switch locale',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 700);
      addTearDown(tester.view.reset);

      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(preferences),
            secureSessionStoreProvider.overrideWithValue(_MemorySessionStore()),
            serverRepositoryProvider.overrideWithValue(
              _EmptyServerRepository(),
            ),
          ],
          child: const HardwareReserveApp(),
        ),
      );
      await tester.pump();
      await tester.pump();

      const persianTitle = 'سخت‌افزار حرفه‌ای را ساده و مطمئن رزرو کنید';
      expect(find.text(persianTitle), findsOneWidget);
      expect(
        Directionality.of(tester.element(find.text(persianTitle))),
        TextDirection.rtl,
      );
      expect(tester.takeException(), isNull);

      await tester.tap(find.byIcon(Icons.language_rounded));
      await tester.pumpAndSettle();

      expect(
        find.text('Reserve professional hardware with confidence'),
        findsOneWidget,
      );
      expect(preferences.getString('hardware_reserve.locale'), 'en');
      expect(tester.takeException(), isNull);
    },
  );
}

class _MemorySessionStore extends SecureSessionStore {
  AuthResponse? session;

  @override
  Future<AuthResponse?> read() async => session;

  @override
  Future<void> write(AuthResponse value) async => session = value;

  @override
  Future<void> clear() async => session = null;
}

class _EmptyServerRepository extends ServerRepository {
  _EmptyServerRepository() : super(Dio());

  @override
  Future<List<ServerModel>> getServers({
    ServerFilters filters = const ServerFilters(),
  }) async => const <ServerModel>[];
}
