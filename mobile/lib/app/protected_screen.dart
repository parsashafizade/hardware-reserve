import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/localization/app_localizations.dart';
import '../core/network/api_providers.dart';
import '../core/widgets/async_states.dart';
import '../features/auth/application/auth_controller.dart';

class ProtectedScreen extends ConsumerWidget {
  const ProtectedScreen({
    super.key,
    required this.returnPath,
    required this.child,
    this.adminOnly = false,
    this.userOnly = false,
  });

  final String returnPath;
  final Widget child;
  final bool adminOnly;
  final bool userOnly;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    if (auth.phase == AuthPhase.restoring) return const AppLoadingView();
    if (auth.isAuthenticated) {
      if (userOnly && auth.session!.user.isAdmin) {
        return const _AdminDestinationRedirect();
      }
      if (!adminOnly || auth.session!.user.isAdmin) return child;
      return const _AdminAccessDeniedScreen();
    }

    return Scaffold(
      appBar: AppBar(),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.lock_outline_rounded, size: 42),
                    const SizedBox(height: 16),
                    Text(
                      context.l10n.tr('auth.loginSubtitle'),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () => context.push(
                          '/login?returnTo=${Uri.encodeComponent(returnPath)}',
                        ),
                        child: Text(context.l10n.tr('action.login')),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AdminDestinationRedirect extends StatelessWidget {
  const _AdminDestinationRedirect();

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) context.go('/admin');
    });
    return const Scaffold(body: SafeArea(child: AppLoadingView()));
  }
}

class _AdminAccessDeniedScreen extends StatelessWidget {
  const _AdminAccessDeniedScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.admin_panel_settings_outlined, size: 42),
                    const SizedBox(height: 16),
                    Text(
                      context.l10n.tr('auth.adminRequiredTitle'),
                      style: Theme.of(context).textTheme.titleLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      context.l10n.tr('auth.adminRequired'),
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
        ),
      ),
    );
  }
}
