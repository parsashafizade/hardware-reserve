import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/localization/app_localizations.dart';
import '../core/network/api_providers.dart';
import '../core/widgets/async_states.dart';
import '../features/account/presentation/profile_screen.dart';
import '../features/admin/operations/admin_operations.dart';
import '../features/admin/presentation/admin_shell.dart';
import '../features/admin/servers/presentation/admin_server_detail_screen.dart';
import '../features/admin/servers/presentation/admin_server_form_screen.dart';
import '../features/admin/servers/presentation/admin_servers_screen.dart';
import '../features/admin/support/presentation/admin_support_conversation_screen.dart';
import '../features/admin/support/presentation/admin_support_inbox_screen.dart';
import '../features/auth/presentation/forgot_password_screen.dart';
import '../features/auth/application/auth_controller.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/register_screen.dart';
import '../features/auth/presentation/verify_email_screen.dart';
import '../features/catalog/presentation/server_details_screen.dart';
import '../features/catalog/presentation/servers_screen.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/notifications/presentation/activity_screen.dart';
import '../features/reservations/presentation/checkout_screen.dart';
import '../features/reservations/presentation/my_reservations_screen.dart';
import '../features/reservations/presentation/my_services_screen.dart';
import '../features/reservations/presentation/reservation_cockpit_screen.dart';
import '../features/reservations/presentation/reservation_screen.dart';
import '../features/support/presentation/support_conversation_screen.dart';
import '../features/support/presentation/support_screen.dart';
import 'app_shell.dart';
import 'protected_screen.dart';
import 'role_navigation.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const _RoleAwareHomeScreen(),
          ),
          GoRoute(
            path: '/servers',
            builder: (context, state) => const ServersScreen(),
          ),
          GoRoute(
            path: '/reservations',
            builder: (context, state) => const ProtectedScreen(
              returnPath: '/reservations',
              userOnly: true,
              child: MyReservationsScreen(),
            ),
          ),
          GoRoute(
            path: '/services',
            builder: (context, state) => const ProtectedScreen(
              returnPath: '/services',
              userOnly: true,
              child: MyServicesScreen(),
            ),
          ),
          GoRoute(
            path: '/profile',
            builder: (context, state) => const ProtectedScreen(
              returnPath: '/profile',
              child: ProfileScreen(),
            ),
          ),
          GoRoute(
            path: '/login',
            builder: (context, state) => _RoleAwareGuestScreen(
              requestedPath: state.uri.queryParameters['returnTo'],
              child: LoginScreen(
                returnPath: state.uri.queryParameters['returnTo'],
              ),
            ),
          ),
        ],
      ),
      ShellRoute(
        builder: (context, state, child) => ProtectedScreen(
          returnPath: state.uri.path,
          adminOnly: true,
          child: AdminShell(child: child),
        ),
        routes: [
          GoRoute(
            path: '/admin',
            builder: (context, state) => AdminDashboardScreen(
              onOpenServers: () => context.go('/admin/servers'),
              onOpenReservations: () => context.go('/admin/reservations'),
              onOpenUsers: () => context.go('/admin/users'),
              onOpenSupport: () => context.go('/admin/support'),
              onOpenProfile: () => context.push('/profile'),
            ),
          ),
          GoRoute(
            path: '/admin/servers',
            builder: (context, state) => const AdminServersScreen(),
          ),
          GoRoute(
            path: '/admin/servers/new',
            builder: (context, state) => const AdminServerFormScreen(),
          ),
          GoRoute(
            path: '/admin/servers/:id/edit',
            builder: (context, state) => _integerRoute(
              state,
              (id) => AdminServerFormScreen(serverId: id),
            ),
          ),
          GoRoute(
            path: '/admin/servers/:id',
            builder: (context, state) => _integerRoute(
              state,
              (id) => AdminServerDetailScreen(serverId: id),
            ),
          ),
          GoRoute(
            path: '/admin/reservations',
            builder: (context, state) => AdminReservationsScreen(
              onOpenReservation: (reservationId) async {
                await context.push<void>('/admin/reservations/$reservationId');
              },
            ),
          ),
          GoRoute(
            path: '/admin/reservations/:id',
            builder: (context, state) => _integerRoute(
              state,
              (id) => AdminReservationDetailScreen(
                reservationId: id,
                onOpenUser: (userId) async {
                  await context.push<void>('/admin/users/$userId');
                },
              ),
            ),
          ),
          GoRoute(
            path: '/admin/users',
            builder: (context, state) => AdminUsersScreen(
              onOpenUser: (userId) async {
                await context.push<void>('/admin/users/$userId');
              },
            ),
          ),
          GoRoute(
            path: '/admin/users/:id',
            builder: (context, state) => _integerRoute(
              state,
              (id) => AdminUserOverviewScreen(
                userId: id,
                onOpenReservation: (reservationId) async {
                  await context.push<void>(
                    '/admin/reservations/$reservationId',
                  );
                },
              ),
            ),
          ),
          GoRoute(
            path: '/admin/support',
            builder: (context, state) => AdminSupportInboxScreen(
              onOpenConversation: (conversationId) async {
                await context.push<void>('/admin/support/$conversationId');
              },
            ),
          ),
          GoRoute(
            path: '/admin/support/:id',
            builder: (context, state) => AdminSupportConversationScreen(
              conversationId: state.pathParameters['id']!,
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const _RoleAwareGuestScreen(
          child: RegisterScreen(),
        ),
      ),
      GoRoute(
        path: '/verify-email',
        builder: (context, state) =>
            VerifyEmailScreen(email: state.uri.queryParameters['email'] ?? ''),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/servers/:id/reserve',
        builder: (context, state) => _integerRoute(
          state,
          (id) => ProtectedScreen(
            returnPath: state.uri.path,
            userOnly: true,
            child: ReservationScreen(serverId: id),
          ),
        ),
      ),
      GoRoute(
        path: '/servers/:id',
        builder: (context, state) =>
            _integerRoute(state, (id) => ServerDetailsScreen(serverId: id)),
      ),
      GoRoute(
        path: '/reservations/:id/checkout',
        builder: (context, state) => _integerRoute(
          state,
          (id) => ProtectedScreen(
            returnPath: state.uri.path,
            userOnly: true,
            child: CheckoutScreen(reservationId: id),
          ),
        ),
      ),
      GoRoute(
        path: '/reservations/:id',
        builder: (context, state) => _integerRoute(
          state,
          (id) => ProtectedScreen(
            returnPath: state.uri.path,
            userOnly: true,
            child: ReservationCockpitScreen(reservationId: id),
          ),
        ),
      ),
      GoRoute(
        path: '/support',
        builder: (context, state) => const ProtectedScreen(
          returnPath: '/support',
          userOnly: true,
          child: SupportScreen(),
        ),
      ),
      GoRoute(
        path: '/support/:id',
        builder: (context, state) => ProtectedScreen(
          returnPath: state.uri.path,
          userOnly: true,
          child: SupportConversationScreen(
            conversationId: state.pathParameters['id']!,
          ),
        ),
      ),
      GoRoute(
        path: '/activity',
        builder: (context, state) => ProtectedScreen(
          returnPath: '/activity',
          child: ActivityScreen(
            onOpenReservation: (reservationId) =>
                context.push('/reservations/$reservationId'),
            onOpenSupportConversation: (conversationId) =>
                context.push('/support/$conversationId'),
          ),
        ),
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});

class _RoleAwareHomeScreen extends ConsumerWidget {
  const _RoleAwareHomeScreen();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    if (auth.phase == AuthPhase.restoring) {
      return const Scaffold(body: SafeArea(child: AppLoadingView()));
    }
    if (auth.session?.user.isAdmin ?? false) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.go('/admin');
      });
      return const Scaffold(body: SafeArea(child: AppLoadingView()));
    }
    return const HomeScreen();
  }
}

class _RoleAwareGuestScreen extends ConsumerWidget {
  const _RoleAwareGuestScreen({required this.child, this.requestedPath});

  final Widget child;
  final String? requestedPath;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    if (auth.phase == AuthPhase.restoring) {
      return const Scaffold(body: SafeArea(child: AppLoadingView()));
    }
    if (auth.isAuthenticated) {
      final target = authenticatedLandingPath(
        auth.session!.user,
        requestedPath: requestedPath,
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.go(target);
      });
      return const Scaffold(body: SafeArea(child: AppLoadingView()));
    }
    return child;
  }
}

Widget _integerRoute(GoRouterState state, Widget Function(int id) builder) {
  final id = int.tryParse(state.pathParameters['id'] ?? '');
  return id != null && id > 0 ? builder(id) : const _InvalidRouteScreen();
}

class _InvalidRouteScreen extends StatelessWidget {
  const _InvalidRouteScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.link_off_rounded, size: 44),
                const SizedBox(height: 16),
                Text(
                  context.l10n.tr('error.generic'),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                OutlinedButton(
                  onPressed: () => context.go('/'),
                  child: Text(context.l10n.tr('action.backHome')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
