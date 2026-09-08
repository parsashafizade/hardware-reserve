import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/network/error_presenter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/app_format.dart';
import '../../../core/widgets/async_states.dart';
import '../../../core/widgets/refresh_on_resume.dart';
import '../application/activity_controller.dart';
import '../application/notification_providers.dart';
import '../data/notification_models.dart';

typedef ReservationNotificationOpener =
    FutureOr<void> Function(int reservationId);
typedef SupportNotificationOpener =
    FutureOr<void> Function(String conversationId);

class ActivityScreen extends ConsumerStatefulWidget {
  const ActivityScreen({
    super.key,
    this.onOpenReservation,
    this.onOpenSupportConversation,
  });

  final ReservationNotificationOpener? onOpenReservation;
  final SupportNotificationOpener? onOpenSupportConversation;

  @override
  ConsumerState<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends ConsumerState<ActivityScreen> {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_loadMoreNearEnd);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_loadMoreNearEnd)
      ..dispose();
    super.dispose();
  }

  void _loadMoreNearEnd() {
    if (!mounted || !_scrollController.hasClients) {
      return;
    }
    if (_scrollController.position.extentAfter < 420) {
      unawaited(ref.read(activityControllerProvider.notifier).loadMore());
    }
  }

  Future<void> _openNotification(UserNotificationModel notification) async {
    unawaited(
      ref.read(activityControllerProvider.notifier).markRead(notification),
    );

    final reservationId = notification.reservationId;
    if (reservationId != null && widget.onOpenReservation != null) {
      await widget.onOpenReservation!(reservationId);
      return;
    }

    final conversationId = notification.supportConversationId;
    if (conversationId != null && widget.onOpenSupportConversation != null) {
      await widget.onOpenSupportConversation!(conversationId);
    }
  }

  bool _hasDestination(UserNotificationModel notification) {
    return (notification.reservationId != null &&
            widget.onOpenReservation != null) ||
        (notification.supportConversationId != null &&
            widget.onOpenSupportConversation != null);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(activityControllerProvider);
    final controller = ref.read(activityControllerProvider.notifier);

    return RefreshOnResume(
      onResume: controller.refresh,
      child: Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.tr('activity.title')),
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
      body: Column(
        children: [
          if (state.actionError != null)
            _ActionErrorBanner(
              error: state.actionError!,
              onDismiss: controller.clearActionError,
            ),
          Expanded(
            child: _ActivityBody(
              state: state,
              scrollController: _scrollController,
              onRefresh: controller.refresh,
              onLoadMore: controller.loadMore,
              onMarkAllRead: controller.markAllRead,
              hasDestination: _hasDestination,
              onOpenNotification: _openNotification,
            ),
          ),
        ],
      ),
      ),
    );
  }
}

class _ActivityBody extends StatelessWidget {
  const _ActivityBody({
    required this.state,
    required this.scrollController,
    required this.onRefresh,
    required this.onLoadMore,
    required this.onMarkAllRead,
    required this.hasDestination,
    required this.onOpenNotification,
  });

  final ActivityState state;
  final ScrollController scrollController;
  final Future<void> Function() onRefresh;
  final Future<void> Function() onLoadMore;
  final Future<void> Function() onMarkAllRead;
  final bool Function(UserNotificationModel notification) hasDestination;
  final ValueChanged<UserNotificationModel> onOpenNotification;

  @override
  Widget build(BuildContext context) {
    if (state.isLoading && state.notifications.isEmpty) {
      return const _ActivityLoadingView();
    }
    if (state.error != null && state.notifications.isEmpty) {
      return AppErrorView(error: state.error!, onRetry: onRefresh);
    }

    final sections = _groupNotifications(state.notifications);
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: CustomScrollView(
        controller: scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            sliver: SliverToBoxAdapter(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _ActivitySummaryCard(
                        unreadCount: state.unreadCount,
                        isMarkingAllRead: state.isMarkingAllRead,
                        onMarkAllRead: onMarkAllRead,
                      ),
                      const SizedBox(height: 24),
                      if (state.notifications.isEmpty)
                        const _ActivityEmptyCard()
                      else
                        for (final section in sections) ...[
                          _SectionHeading(labelKey: section.labelKey),
                          const SizedBox(height: 10),
                          for (final notification in section.notifications)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _NotificationCard(
                                notification: notification,
                                isMarkingRead: state.markingReadIds.contains(
                                  notification.id,
                                ),
                                hasDestination: hasDestination(notification),
                                onTap: () => onOpenNotification(notification),
                              ),
                            ),
                          const SizedBox(height: 10),
                        ],
                      _PaginationFooter(
                        hasMore: state.hasMore,
                        isLoading: state.isLoadingMore,
                        error: state.paginationError,
                        onLoadMore: onLoadMore,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivitySummaryCard extends StatelessWidget {
  const _ActivitySummaryCard({
    required this.unreadCount,
    required this.isMarkingAllRead,
    required this.onMarkAllRead,
  });

  final int unreadCount;
  final bool isMarkingAllRead;
  final Future<void> Function() onMarkAllRead;

  @override
  Widget build(BuildContext context) {
    final unreadLabel = context.l10n.tr('activity.unread', <String, Object?>{
      'count': AppFormat.number(context, unreadCount),
    });

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.panelRadius),
        gradient: const LinearGradient(
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
          colors: [AppColors.brand950, AppColors.brand700],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.brand950.withValues(alpha: .16),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: .16),
                  ),
                ),
                child: const Icon(
                  Icons.notifications_active_outlined,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              Semantics(
                label: unreadLabel,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: unreadCount > 0
                        ? AppColors.brand400.withValues(alpha: .22)
                        : Colors.white.withValues(alpha: .1),
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: .16),
                    ),
                  ),
                  child: Text(
                    unreadLabel,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            context.l10n.tr('activity.title'),
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            context.l10n.tr('activity.description'),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: .78),
              height: 1.55,
            ),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppColors.brand800,
              disabledBackgroundColor: Colors.white.withValues(alpha: .12),
              disabledForegroundColor: Colors.white.withValues(alpha: .55),
            ),
            onPressed: unreadCount == 0 || isMarkingAllRead
                ? null
                : () => unawaited(onMarkAllRead()),
            icon: isMarkingAllRead
                ? const SizedBox.square(
                    dimension: 17,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.done_all_rounded, size: 19),
            label: Text(
              context.l10n.tr(
                isMarkingAllRead ? 'activity.markingAll' : 'activity.markAll',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityEmptyCard extends StatelessWidget {
  const _ActivityEmptyCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Column(
          children: [
            EmptyState(
              icon: Icons.notifications_none_rounded,
              message: context.l10n.tr('activity.empty'),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(28, 0, 28, 24),
              child: Text(
                context.l10n.tr('activity.emptyBody'),
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.ink500),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.labelKey});

  final String labelKey;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          context.l10n.tr(labelKey),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: AppColors.ink700,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 10),
        const Expanded(child: Divider()),
      ],
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.notification,
    required this.isMarkingRead,
    required this.hasDestination,
    required this.onTap,
  });

  final UserNotificationModel notification;
  final bool isMarkingRead;
  final bool hasDestination;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final visual = _NotificationVisual.forType(notification.type);
    final title = _notificationTitle(context, notification);
    final message = notification.message?.trim();
    final canTap = !notification.isRead || hasDestination;
    final source = _notificationSourceLabel(context, notification.source);
    final semanticsParts = <String>[
      if (!notification.isRead) context.l10n.tr('activity.unreadSemantic'),
      title,
      if (message != null && message.isNotEmpty) message,
      AppFormat.dateTime(context, notification.createdAt),
    ];

    return Semantics(
      button: canTap,
      label: semanticsParts.join('. '),
      child: Material(
        color: notification.isRead ? Colors.white : AppColors.brand50,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.cardRadius),
          side: BorderSide(
            color: notification.isRead ? AppColors.border : AppColors.brand200,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: canTap ? onTap : null,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: visual.color.withValues(alpha: .11),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(visual.icon, color: visual.color, size: 22),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: visual.color.withValues(alpha: .09),
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: Text(
                              source,
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    color: visual.color,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ),
                          const Spacer(),
                          if (isMarkingRead)
                            const SizedBox.square(
                              dimension: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          else if (!notification.isRead)
                            Container(
                              width: 9,
                              height: 9,
                              decoration: const BoxDecoration(
                                color: AppColors.brand500,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 9),
                      Text(
                        title,
                        textDirection: _textDirectionFor(title),
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontWeight: notification.isRead
                                  ? FontWeight.w600
                                  : FontWeight.w700,
                              height: 1.45,
                            ),
                      ),
                      if (message != null && message.isNotEmpty) ...[
                        const SizedBox(height: 5),
                        Text(
                          message,
                          textDirection: _textDirectionFor(message),
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: AppColors.ink600, height: 1.55),
                        ),
                      ],
                      const SizedBox(height: 11),
                      Wrap(
                        spacing: 12,
                        runSpacing: 7,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          _Metadata(
                            icon: Icons.schedule_rounded,
                            label: AppFormat.dateTime(
                              context,
                              notification.createdAt,
                            ),
                          ),
                          if (hasDestination)
                            _DestinationHint(notification: notification),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Metadata extends StatelessWidget {
  const _Metadata({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: AppColors.ink500),
        const SizedBox(width: 5),
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: AppColors.ink500),
        ),
      ],
    );
  }
}

class _DestinationHint extends StatelessWidget {
  const _DestinationHint({required this.notification});

  final UserNotificationModel notification;

  @override
  Widget build(BuildContext context) {
    final isSupport = notification.supportConversationId != null;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          isSupport ? Icons.forum_outlined : Icons.open_in_new_rounded,
          size: 15,
          color: AppColors.brand600,
        ),
        const SizedBox(width: 5),
        Text(
          context.l10n.tr(
            isSupport ? 'activity.openSupport' : 'activity.openReservation',
          ),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: AppColors.brand700,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _PaginationFooter extends StatelessWidget {
  const _PaginationFooter({
    required this.hasMore,
    required this.isLoading,
    required this.error,
    required this.onLoadMore,
  });

  final bool hasMore;
  final bool isLoading;
  final Object? error;
  final Future<void> Function() onLoadMore;

  @override
  Widget build(BuildContext context) {
    if (error != null) {
      return Container(
        margin: const EdgeInsets.only(top: 4),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF5F6),
          borderRadius: BorderRadius.circular(AppTheme.controlRadius),
          border: Border.all(color: AppColors.danger.withValues(alpha: .16)),
        ),
        child: Column(
          children: [
            Text(
              presentError(context, error!),
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.danger),
            ),
            const SizedBox(height: 6),
            TextButton.icon(
              onPressed: () => unawaited(onLoadMore()),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text(context.l10n.tr('activity.paginationRetry')),
            ),
          ],
        ),
      );
    }
    if (!hasMore) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Center(
        child: OutlinedButton.icon(
          onPressed: isLoading ? null : () => unawaited(onLoadMore()),
          icon: isLoading
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.expand_more_rounded),
          label: Text(
            context.l10n.tr(
              isLoading ? 'activity.loadingMore' : 'activity.loadMore',
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionErrorBanner extends StatelessWidget {
  const _ActionErrorBanner({required this.error, required this.onDismiss});

  final Object error;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        padding: const EdgeInsetsDirectional.only(start: 12, top: 7, bottom: 7),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF0F2),
          borderRadius: BorderRadius.circular(AppTheme.controlRadius),
          border: Border.all(color: AppColors.danger.withValues(alpha: .2)),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 18,
              color: AppColors.danger,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                presentError(context, error),
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.danger),
              ),
            ),
            IconButton(
              tooltip: context.l10n.tr('action.close'),
              visualDensity: VisualDensity.compact,
              onPressed: onDismiss,
              icon: const Icon(Icons.close_rounded, size: 18),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivityLoadingView extends StatelessWidget {
  const _ActivityLoadingView();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  height: 225,
                  decoration: BoxDecoration(
                    color: AppColors.brand950,
                    borderRadius: BorderRadius.circular(AppTheme.panelRadius),
                  ),
                  child: const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                ),
                const SizedBox(height: 26),
                const _SkeletonBox(height: 20, widthFactor: .28),
                const SizedBox(height: 13),
                for (var index = 0; index < 3; index++) ...[
                  const _SkeletonBox(height: 132),
                  const SizedBox(height: 10),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SkeletonBox extends StatelessWidget {
  const _SkeletonBox({required this.height, this.widthFactor = 1});

  final double height;
  final double widthFactor;

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      widthFactor: widthFactor,
      alignment: AlignmentDirectional.centerStart,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: AppColors.muted,
          borderRadius: BorderRadius.circular(AppTheme.cardRadius),
          border: Border.all(color: AppColors.border),
        ),
      ),
    );
  }
}

class _NotificationSection {
  const _NotificationSection({
    required this.labelKey,
    required this.notifications,
  });

  final String labelKey;
  final List<UserNotificationModel> notifications;
}

List<_NotificationSection> _groupNotifications(
  List<UserNotificationModel> notifications,
) {
  final now = DateTime.now();
  final today = DateUtils.dateOnly(now);
  final yesterday = today.subtract(const Duration(days: 1));
  final groups = <String, List<UserNotificationModel>>{};

  for (final notification in notifications) {
    final date = DateUtils.dateOnly(notification.createdAt.toLocal());
    final labelKey = date == today
        ? 'activity.today'
        : date == yesterday
        ? 'activity.yesterday'
        : 'activity.earlier';
    groups
        .putIfAbsent(labelKey, () => <UserNotificationModel>[])
        .add(notification);
  }

  return <String>['activity.today', 'activity.yesterday', 'activity.earlier']
      .where(groups.containsKey)
      .map(
        (key) => _NotificationSection(
          labelKey: key,
          notifications: List<UserNotificationModel>.unmodifiable(groups[key]!),
        ),
      )
      .toList(growable: false);
}

String _notificationTitle(
  BuildContext context,
  UserNotificationModel notification,
) {
  final backendTitle = notification.title?.trim();
  if ((notification.type == UserNotificationType.adminMessage ||
          notification.type == UserNotificationType.unknown) &&
      backendTitle != null &&
      backendTitle.isNotEmpty) {
    return backendTitle;
  }

  final key = switch (notification.type) {
    UserNotificationType.reservationCreated =>
      'activity.type.ReservationCreated',
    UserNotificationType.paymentConfirmed => 'activity.type.PaymentConfirmed',
    UserNotificationType.reservationStartsSoon =>
      'activity.type.ReservationStartsSoon',
    UserNotificationType.reservationStarted =>
      'activity.type.ReservationStarted',
    UserNotificationType.reservationEndsSoon =>
      'activity.type.ReservationEndsSoon',
    UserNotificationType.reservationCompleted =>
      'activity.type.ReservationCompleted',
    UserNotificationType.serviceDetailsAssigned =>
      'activity.type.ServiceDetailsAssigned',
    UserNotificationType.supportReply => 'activity.type.SupportReply',
    UserNotificationType.adminMessage => 'activity.type.AdminMessage',
    UserNotificationType.reservationCancelled =>
      'activity.type.ReservationCancelled',
    UserNotificationType.unknown => 'activity.unknown',
  };
  final resourceLabel = notification.resourceLabel?.trim();
  final fallbackKey = notification.type == UserNotificationType.supportReply
      ? 'activity.supportFallback'
      : 'activity.fallbackResource';
  return context.l10n.tr(key, <String, Object?>{
    'name': resourceLabel == null || resourceLabel.isEmpty
        ? context.l10n.tr(fallbackKey)
        : resourceLabel,
  });
}

String _notificationSourceLabel(
  BuildContext context,
  UserNotificationSource source,
) {
  return context.l10n.tr(switch (source) {
    UserNotificationSource.system => 'activity.system',
    UserNotificationSource.admin => 'activity.admin',
    UserNotificationSource.unknown => 'activity.sourceUnknown',
  });
}

TextDirection? _textDirectionFor(String value) {
  for (final rune in value.runes) {
    final isArabic =
        (rune >= 0x0600 && rune <= 0x06FF) ||
        (rune >= 0x0750 && rune <= 0x077F) ||
        (rune >= 0x08A0 && rune <= 0x08FF) ||
        (rune >= 0xFB50 && rune <= 0xFDFF) ||
        (rune >= 0xFE70 && rune <= 0xFEFF);
    if (isArabic) {
      return TextDirection.rtl;
    }

    final isLatinUppercase = rune >= 0x41 && rune <= 0x5A;
    final isLatinLowercase = rune >= 0x61 && rune <= 0x7A;
    if (isLatinUppercase || isLatinLowercase) {
      return TextDirection.ltr;
    }
  }
  return null;
}

class _NotificationVisual {
  const _NotificationVisual(this.icon, this.color);

  factory _NotificationVisual.forType(UserNotificationType type) {
    return switch (type) {
      UserNotificationType.reservationCreated => const _NotificationVisual(
        Icons.event_available_outlined,
        AppColors.info,
      ),
      UserNotificationType.paymentConfirmed => const _NotificationVisual(
        Icons.verified_outlined,
        AppColors.success,
      ),
      UserNotificationType.reservationStartsSoon => const _NotificationVisual(
        Icons.upcoming_outlined,
        AppColors.warning,
      ),
      UserNotificationType.reservationStarted => const _NotificationVisual(
        Icons.play_circle_outline_rounded,
        AppColors.success,
      ),
      UserNotificationType.reservationEndsSoon => const _NotificationVisual(
        Icons.timer_outlined,
        AppColors.warning,
      ),
      UserNotificationType.reservationCompleted => const _NotificationVisual(
        Icons.task_alt_rounded,
        AppColors.success,
      ),
      UserNotificationType.serviceDetailsAssigned => const _NotificationVisual(
        Icons.vpn_key_outlined,
        AppColors.success,
      ),
      UserNotificationType.supportReply => const _NotificationVisual(
        Icons.mark_chat_unread_outlined,
        AppColors.info,
      ),
      UserNotificationType.adminMessage => const _NotificationVisual(
        Icons.campaign_outlined,
        AppColors.brand700,
      ),
      UserNotificationType.reservationCancelled => const _NotificationVisual(
        Icons.event_busy_outlined,
        AppColors.danger,
      ),
      UserNotificationType.unknown => const _NotificationVisual(
        Icons.notifications_outlined,
        AppColors.ink500,
      ),
    };
  }

  final IconData icon;
  final Color color;
}
