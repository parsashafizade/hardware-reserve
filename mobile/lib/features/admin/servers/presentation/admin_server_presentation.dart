import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/network/api_failure.dart';
import '../../../../core/network/error_presenter.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/app_status_badge.dart';
import '../data/admin_server_contracts.dart';

String adminServerStatusLabel(
  BuildContext context,
  AdminServerOperationalStatus status,
) {
  final key =
      'admin.servers.status.${switch (status) {
        AdminServerOperationalStatus.available => 'available',
        AdminServerOperationalStatus.temporarilyUnavailable => 'temporarilyUnavailable',
        AdminServerOperationalStatus.maintenance => 'maintenance',
        AdminServerOperationalStatus.disabled => 'disabled',
      }}';
  final localized = context.l10n.tr(key);
  return localized == key ? status.wireValue : localized;
}

Color adminServerStatusColor(AdminServerOperationalStatus status) {
  return switch (status) {
    AdminServerOperationalStatus.available => AppColors.success,
    AdminServerOperationalStatus.temporarilyUnavailable => AppColors.warning,
    AdminServerOperationalStatus.maintenance => AppColors.info,
    AdminServerOperationalStatus.disabled => AppColors.ink500,
  };
}

String adminServerTierLabel(
  BuildContext context,
  AdminServerPerformanceTier tier,
) {
  final key =
      'admin.servers.tier.${switch (tier) {
        AdminServerPerformanceTier.entry => 'entry',
        AdminServerPerformanceTier.standard => 'standard',
        AdminServerPerformanceTier.high => 'high',
        AdminServerPerformanceTier.extreme => 'extreme',
      }}';
  final localized = context.l10n.tr(key);
  return localized == key ? tier.wireValue : localized;
}

String adminServerWorkloadLabel(
  BuildContext context,
  AdminServerWorkloadType workload,
) {
  final key =
      'admin.servers.workload.${switch (workload) {
        AdminServerWorkloadType.modelTraining => 'modelTraining',
        AdminServerWorkloadType.inference => 'inference',
        AdminServerWorkloadType.rendering => 'rendering',
        AdminServerWorkloadType.developmentCompilation => 'developmentCompilation',
        AdminServerWorkloadType.dataProcessing => 'dataProcessing',
        AdminServerWorkloadType.webBackendHosting => 'webBackendHosting',
        AdminServerWorkloadType.generalCompute => 'generalCompute',
      }}';
  final localized = context.l10n.tr(key);
  return localized == key ? workload.wireValue : localized;
}

String adminServerErrorText(BuildContext context, Object error) {
  final failure = ApiFailure.from(error);
  if (failure.code == 'RESERVATION_TIME_CONFLICT') {
    return context.l10n.tr('admin.servers.maintenanceConflict');
  }
  if (failure.statusCode == 404) {
    return context.l10n.tr('admin.servers.notFound');
  }
  return presentError(context, failure);
}

bool isAmbiguousAdminServerFailure(Object error) {
  final failure = ApiFailure.from(error);
  return failure.kind == ApiFailureKind.offline ||
      failure.kind == ApiFailureKind.timeout ||
      failure.kind == ApiFailureKind.server;
}

class AdminServerStatusBadge extends StatelessWidget {
  const AdminServerStatusBadge({super.key, required this.status});

  final AdminServerOperationalStatus status;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: AlignmentDirectional.centerStart,
      child: AppStatusBadge(
        label: adminServerStatusLabel(context, status),
        color: adminServerStatusColor(status),
      ),
    );
  }
}

class AdminServerDetailRow extends StatelessWidget {
  const AdminServerDetailRow({
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
            child: Text(label, style: const TextStyle(color: AppColors.ink500)),
          ),
          const SizedBox(width: 16),
          Flexible(
            child: Text(
              value,
              textDirection: valueDirection,
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class AdminServerInlineError extends StatelessWidget {
  const AdminServerInlineError({super.key, required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(AppTheme.controlRadius),
        border: Border.all(color: AppColors.danger.withValues(alpha: .2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded, color: AppColors.danger),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              adminServerErrorText(context, error),
              style: const TextStyle(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );
  }
}
