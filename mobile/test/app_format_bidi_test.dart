import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hardware_reserve/core/localization/app_localizations.dart';
import 'package:hardware_reserve/core/utils/app_format.dart';

void main() {
  testWidgets('money keeps amount and unit isolated in either locale', (
    tester,
  ) async {
    String? formatted;

    Future<void> render(Locale locale, String unit) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: locale,
          supportedLocales: const <Locale>[
            Locale('fa', 'IR'),
            Locale('en', 'US'),
          ],
          localizationsDelegates: const <LocalizationsDelegate<Object>>[
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: Builder(
            builder: (context) {
              formatted = AppFormat.money(context, 12345, unit);
              return Text(formatted!);
            },
          ),
        ),
      );
    }

    await render(const Locale('fa', 'IR'), 'تومان');
    expect(formatted, startsWith('\u2068'));
    expect(formatted, endsWith('\u2069'));
    expect(formatted, contains('\u00a0تومان'));
    expect(formatted, isNot(contains(' تومان')));

    await render(const Locale('en', 'US'), 'Toman');
    expect(formatted, startsWith('\u2068'));
    expect(formatted, endsWith('\u2069'));
    expect(formatted, contains('\u00a0Toman'));
    expect(formatted, isNot(contains(' Toman')));
    expect(tester.takeException(), isNull);
  });
}
