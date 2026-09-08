import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/app_format.dart';
import '../../../../core/widgets/app_status_badge.dart';
import '../../../../core/widgets/async_states.dart';
import '../../../../core/widgets/first_strong_text.dart';
import '../application/admin_operations_providers.dart';
import '../data/admin_operations_models.dart';
import 'admin_operations_widgets.dart';
import 'admin_reservations_screen.dart';

class AdminUserOverviewScreen extends ConsumerWidget {
  const AdminUserOverviewScreen({
    super.key,
    required this.userId,
    this.onOpenReservation,
  });

  final int userId;
  final AdminReservationOpener? onOpenReservation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = adminUserOverviewControllerProvider(userId);
    final state = ref.watch(provider);
    final controller = ref.read(provider.notifier);
    final user = state.user;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.tr('admin.userOverview.title')),
        actions: [
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
      body: state.isLoading && user == null
          ? const AppLoadingView()
          : state.error != null && user == null
          ? AppErrorView(error: state.error!, onRetry: controller.load)
          : RefreshIndicator(
              onRefresh: controller.refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 36),
                children: [
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 760),
                      child: _OverviewContent(
                        user: user!,
                        onOpenReservation: onOpenReservation,
                        refreshError: state.error,
                        onRetry: () => unawaited(controller.refresh()),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _OverviewContent extends StatelessWidget {
  const _OverviewContent({
    required this.user,
    required this.onRetry,
    this.onOpenReservation,
    this.refreshError,
  });

  final AdminUserOverviewModel user;
  final AdminReservationOpener? onOpenReservation;
  final Object? refreshError;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (refreshError != null) ...[
          AdminInlineError(error: refreshError!, onRetry: onRetry),
          const SizedBox(height: 12),
        ],
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.brand100,
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: const Icon(
                        Icons.person_rounded,
                        color: AppColors.brand700,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          FirstStrongText(
                            user.fullName,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 4),
                          SelectableText(
                            user.email,
                            textDirection: TextDirection.ltr,
                            textAlign: TextAlign.start,
                            style: const TextStyle(
                              color: AppColors.ink500,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    AppStatusBadge(
                      label: context.l10n.tr(
                        user.isAdmin
                            ? 'admin.users.roleAdmin'
                            : 'admin.users.roleUser',
                      ),
                      color: user.isAdmin
                          ? AppColors.brand700
                          : AppColors.ink600,
                    ),
                    AppStatusBadge(
                      label: context.l10n.tr(
                        user.isEmailVerified
                            ? 'admin.users.verified'
                            : 'admin.users.unverified',
                      ),
                      color: user.isEmailVerified
                          ? AppColors.success
                          : AppColors.warning,
                    ),
                  ],
                ),
                const Divider(height: 25),
                AdminDetailLine(
                  label: context.l10n.tr('admin.userOverview.userId'),
                  value: AppFormat.number(context, user.id),
                  valueDirection: TextDirection.ltr,
                ),
                AdminDetailLine(
                  label: context.l10n.tr('admin.userOverview.createdAt'),
                  value: AppFormat.dateTime(context, user.createdAt),
                ),
                if (user.emailVerifiedAt != null)
                  AdminDetailLine(
                    label: context.l10n.tr(
                      'admin.userOverview.emailVerifiedAt',
                    ),
                    value: AppFormat.dateTime(context, user.emailVerifiedAt!),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        Text(
          context.l10n.tr('admin.userOverview.metrics'),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 11),
        _Metrics(user: user),
        const SizedBox(height: 22),
        Text(
          context.l10n.tr('admin.userOverview.recentReservations'),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 11),
        if (user.recentReservations.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                context.l10n.tr('admin.userOverview.noReservations'),
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.ink500),
              ),
            ),
          )
        else
          for (
            var index = 0;
            index < user.recentReservations.length;
            index++
          ) ...[
            AdminOrderCard(
              order: user.recentReservations[index],
              onTap: onOpenReservation == null
                  ? null
                  : () => unawaited(
                      Future.sync(
                        () => onOpenReservation!(
                          user.recentReservations[index].reservationId,
                        ),
                      ),
                    ),
            ),
            if (index < user.recentReservations.length - 1)
              const SizedBox(height: 10),
          ],
      ],
    );
  }
}

class _Metrics extends StatelessWidget {
  const _Metrics({required this.user});

  final AdminUserOverviewModel user;

  @override
  Widget build(BuildContext context) {
    final metrics = <({IconData icon, String key, int value, Color color})>[
      (
        icon: Icons.receipt_long_outlined,
        key: 'admin.userOverview.reservations',
        value: user.reservationCount,
        color: AppColors.brand700,
      ),
      (
        icon: Icons.play_circle_outline_rounded,
        key: 'admin.userOverview.active',
        value: user.activeReservationCount,
        color: AppColors.success,
      ),
      (
        icon: Icons.payments_outlined,
        key: 'admin.userOverview.payments',
        value: user.completedPaymentCount,
        color: AppColors.success,
      ),
      (
        icon: Icons.support_agent_outlined,
        key: 'admin.userOverview.support',
        value: user.supportConversationCount,
        color: AppColors.info,
      ),
      (
        icon: Icons.notifications_outlined,
        key: 'admin.userOverview.unread',
        value: user.unreadNotificationCount,
        color: AppColors.warning,
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 620 ? 2 : 1;
        final width = (constraints.maxWidth - ((columns - 1) * 10)) / columns;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
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
