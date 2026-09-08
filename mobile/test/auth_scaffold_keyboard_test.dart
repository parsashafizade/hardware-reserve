import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hardware_reserve/core/localization/app_localizations.dart';
import 'package:hardware_reserve/features/auth/presentation/auth_scaffold.dart';

void main() {
  testWidgets(
    'auth form reclaims mobile hero space while keyboard is visible',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 560);
      tester.view.viewInsets = const FakeViewPadding(bottom: 240);
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        const MaterialApp(
          locale: Locale('fa', 'IR'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: <LocalizationsDelegate<Object>>[
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: AuthScaffold(
            title: 'ورود',
            subtitle: 'حساب کاربری',
            child: TextField(),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(Image), findsNothing);
      expect(find.byType(TextField), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
