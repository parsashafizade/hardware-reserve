import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_localizations.dart';
import '../../support/application/support_providers.dart';

class AdminShell extends ConsumerWidget {
  const AdminShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final realtime = ref.watch(supportRealtimeServiceProvider);
    // Keep the one account-scoped support connection alive throughout the
    // Admin workspace. REST reads remain authoritative if startup fails.
    unawaited(realtime.start().catchError((Object _) {}));

    final location = GoRouterState.of(context).uri.path;
    final destinations = _destinations(context);
    final selectedIndex = _selectedIndex(location, destinations);

    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: (index) => context.go(destinations[index].path),
        destinations: [
          for (final destination in destinations)
            NavigationDestination(
              icon: Icon(destination.icon),
              selectedIcon: Icon(destination.selectedIcon),
              label: destination.label,
            ),
        ],
      ),
    );
  }

  int _selectedIndex(String location, List<_AdminDestination> destinations) {
    final exact = destinations.indexWhere((item) => item.path == location);
    if (exact >= 0) return exact;

    final nested = destinations.indexWhere(
      (item) => item.path != '/admin' && location.startsWith('${item.path}/'),
    );
    return nested >= 0 ? nested : 0;
  }

  List<_AdminDestination> _destinations(BuildContext context) => [
    _AdminDestination(
      path: '/admin',
      label: context.l10n.tr('admin.nav.overview'),
      icon: Icons.dashboard_outlined,
      selectedIcon: Icons.dashboard_rounded,
    ),
    _AdminDestination(
      path: '/admin/servers',
      label: context.l10n.tr('admin.nav.servers'),
      icon: Icons.dns_outlined,
      selectedIcon: Icons.dns_rounded,
    ),
    _AdminDestination(
      path: '/admin/reservations',
      label: context.l10n.tr('admin.nav.reservations'),
      icon: Icons.receipt_long_outlined,
      selectedIcon: Icons.receipt_long_rounded,
    ),
    _AdminDestination(
      path: '/admin/users',
      label: context.l10n.tr('admin.nav.users'),
      icon: Icons.group_outlined,
      selectedIcon: Icons.group_rounded,
    ),
    _AdminDestination(
      path: '/admin/support',
      label: context.l10n.tr('admin.nav.support'),
      icon: Icons.support_agent_outlined,
      selectedIcon: Icons.support_agent_rounded,
    ),
  ];
}

class _AdminDestination {
  const _AdminDestination({
    required this.path,
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  final String path;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}
