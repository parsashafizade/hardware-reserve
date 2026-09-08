import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hardware_reserve/core/localization/app_localizations.dart';
import 'package:hardware_reserve/core/network/api_providers.dart';
import 'package:hardware_reserve/features/catalog/data/server_model.dart';
import 'package:hardware_reserve/features/catalog/data/server_repository.dart';
import 'package:hardware_reserve/features/catalog/presentation/servers_screen.dart';

void main() {
  testWidgets('catalog search follows first strong text in Persian mode', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          serverRepositoryProvider.overrideWithValue(_EmptyRepository()),
        ],
        child: const MaterialApp(
          locale: Locale('fa', 'IR'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: <LocalizationsDelegate<Object>>[
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: ServersScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final search = find.byType(TextField);
    expect(tester.widget<TextField>(search).textDirection, TextDirection.rtl);

    await tester.enterText(search, 'RTX 4090');
    await tester.pump();
    expect(tester.widget<TextField>(search).textDirection, TextDirection.ltr);

    await tester.enterText(search, 'سرور RTX 4090');
    await tester.pump();
    expect(tester.widget<TextField>(search).textDirection, TextDirection.rtl);
    expect(tester.takeException(), isNull);
  });
}

class _EmptyRepository extends ServerRepository {
  _EmptyRepository() : super(Dio());

  @override
  Future<List<ServerModel>> getServers({
    ServerFilters filters = const ServerFilters(),
  }) async => const <ServerModel>[];
}
