import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/network/error_presenter.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/app_format.dart';
import '../../../../core/widgets/app_status_badge.dart';
import '../../../../core/widgets/first_strong_text.dart';
import '../data/admin_operations_models.dart';

class AdminMetricCard extends StatelessWidget {
  const AdminMetricCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.color = AppColors.brand700,
  });

  final IconData icon;
  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: .1),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(icon, color: color, size: 21),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AppFormat.number(context, value),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    label,
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
      ),
    );
  }
}

class AdminInlineError extends StatelessWidget {
  const AdminInlineError({
    super.key,
    required this.error,
    required this.onRetry,
  });

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(13, 10, 7, 10),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: .07),
        borderRadius: BorderRadius.circular(AppTheme.controlRadius),
        border: Border.all(color: AppColors.danger.withValues(alpha: .22)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: AppColors.danger),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              presentError(context, error),
              style: const TextStyle(color: AppColors.danger, fontSize: 12),
            ),
          ),
          TextButton(
            onPressed: onRetry,
            child: Text(context.l10n.tr('action.retry')),
          ),
        ],
      ),
    );
  }
}

class AdminWireStatusBadge extends StatelessWidget {
  const AdminWireStatusBadge({
    super.key,
    required this.status,
    required this.kind,
  });

  final String status;
  final String kind;

  @override
  Widget build(BuildContext context) {
    final normalized = normalizeAdminWireValue(status);
    final color = switch (normalized) {
      'paid' || 'completed' || 'active' => AppColors.success,
      'pending' ||
      'pendingpayment' ||
      'unpaid' ||
      'upcoming' => AppColors.warning,
      'cancelled' || 'failed' || 'refunded' => AppColors.danger,
      _ => AppColors.info,
    };
    final key = 'admin.status.$kind.$status';
    final localized = context.l10n.tr(key);
    return AppStatusBadge(
      label: localized == key ? status : localized,
      color: color,
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
    );
  }
}

class AdminProvisioningBadge extends StatelessWidget {
  const AdminProvisioningBadge({super.key, required this.credentialsAssigned});

  final bool credentialsAssigned;

  @override
  Widget build(BuildContext context) {
    return AppStatusBadge(
      label: context.l10n.tr(
        credentialsAssigned
            ? 'admin.provisioning.assigned'
            : 'admin.provisioning.notAssigned',
      ),
      color: credentialsAssigned ? AppColors.success : AppColors.warning,
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
    );
  }
}

class AdminOrderCard extends StatelessWidget {
  const AdminOrderCard({super.key, required this.order, this.onTap});

  final AdminOrderModel order;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.brand100,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: const Icon(
                      Icons.receipt_long_rounded,
                      color: AppColors.brand700,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.l10n.tr(
                            'admin.reservations.number',
                            <String, Object?>{
                              'id': AppFormat.number(
                                context,
                                order.reservationId,
                              ),
                            },
                          ),
                          style: const TextStyle(
                            color: AppColors.ink500,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          order.hardwareLabel,
                          textDirection: TextDirection.ltr,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                  ),
                  if (onTap != null)
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: AppColors.ink500,
                    ),
                ],
              ),
              const SizedBox(height: 13),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: [
                  AdminWireStatusBadge(
                    status: order.reservationStatus,
                    kind: 'reservation',
                  ),
                  AdminWireStatusBadge(
                    status: order.paymentStatus,
                    kind: 'payment',
                  ),
                  AdminProvisioningBadge(
                    credentialsAssigned: order.credentialsAssigned,
                  ),
                ],
              ),
              const Divider(height: 25),
              _CompactLine(
                icon: Icons.person_outline_rounded,
                text: order.userFullName,
              ),
              const SizedBox(height: 8),
              _CompactLine(
                icon: Icons.schedule_rounded,
                text: AppFormat.dateTime(context, order.startTime),
              ),
              const SizedBox(height: 8),
              _CompactLine(
                icon: Icons.payments_outlined,
                text: AppFormat.money(
                  context,
                  order.totalPrice,
                  context.l10n.tr('common.toman'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AdminPaginationBar extends StatelessWidget {
  const AdminPaginationBar({
    super.key,
    required this.page,
    required this.totalCount,
    required this.hasPrevious,
    required this.hasNext,
    required this.busy,
    required this.onPrevious,
    required this.onNext,
  });

  final int page;
  final int totalCount;
  final bool hasPrevious;
  final bool hasNext;
  final bool busy;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton.outlined(
          tooltip: context.l10n.tr('admin.pagination.previous'),
          onPressed: hasPrevious && !busy ? onPrevious : null,
          icon: const Icon(Icons.chevron_left_rounded),
        ),
        Expanded(
          child: Column(
            children: [
              Text(
                context.l10n.tr('admin.pagination.page', <String, Object?>{
                  'page': AppFormat.number(context, page),
                }),
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              Text(
                context.l10n.tr('admin.pagination.total', <String, Object?>{
                  'count': AppFormat.number(context, totalCount),
                }),
                style: const TextStyle(color: AppColors.ink500, fontSize: 11),
              ),
            ],
          ),
        ),
        IconButton.outlined(
          tooltip: context.l10n.tr('admin.pagination.next'),
          onPressed: hasNext && !busy ? onNext : null,
          icon: const Icon(Icons.chevron_right_rounded),
        ),
      ],
    );
  }
}

class AdminDetailLine extends StatelessWidget {
  const AdminDetailLine({
    super.key,
    required this.label,
    required this.value,
    this.valueDirection,
  });

  final String label;
  final String value;
  final TextDirection? valueDirection;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: AppColors.ink500, fontSize: 12),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: SelectableText(
              value,
              textDirection: valueDirection ?? firstStrongTextDirection(value),
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactLine extends StatelessWidget {
  const _CompactLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.ink500),
        const SizedBox(width: 8),
        Expanded(
          child: FirstStrongText(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppColors.ink700, fontSize: 12),
          ),
        ),
      ],
    );
  }
}
