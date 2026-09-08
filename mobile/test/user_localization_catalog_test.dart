import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hardware_reserve/core/localization/app_localizations.dart';

void main() {
  test('literal shared and User localization keys resolve in both locales', () {
    final sourceDirectory = Directory('lib');
    final keyPattern = RegExp(r"l10n\.tr\(\s*'([^']+)'");
    final requiredKeys = <String>{};

    for (final file
        in sourceDirectory.listSync(recursive: true).whereType<File>()) {
      if (!file.path.endsWith('.dart') ||
          file.path.contains(
            '${Platform.pathSeparator}features${Platform.pathSeparator}admin${Platform.pathSeparator}',
          )) {
        continue;
      }
      for (final match in keyPattern.allMatches(file.readAsStringSync())) {
        final key = match.group(1)!;
        if (!key.contains(r'$')) requiredKeys.add(key);
      }
    }

    for (final locale in const <Locale>[
      Locale('fa', 'IR'),
      Locale('en', 'US'),
    ]) {
      final localizations = AppLocalizations(locale);
      final available = AppLocalizations.translationKeysFor(locale);
      expect(
        available.containsAll(requiredKeys),
        isTrue,
        reason:
            '${locale.languageCode} is missing: ${requiredKeys.difference(available)}',
      );
      for (final key in requiredKeys) {
        expect(localizations.tr(key), isNot(key), reason: '$key is unresolved');
      }
    }
  });
}
