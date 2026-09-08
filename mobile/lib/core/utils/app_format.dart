import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:shamsi_date/shamsi_date.dart';

class AppFormat {
  AppFormat._();

  static const _persianDigits = <String>[
    '۰',
    '۱',
    '۲',
    '۳',
    '۴',
    '۵',
    '۶',
    '۷',
    '۸',
    '۹',
  ];

  static bool isPersian(BuildContext context) =>
      Localizations.localeOf(context).languageCode == 'fa';

  static String digits(String value, {required bool persian}) {
    if (!persian) return value;
    var output = value;
    for (var i = 0; i < 10; i++) {
      output = output.replaceAll('$i', _persianDigits[i]);
    }
    return output;
  }

  static String number(
    BuildContext context,
    num value, {
    int decimalDigits = 0,
  }) {
    final formatted = NumberFormat.decimalPatternDigits(
      locale: isPersian(context) ? 'fa_IR' : 'en_US',
      decimalDigits: decimalDigits,
    ).format(value);
    return digits(formatted, persian: isPersian(context));
  }

  /// Keeps the amount and unit together and directionally isolated when they
  /// are embedded in Persian, English, or mixed technical text.
  static String money(BuildContext context, num value, String unit) =>
      '\u2068${number(context, value)}\u00a0$unit\u2069';

  static String dateTime(BuildContext context, DateTime instant) {
    return dateTimeForLocale(instant, persian: isPersian(context));
  }

  static String dateTimeForLocale(
    DateTime instant, {
    required bool persian,
  }) {
    final local = instant.toLocal();
    if (!persian) {
      return DateFormat.yMMMd('en_US').add_Hm().format(local);
    }
    final jalali = Jalali.fromDateTime(local);
    final formatter = jalali.formatter;
    final text = '${formatter.d} ${formatter.mN} ${formatter.y}، '
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    return digits(text, persian: true);
  }

  static String shortDate(BuildContext context, DateTime instant) {
    return shortDateForLocale(instant, persian: isPersian(context));
  }

  static String shortDateForLocale(
    DateTime instant, {
    required bool persian,
  }) {
    final local = instant.toLocal();
    if (!persian) return DateFormat.MMMd('en_US').format(local);
    final jalali = Jalali.fromDateTime(local);
    return digits(
      '${jalali.formatter.d} ${jalali.formatter.mN}',
      persian: true,
    );
  }
}
