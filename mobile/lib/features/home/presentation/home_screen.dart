import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/network/api_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/app_format.dart';
import '../../../core/widgets/async_states.dart';
import '../../../core/widgets/refresh_on_resume.dart';
import '../../catalog/data/server_model.dart';
import '../data/dashboard_models.dart';

final _homeServersProvider = FutureProvider.autoDispose<List<ServerModel>>(
  (ref) => ref.watch(serverRepositoryProvider).getServers(),
);

final _dashboardProvider = FutureProvider.autoDispose<DashboardSummaryModel>(
  (ref) => ref.watch(dashboardRepositoryProvider).getSummary(),
);

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    Future<void> refresh() async {
        ref.invalidate(_homeServersProvider);
        if (auth.isAuthenticated) ref.invalidate(_dashboardProvider);
    }
    return RefreshOnResume(
      onResume: refresh,
      child: RefreshIndicator(
        onRefresh: refresh,
        child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
            sliver: SliverList.list(
              children: [
                auth.isAuthenticated
                    ? _AuthenticatedHero(ref: ref)
                    : const _GuestHero(),
                const SizedBox(height: 24),
                _ServerPreview(ref: ref),
                const SizedBox(height: 24),
                const _TrustStrip(),
              ],
            ),
          ),
        ],
        ),
      ),
    );
  }
}

class _GuestHero extends StatelessWidget {
  const _GuestHero();
  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 400),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.panelRadius),
        color: AppColors.inverse,
        image: const DecorationImage(
          image: AssetImage('assets/images/server-rack-blue.webp'),
          fit: BoxFit.cover,
          opacity: .30,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33081526),
            blurRadius: 28,
            offset: Offset(0, 16),
          ),
        ],
      ),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0x221767DC), Color(0xF2081526)],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(26),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(
                context.l10n.tr('home.eyebrow'),
                style: const TextStyle(
                  color: AppColors.brand300,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                context.l10n.tr('home.title'),
                style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  color: Colors.white,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                context.l10n.tr('home.body'),
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: const Color(0xFFD7E2EE)),
              ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  FilledButton.icon(
                    onPressed: () => context.go('/servers'),
                    icon: const Icon(Icons.dns_rounded),
                    label: Text(context.l10n.tr('home.explore')),
                  ),
                  OutlinedButton(
                    onPressed: () => context.push('/login'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white30),
                    ),
                    child: Text(context.l10n.tr('action.login')),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AuthenticatedHero extends StatelessWidget {
  const _AuthenticatedHero({required this.ref});
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(_dashboardProvider);
    return state.when(
      loading: () =>
          const Card(child: SizedBox(height: 300, child: AppLoadingView())),
      error: (error, _) => Card(
        child: SizedBox(
          height: 260,
          child: AppErrorView(
            error: error,
            onRetry: () => ref.invalidate(_dashboardProvider),
          ),
        ),
      ),
      data: (dashboard) {
        final reservation = dashboard.primaryReservation;
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.panelRadius),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.inverseRaised, AppColors.inverse],
            ),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.l10n.tr('home.myActivity'),
                style: const TextStyle(
                  color: AppColors.brand300,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                context.l10n.tr('home.state.${dashboard.primaryState}'),
                style: Theme.of(
                  context,
                ).textTheme.headlineMedium?.copyWith(color: Colors.white),
              ),
              if (reservation != null) ...[
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Directionality(
                        textDirection: TextDirection.ltr,
                        child: Text(
                          reservation.server.gpu == 'None'
                              ? reservation.server.cpu
                              : reservation.server.gpu,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${AppFormat.dateTime(context, reservation.startTime)} — ${AppFormat.dateTime(context, reservation.endTime)}',
                        style: const TextStyle(color: Color(0xFFB8C6D6)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => context.push(
                    reservation.status == 'PendingPayment'
                        ? '/reservations/${reservation.reservationId}/checkout'
                        : '/reservations/${reservation.reservationId}',
                  ),
                  child: Text(
                    reservation.status == 'PendingPayment'
                        ? context.l10n.tr('action.pay')
                        : context.l10n.tr('action.view'),
                  ),
                ),
              ] else ...[
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: () => context.go('/servers'),
                  child: Text(context.l10n.tr('home.explore')),
                ),
              ],
              const SizedBox(height: 20),
              Row(
                children: [
                  _Metric(
                    value: dashboard.metrics.totalReservations,
                    label: context.l10n.tr('nav.reservations'),
                  ),
                  _Metric(
                    value: dashboard.metrics.active,
                    label: context.l10n.tr('common.online'),
                  ),
                  _Metric(
                    value: dashboard.metrics.upcoming,
                    label: context.l10n.tr('home.reservation'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.value, required this.label});
  final int value;
  final String label;
  @override
  Widget build(BuildContext context) => Expanded(
    child: Padding(
      padding: const EdgeInsetsDirectional.only(end: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppFormat.number(context, value),
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(color: Colors.white),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Color(0xFF9FB0C3), fontSize: 11),
          ),
        ],
      ),
    ),
  );
}

class _ServerPreview extends StatelessWidget {
  const _ServerPreview({required this.ref});
  final WidgetRef ref;
  @override
  Widget build(BuildContext context) {
    final servers = ref.watch(_homeServersProvider);
    final largeText = MediaQuery.textScalerOf(context).scale(14) > 20;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (largeText)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                context.l10n.tr('servers.title'),
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton(
                  onPressed: () => context.go('/servers'),
                  child: Text(context.l10n.tr('action.view')),
                ),
              ),
            ],
          )
        else
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  context.l10n.tr('servers.title'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              TextButton(
                onPressed: () => context.go('/servers'),
                child: Text(context.l10n.tr('action.view')),
              ),
            ],
          ),
        const SizedBox(height: 10),
        servers.when(
          loading: () =>
              const SizedBox(height: 150, child: AppLoadingView(compact: true)),
          error: (error, _) => SizedBox(
            height: 170,
            child: AppErrorView(
              compact: true,
              error: error,
              onRetry: () => ref.invalidate(_homeServersProvider),
            ),
          ),
          data: (items) => SizedBox(
            height: 190,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: items.take(6).length,
              separatorBuilder: (_, index) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final server = items[index];
                return SizedBox(
                  width: 250,
                  child: Card(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(AppTheme.cardRadius),
                      onTap: () => context.push('/servers/${server.id}'),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.dns_rounded,
                              color: AppColors.brand600,
                            ),
                            const Spacer(),
                            Directionality(
                              textDirection: TextDirection.ltr,
                              child: Text(
                                server.gpu == 'None' ? server.cpu : server.gpu,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${server.ram} · ${server.storage}',
                              textDirection: TextDirection.ltr,
                              style: const TextStyle(color: AppColors.ink500),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              AppFormat.money(
                                context,
                                server.pricePerHour,
                                context.l10n.tr('common.toman'),
                              ),
                              style: const TextStyle(
                                color: AppColors.brand700,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _TrustStrip extends StatelessWidget {
  const _TrustStrip();
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          const Icon(Icons.verified_user_outlined, color: AppColors.success),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              context.l10n.tr('home.body'),
              style: const TextStyle(color: AppColors.ink600),
            ),
          ),
        ],
      ),
    ),
  );
}
