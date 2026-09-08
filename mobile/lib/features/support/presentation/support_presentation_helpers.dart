import 'package:flutter/material.dart';

export '../../../core/widgets/first_strong_text.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_status_badge.dart';
import '../data/support_models.dart';

const supportCategories = <String>[
  'General support',
  'Hardware selection',
  'Reservations',
  'Payments',
  'Provisioning',
  'Account',
];

String supportCategoryLabel(BuildContext context, String category) {
  return switch (category) {
    'General support' => context.l10n.tr('support.category.general'),
    'Hardware selection' => context.l10n.tr('support.category.hardware'),
    'Reservations' => context.l10n.tr('support.category.reservations'),
    'Payments' => context.l10n.tr('support.category.payments'),
    'Provisioning' => context.l10n.tr('support.category.provisioning'),
    'Account' => context.l10n.tr('support.category.account'),
    _ => category,
  };
}

String supportStatusLabel(
  BuildContext context,
  SupportConversationStatus status,
) {
  return switch (status) {
    SupportConversationStatus.aiActive => context.l10n.tr(
      'support.status.aiActive',
    ),
    SupportConversationStatus.waitingForAdmin => context.l10n.tr(
      'support.status.waitingForAdmin',
    ),
    SupportConversationStatus.adminActive => context.l10n.tr(
      'support.status.adminActive',
    ),
    SupportConversationStatus.resolved => context.l10n.tr(
      'support.status.resolved',
    ),
    SupportConversationStatus.closed => context.l10n.tr(
      'support.status.closed',
    ),
    SupportConversationStatus.unknown => context.l10n.tr(
      'support.status.unknown',
    ),
  };
}

Color supportStatusColor(SupportConversationStatus status) {
  return switch (status) {
    SupportConversationStatus.aiActive => AppColors.brand600,
    SupportConversationStatus.waitingForAdmin => AppColors.warning,
    SupportConversationStatus.adminActive => AppColors.info,
    SupportConversationStatus.resolved => AppColors.success,
    SupportConversationStatus.closed => AppColors.ink500,
    SupportConversationStatus.unknown => AppColors.ink500,
  };
}

String supportSenderLabel(
  BuildContext context,
  SupportParticipantType participantType,
) {
  return switch (participantType) {
    SupportParticipantType.user => context.l10n.tr('support.you'),
    SupportParticipantType.ai => context.l10n.tr('support.ai'),
    SupportParticipantType.admin => context.l10n.tr('support.admin'),
    SupportParticipantType.unknown => context.l10n.tr(
      'support.participantUnknown',
    ),
  };
}

class SupportStatusChip extends StatelessWidget {
  const SupportStatusChip({super.key, required this.status});

  final SupportConversationStatus status;

  @override
  Widget build(BuildContext context) {
    final color = supportStatusColor(status);
    return AppStatusBadge(
      label: supportStatusLabel(context, status),
      color: color,
    );
  }
}
