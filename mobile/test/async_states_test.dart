import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hardware_reserve/core/localization/app_localizations.dart';
import 'package:hardware_reserve/core/network/api_failure.dart';
import 'package:hardware_reserve/core/widgets/async_states.dart';

void main() {
  testWidgets('compact Persian offline state fits its 170px host', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 500);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('fa', 'IR'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Scaffold(
          body: Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: 320,
              height: 170,
              child: AppErrorView(
                compact: true,
                error: const ApiFailure(
                  kind: ApiFailureKind.offline,
                  message: 'offline',
                ),
                onRetry: _noop,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('تلاش دوباره'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

void _noop() {}
