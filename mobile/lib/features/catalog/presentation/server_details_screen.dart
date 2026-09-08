import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/network/api_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/app_format.dart';
import '../../../core/widgets/async_states.dart';
import '../../auth/application/auth_controller.dart';
import '../data/server_model.dart';

class ServerDetailsScreen extends ConsumerStatefulWidget {
  const ServerDetailsScreen({super.key, required this.serverId});

  final int serverId;

  @override
  ConsumerState<ServerDetailsScreen> createState() =>
      _ServerDetailsScreenState();
}

class _ServerDetailsScreenState extends ConsumerState<ServerDetailsScreen> {
  late Future<ServerModel> _serverFuture;

  @override
  void initState() {
    super.initState();
    _serverFuture = _load();
  }

  Future<ServerModel> _load() {
    return ref.read(serverRepositoryProvider).getServerById(widget.serverId);
  }

  Future<void> _reload() async {
    final future = _load();
    setState(() => _serverFuture = future);
    await future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.tr('server.specs'))),
      body: FutureBuilder<ServerModel>(
        future: _serverFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const AppLoadingView();
          }
          if (snapshot.hasError) {
            return AppErrorView(error: snapshot.error!, onRetry: _reload);
          }
          final server = snapshot.requireData;
          return _ServerDetailsBody(server: server, onRefresh: _reload);
        },
      ),
    );
  }
}

class _ServerDetailsBody extends ConsumerWidget {
  const _ServerDetailsBody({required this.server, required this.onRefresh});

  final ServerModel server;
  final RefreshCallback onRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final available =
        server.isActive && server.operationalStatus == 'Available';
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 120),
            sliver: SliverList.list(
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 760),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _ServerHero(server: server, available: available),
                        const SizedBox(height: 16),
                        _SpecsCard(server: server),
                        const SizedBox(height: 16),
                        _PricingCard(server: server),
                        if (server.workloadCapabilities.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          _CapabilityCard(server: server),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ServerHero extends StatelessWidget {
  const _ServerHero({required this.server, required this.available});

  final ServerModel server;
  final bool available;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.inverseRaised, AppColors.inverse],
        ),
        borderRadius: BorderRadius.circular(AppTheme.panelRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Hero(
                tag: 'server-${server.id}',
                child: Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: AppColors.brand600,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(Icons.dns_rounded, color: Colors.white),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      server.gpu.trim().toLowerCase() == 'none'
                          ? server.cpu
                          : server.gpu,
                      textDirection: TextDirection.ltr,
                      textAlign: TextAlign.start,
                      style: Theme.of(
                        context,
                      ).textTheme.titleLarge?.copyWith(color: Colors.white),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      server.performanceTier,
                      textDirection: TextDirection.ltr,
                      style: const TextStyle(color: Color(0xFFB8C6D6)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
            decoration: BoxDecoration(
              color: (available ? AppColors.success : AppColors.warning)
                  .withValues(alpha: .16),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: (available ? AppColors.success : AppColors.warning)
                    .withValues(alpha: .5),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  available
                      ? Icons.check_circle_rounded
                      : Icons.schedule_rounded,
                  size: 16,
                  color: available ? AppColors.success : AppColors.warning,
                ),
                const SizedBox(width: 7),
                Text(
                  context.l10n.tr(
                    available ? 'servers.available' : 'servers.unavailable',
                  ),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SpecsCard extends StatelessWidget {
  const _SpecsCard({required this.server});

  final ServerModel server;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.tr('server.specs'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            _SpecRow(
              icon: Icons.memory_rounded,
              label: 'CPU',
              value: server.cpu,
            ),
            _SpecRow(
              icon: Icons.developer_board_rounded,
              label: 'GPU',
              value: server.gpu,
            ),
            _SpecRow(
              icon: Icons.sd_storage_rounded,
              label: 'RAM',
              value: server.ram,
            ),
            _SpecRow(
              icon: Icons.storage_rounded,
              label: 'Storage',
              value: server.storage,
            ),
            _SpecRow(
              icon: Icons.computer_rounded,
              label: 'OS',
              value: server.os,
              last: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _SpecRow extends StatelessWidget {
  const _SpecRow({
    required this.icon,
    required this.label,
    required this.value,
    this.last = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.muted,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: AppColors.brand700),
            ),
            const SizedBox(width: 11),
            SizedBox(
              width: 62,
              child: Text(
                label,
                textDirection: TextDirection.ltr,
                style: const TextStyle(color: AppColors.ink500, fontSize: 12),
              ),
            ),
            Expanded(
              child: Text(
                value,
                textDirection: TextDirection.ltr,
                textAlign: TextAlign.end,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        if (!last) const Divider(height: 24),
      ],
    );
  }
}

class _PricingCard extends ConsumerWidget {
  const _PricingCard({required this.server});

  final ServerModel server;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final available =
        server.isActive && server.operationalStatus == 'Available';
    final restoring = auth.phase == AuthPhase.restoring;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: _Price(
                    label: context.l10n.tr('servers.hourly'),
                    value: server.pricePerHour,
                  ),
                ),
                Container(width: 1, height: 48, color: AppColors.border),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsetsDirectional.only(start: 16),
                    child: _Price(
                      label: context.l10n.tr('servers.daily'),
                      value: server.pricePerDay,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (available)
              FilledButton.icon(
                onPressed: restoring
                    ? null
                    : () {
                        final reservePath = '/servers/${server.id}/reserve';
                        if (auth.isAuthenticated) {
                          context.push(reservePath);
                        } else {
                          context.push(
                            '/login?returnTo=${Uri.encodeComponent(reservePath)}',
                          );
                        }
                      },
                icon: restoring
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.event_available_rounded),
                label: Text(
                  auth.isAuthenticated
                      ? context.l10n.tr('action.reserve')
                      : context.l10n.tr('action.login'),
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: .08),
                  borderRadius: BorderRadius.circular(AppTheme.controlRadius),
                ),
                child: Text(
                  context.l10n.tr('servers.unavailable'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.warning,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Price extends StatelessWidget {
  const _Price({required this.label, required this.value});

  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppColors.ink500)),
        const SizedBox(height: 5),
        Text(
          AppFormat.money(context, value, context.l10n.tr('common.toman')),
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(color: AppColors.brand700),
        ),
      ],
    );
  }
}

class _CapabilityCard extends StatelessWidget {
  const _CapabilityCard({required this.server});

  final ServerModel server;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.tr('server.bestSuitedFor'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 13),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final capability in server.workloadCapabilities)
                  Chip(
                    avatar: Icon(
                      capability.suitabilityLevel >= 3
                          ? Icons.bolt_rounded
                          : Icons.check_rounded,
                      size: 16,
                      color: AppColors.brand700,
                    ),
                    label: Text(
                      capability.workloadType,
                      textDirection: TextDirection.ltr,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
