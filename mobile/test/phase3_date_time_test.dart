import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hardware_reserve/core/utils/app_format.dart';
import 'package:hardware_reserve/core/widgets/refresh_on_resume.dart';

void main() {
  test('Persian presentation uses Jalali and English remains Gregorian', () {
    final instant = DateTime(2026, 3, 21, 12, 30);

    expect(
      AppFormat.dateTimeForLocale(instant, persian: true),
      '۱ فروردین ۱۴۰۵، ۱۲:۳۰',
    );
    final english = AppFormat.dateTimeForLocale(instant, persian: false);
    expect(english, contains('Mar 21, 2026'));
    expect(english, isNot(contains('1405')));
  });

  test('Jalali leap day and year boundary are correct', () {
    expect(
      AppFormat.shortDateForLocale(DateTime(2025, 3, 20), persian: true),
      '۳۰ اسفند',
    );
    expect(
      AppFormat.shortDateForLocale(DateTime(2025, 3, 21), persian: true),
      '۱ فروردین',
    );
    expect(
      AppFormat.dateTimeForLocale(DateTime(2025, 12, 31), persian: false),
      contains('2025'),
    );
    expect(
      AppFormat.dateTimeForLocale(DateTime(2026, 1, 1), persian: false),
      contains('2026'),
    );
  });

  testWidgets('time-sensitive views refresh when the app resumes', (
    tester,
  ) async {
    var refreshes = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: RefreshOnResume(
          onResume: () => refreshes++,
          child: const Text('time-sensitive view'),
        ),
      ),
    );

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    expect(refreshes, 1);
  });
}
