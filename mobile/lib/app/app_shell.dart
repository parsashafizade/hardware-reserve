import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/localization/app_localizations.dart';
import '../core/localization/locale_controller.dart';
import '../core/network/api_providers.dart';
import '../core/widgets/app_brand.dart';
import '../core/widgets/async_states.dart';
import '../features/auth/application/auth_controller.dart';

class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    if (auth.phase == AuthPhase.restoring) {
      return const Scaffold(body: SafeArea(child: AppLoadingView()));
    }

    final authenticated = auth.isAuthenticated;
    final isAdmin = auth.session?.user.isAdmin ?? false;
    final location = GoRouterState.of(context).uri.path;
    final destinations = authenticated
        ? isAdmin
            ? _adminDestinations(context)
            : _authenticatedDestinations(context)
        : _guestDestinations(context);
    final selected = _selectedIndex(location, destinations);

    return Scaffold(
      body: location == '/'
          ? Column(
              children: [
                SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 8, 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: AppBrand(
                            compact: MediaQuery.sizeOf(context).width < 380,
                          ),
                        ),
                        if (!authenticated)
                          IconButton(
                            tooltip: context.l10n.tr('profile.language'),
                            onPressed: () => ref
                                .read(localeControllerProvider.notifier)
                                .toggle(),
                            icon: const Icon(Icons.language_rounded),
                          ),
                        if (authenticated) ...[
                          if (isAdmin)
                            IconButton(
                              tooltip: context.l10n.tr('admin.entry.title'),
                              onPressed: () => context.push('/admin'),
                              icon: const Icon(
                                Icons.admin_panel_settings_outlined,
                              ),
                            ),
                          IconButton(
                            tooltip: context.l10n.tr('home.myActivity'),
                            onPressed: () => context.push('/activity'),
                            icon: const Icon(Icons.notifications_outlined),
                          ),
                          IconButton(
                            tooltip: context.l10n.tr('nav.support'),
                            onPressed: () => context.push('/support'),
                            icon: const Icon(Icons.support_agent_rounded),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                Expanded(child: child),
              ],
            )
          : child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: selected,
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

  int _selectedIndex(String location, List<_Destination> destinations) {
    final exact = destinations.indexWhere((item) => item.path == location);
    if (exact >= 0) return exact;
    final nested = destinations.indexWhere(
      (item) => item.path != '/' && location.startsWith('${item.path}/'),
    );
    return nested >= 0 ? nested : 0;
  }

  List<_Destination> _guestDestinations(BuildContext context) => [
    _Destination(
      path: '/',
      label: context.l10n.tr('nav.home'),
      icon: Icons.home_outlined,
      selectedIcon: Icons.home_rounded,
    ),
    _Destination(
      path: '/servers',
      label: context.l10n.tr('nav.servers'),
      icon: Icons.dns_outlined,
      selectedIcon: Icons.dns_rounded,
    ),
    _Destination(
      path: '/login',
      label: context.l10n.tr('action.login'),
      icon: Icons.person_outline_rounded,
      selectedIcon: Icons.person_rounded,
    ),
  ];

  List<_Destination> _authenticatedDestinations(BuildContext context) => [
    _Destination(
      path: '/',
      label: context.l10n.tr('nav.home'),
      icon: Icons.home_outlined,
      selectedIcon: Icons.home_rounded,
    ),
    _Destination(
      path: '/servers',
      label: context.l10n.tr('nav.servers'),
      icon: Icons.dns_outlined,
      selectedIcon: Icons.dns_rounded,
    ),
    _Destination(
      path: '/reservations',
      label: context.l10n.tr('nav.reservations'),
      icon: Icons.event_note_outlined,
      selectedIcon: Icons.event_note_rounded,
    ),
    _Destination(
      path: '/services',
      label: context.l10n.tr('nav.services'),
      icon: Icons.cloud_outlined,
      selectedIcon: Icons.cloud_rounded,
    ),
    _Destination(
      path: '/profile',
      label: context.l10n.tr('nav.profile'),
      icon: Icons.person_outline_rounded,
      selectedIcon: Icons.person_rounded,
    ),
  ];

  List<_Destination> _adminDestinations(BuildContext context) => [
    _Destination(
      path: '/admin',
      label: context.l10n.tr('admin.nav.overview'),
      icon: Icons.dashboard_outlined,
      selectedIcon: Icons.dashboard_rounded,
    ),
    _Destination(
      path: '/servers',
      label: context.l10n.tr('nav.servers'),
      icon: Icons.dns_outlined,
      selectedIcon: Icons.dns_rounded,
    ),
    _Destination(
      path: '/profile',
      label: context.l10n.tr('nav.profile'),
      icon: Icons.person_outline_rounded,
      selectedIcon: Icons.person_rounded,
    ),
  ];
}

class _Destination {
  const _Destination({
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
