import 'package:flutter/widgets.dart';

import '../../../../core/localization/app_localizations.dart';

/// Uses the app-wide localization table. The inline values are a defensive
/// fallback for a future partial catalog deployment, not a separate locale store.
String adminSupportText(
  BuildContext context,
  String key, {
  required String fa,
  required String en,
  Map<String, Object?> values = const <String, Object?>{},
}) {
  final localized = context.l10n.tr(key, values);
  if (localized != key) return localized;
  var fallback = context.l10n.isPersian ? fa : en;
  for (final entry in values.entries) {
    fallback = fallback.replaceAll(
      '{${entry.key}}',
      entry.value?.toString() ?? '',
    );
  }
  return fallback;
}
