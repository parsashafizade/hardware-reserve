import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/app_format.dart';
import '../../../../core/widgets/async_states.dart';
import '../../../../core/widgets/refresh_on_resume.dart';
import '../application/admin_operations_providers.dart';
import '../data/admin_operations_models.dart';
import 'admin_operations_widgets.dart';

typedef AdminDashboardDestination = FutureOr<void> Function();

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({
    super.key,
    this.onOpenServers,
    this.onOpenReservations,
    this.onOpenUsers,
    this.onOpenSupport,
    this.onOpenProfile,
  });

  final AdminDashboardDestination? onOpenServers;
  final AdminDashboardDestination? onOpenReservations;
  final AdminDashboardDestination? onOpenUsers;
  final AdminDashboardDestination? onOpenSupport;
  final AdminDashboardDestination? onOpenProfile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(adminDashboardControllerProvider);
    final controller = ref.read(adminDashboardControllerProvider.notifier);
    final stats = state.stats;

    return RefreshOnResume(
      onResume: controller.refresh,
      child: Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.tr('admin.dashboard.title')),
        actions: [
          if (onOpenProfile != null)
            IconButton(
              tooltip: context.l10n.tr('nav.profile'),
              onPressed: () => unawaited(Future.sync(onOpenProfile!)),
              icon: const Icon(Icons.account_circle_outlined),
            ),
          IconButton(
            tooltip: context.l10n.tr('action.refresh'),
            onPressed: state.isLoading || state.isRefreshing
                ? null
                : () => unawaited(controller.refresh()),
            icon: state.isRefreshing
                ? const SizedBox.square(
                    dimension: 19,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: state.isLoading && stats == null
          ? const AppLoadingView()
          : state.error != null && stats == null
          ? AppErrorView(error: state.error!, onRetry: controller.load)
          : RefreshIndicator(
              onRefresh: controller.refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 32),
                children: [
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 980),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            context.l10n.tr('admin.dashboard.description'),
                            style: const TextStyle(color: AppColors.ink600),
                          ),
                          if (state.error != null) ...[
                            const SizedBox(height: 12),
                            AdminInlineError(
                              error: state.error!,
                              onRetry: () => unawaited(controller.refresh()),
                            ),
                          ],
                          const SizedBox(height: 18),
                          _MetricsGrid(stats: stats!),
                          if (_hasDestination) ...[
                            const SizedBox(height: 24),
                            Text(
                              context.l10n.tr('admin.dashboard.operations'),
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 12),
                            _AdminActions(
                              stats: stats,
                              onOpenServers: onOpenServers,
                              onOpenReservations: onOpenReservations,
                              onOpenUsers: onOpenUsers,
                              onOpenSupport: onOpenSupport,
                            ),
                          ],
                          if (stats.recentAuditEvents.isNotEmpty) ...[
                            const SizedBox(height: 24),
                            Text(
                              context.l10n.tr('admin.dashboard.recentAudit'),
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 12),
                            Card(
                              child: Column(
                                children: [
                                  for (
                                    var index = 0;
                                    index < stats.recentAuditEvents.length;
                                    index++
                                  ) ...[
                                    _AuditRow(
                                      event: stats.recentAuditEvents[index],
                                    ),
                                    if (index <
                                        stats.recentAuditEvents.length - 1)
                                      const Divider(height: 1),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
      ),
    );
  }

  bool get _hasDestination =>
      onOpenServers != null ||
      onOpenReservations != null ||
      onOpenUsers != null ||
      onOpenSupport != null;
}

class _MetricsGrid extends StatelessWidget {
  const _MetricsGrid({required this.stats});

  final AdminDashboardStatsModel stats;

  @override
  Widget build(BuildContext context) {
    final metrics = <({IconData icon, String key, int value, Color color})>[
      (
        icon: Icons.group_outlined,
        key: 'admin.dashboard.totalUsers',
        value: stats.totalUsers,
        color: AppColors.brand700,
      ),
      (
        icon: Icons.dns_outlined,
        key: 'admin.dashboard.totalServers',
        value: stats.totalServers,
        color: AppColors.info,
      ),
      (
        icon: Icons.payments_outlined,
        key: 'admin.dashboard.totalPurchases',
        value: stats.totalPurchases,
        color: AppColors.success,
      ),
      (
        icon: Icons.play_circle_outline_rounded,
        key: 'admin.dashboard.activeReservations',
        value: stats.activeReservations,
        color: AppColors.success,
      ),
      (
        icon: Icons.event_available_outlined,
        key: 'admin.dashboard.upcomingReservations',
        value: stats.upcomingReservations,
        color: AppColors.info,
      ),
      (
        icon: Icons.hourglass_top_rounded,
        key: 'admin.dashboard.startingSoon',
        value: stats.startingSoonReservations,
        color: AppColors.warning,
      ),
      (
        icon: Icons.hourglass_bottom_rounded,
        key: 'admin.dashboard.endingSoon',
        value: stats.endingSoonReservations,
        color: AppColors.warning,
      ),
      (
        icon: Icons.pending_actions_rounded,
        key: 'admin.dashboard.pendingPayments',
        value: stats.pendingPayments,
        color: AppColors.warning,
      ),
      (
        icon: Icons.cloud_off_outlined,
        key: 'admin.dashboard.unavailableServers',
        value: stats.unavailableServers,
        color: AppColors.danger,
      ),
      (
        icon: Icons.construction_outlined,
        key: 'admin.dashboard.maintenanceServers',
        value: stats.maintenanceServers,
        color: AppColors.warning,
      ),
      (
        icon: Icons.support_agent_rounded,
        key: 'admin.dashboard.waitingSupport',
        value: stats.waitingSupportConversations,
        color: AppColors.info,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 760
            ? 3
            : constraints.maxWidth >= 500
            ? 2
            : 1;
        final width = (constraints.maxWidth - ((columns - 1) * 12)) / columns;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final metric in metrics)
              SizedBox(
                width: width,
                child: AdminMetricCard(
                  icon: metric.icon,
                  label: context.l10n.tr(metric.key),
                  value: metric.value,
                  color: metric.color,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _AdminActions extends StatelessWidget {
  const _AdminActions({
    required this.stats,
    this.onOpenServers,
    this.onOpenReservations,
    this.onOpenUsers,
    this.onOpenSupport,
  });

  final AdminDashboardStatsModel stats;
  final AdminDashboardDestination? onOpenServers;
  final AdminDashboardDestination? onOpenReservations;
  final AdminDashboardDestination? onOpenUsers;
  final AdminDashboardDestination? onOpenSupport;

  @override
  Widget build(BuildContext context) {
    final actions =
        <({IconData icon, String key, AdminDashboardDestination call, int count})>[
          if (onOpenServers != null)
            (
              icon: Icons.dns_rounded,
              key: 'admin.dashboard.serversTitle',
              call: onOpenServers!,
              count: 0,
            ),
          if (onOpenReservations != null)
            (
              icon: Icons.receipt_long_rounded,
              key: 'admin.dashboard.ordersTitle',
              call: onOpenReservations!,
              count: stats.pendingAssignmentReservations,
            ),
          if (onOpenUsers != null)
            (
              icon: Icons.group_rounded,
              key: 'admin.dashboard.usersTitle',
              call: onOpenUsers!,
              count: 0,
            ),
          if (onOpenSupport != null)
            (
              icon: Icons.support_agent_rounded,
              key: 'admin.dashboard.supportTitle',
              call: onOpenSupport!,
              count: stats.supportAttentionConversations,
            ),
        ];
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final action in actions)
          OutlinedButton.icon(
            onPressed: () => unawaited(Future.sync(action.call)),
            icon: Badge(
              isLabelVisible: action.count > 0,
              label: Text(AppFormat.number(context, action.count)),
              child: Icon(action.icon),
            ),
            label: Text(context.l10n.tr(action.key)),
          ),
      ],
    );
  }
}

class _AuditRow extends StatelessWidget {
  const _AuditRow({required this.event});

  final AdminAuditEventModel event;

  @override
  Widget build(BuildContext context) {
    final actionKey = 'admin.audit.actions.${event.action}';
    final localizedAction = context.l10n.tr(actionKey);
    return Padding(
      padding: const EdgeInsets.all(15),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.history_rounded,
            size: 19,
            color: AppColors.brand700,
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  localizedAction == actionKey ? event.action : localizedAction,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                if (event.details?.trim().isNotEmpty == true) ...[
                  const SizedBox(height: 4),
                  Text(
                    event.details!,
                    textDirection: TextDirection.ltr,
                    style: const TextStyle(
                      color: AppColors.ink500,
                      fontSize: 12,
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  AppFormat.dateTime(context, event.createdAt),
                  style: const TextStyle(color: AppColors.ink500, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
