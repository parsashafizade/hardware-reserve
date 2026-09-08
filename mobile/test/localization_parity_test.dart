import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hardware_reserve/core/localization/app_localizations.dart';

void main() {
  test('Persian and English expose the same translation keys', () {
    final persian = AppLocalizations.translationKeysFor(
      const Locale('fa', 'IR'),
    );
    final english = AppLocalizations.translationKeysFor(
      const Locale('en', 'US'),
    );

    expect(persian, equals(english));
  });

  test('every literal Admin localization key exists in the shared catalog', () {
    final adminDirectory = Directory('lib/features/admin');
    expect(adminDirectory.existsSync(), isTrue);

    final literalKeys = <String>{};
    final keyPattern = RegExp(r'admin\.[A-Za-z0-9_.]+');
    for (final file
        in adminDirectory.listSync(recursive: true).whereType<File>()) {
      if (!file.path.endsWith('.dart')) continue;
      for (final match in keyPattern.allMatches(file.readAsStringSync())) {
        final key = match.group(0)!;
        if (!key.endsWith('.')) literalKeys.add(key);
      }
    }

    const dynamicKeys = <String>{
      'admin.reservations.filter.all',
      'admin.reservations.filter.pendingPayment',
      'admin.reservations.filter.active',
      'admin.reservations.filter.upcoming',
      'admin.reservations.filter.completed',
      'admin.reservations.filter.cancelled',
      'admin.reservations.assignment.all',
      'admin.reservations.assignment.needsAssignment',
      'admin.reservations.assignment.assigned',
      'admin.status.reservation.PendingPayment',
      'admin.status.reservation.Paid',
      'admin.status.reservation.Cancelled',
      'admin.status.payment.Unpaid',
      'admin.status.payment.Pending',
      'admin.status.payment.Completed',
      'admin.status.payment.Failed',
      'admin.status.payment.Refunded',
      'admin.audit.actions.MaintenanceCreated',
      'admin.audit.actions.MaintenanceRemoved',
      'admin.audit.actions.ManualNotificationSent',
      'admin.audit.actions.BroadcastNotificationSent',
      'admin.audit.actions.ReservationCancelled',
      'admin.audit.actions.CredentialsAssigned',
      'admin.audit.actions.ServerCreated',
      'admin.audit.actions.ServerConfigurationChanged',
      'admin.audit.actions.ServerDisabled',
      'admin.servers.status.available',
      'admin.servers.status.temporarilyUnavailable',
      'admin.servers.status.maintenance',
      'admin.servers.status.disabled',
      'admin.servers.tier.entry',
      'admin.servers.tier.standard',
      'admin.servers.tier.high',
      'admin.servers.tier.extreme',
      'admin.servers.workload.modelTraining',
      'admin.servers.workload.inference',
      'admin.servers.workload.rendering',
      'admin.servers.workload.developmentCompilation',
      'admin.servers.workload.dataProcessing',
      'admin.servers.workload.webBackendHosting',
      'admin.servers.workload.generalCompute',
    };

    final requiredKeys = literalKeys.union(dynamicKeys);
    for (final locale in AppLocalizations.supportedLocales) {
      final available = AppLocalizations.translationKeysFor(locale);
      expect(
        available.containsAll(requiredKeys),
        isTrue,
        reason:
            '${locale.languageCode} is missing: ${requiredKeys.difference(available)}',
      );
      final localizations = AppLocalizations(locale);
      for (final key in requiredKeys) {
        expect(localizations.tr(key), isNot(key), reason: '$key is unresolved');
      }
    }
  });
}
