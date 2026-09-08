import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hardware_reserve/core/localization/app_localizations.dart';
import 'package:hardware_reserve/core/theme/app_theme.dart';
import 'package:hardware_reserve/features/admin/servers/application/admin_server_providers.dart';
import 'package:hardware_reserve/features/admin/servers/presentation/admin_servers_screen.dart';
import 'package:hardware_reserve/features/catalog/data/server_model.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Admin inventory fits a compact phone in Persian and English', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 700);
    addTearDown(tester.view.reset);

    Future<void> pumpLocale(Locale locale) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            adminServersProvider.overrideWith(
              (ref) async => const <ServerModel>[_server],
            ),
          ],
          child: MaterialApp(
            locale: locale,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            theme: AppTheme.light(locale),
            home: const AdminServersScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }

    await pumpLocale(const Locale('fa', 'IR'));
    expect(find.text('مدیریت سرورها'), findsOneWidget);
    expect(find.text('RTX 4090'), findsOneWidget);
    expect(
      Directionality.of(tester.element(find.text('مدیریت سرورها'))),
      TextDirection.rtl,
    );

    await pumpLocale(const Locale('en', 'US'));
    expect(find.text('Server management'), findsOneWidget);
    expect(find.text('RTX 4090'), findsOneWidget);
  });
}

const _server = ServerModel(
  id: 4090,
  cpu: 'AMD EPYC 9654',
  gpu: 'RTX 4090',
  ram: '128 GB',
  storage: '2 TB NVMe',
  os: 'Ubuntu 24.04 LTS',
  pricePerHour: 275000,
  pricePerDay: 5500000,
  isActive: true,
  operationalStatus: 'Available',
  finderEligible: true,
  cpuCapabilityLevel: 5,
  gpuCapabilityLevel: 5,
  performanceTier: 'Extreme',
  workloadCapabilities: <ServerWorkloadCapabilityModel>[
    ServerWorkloadCapabilityModel(
      workloadType: 'ModelTraining',
      suitabilityLevel: 5,
    ),
  ],
);
