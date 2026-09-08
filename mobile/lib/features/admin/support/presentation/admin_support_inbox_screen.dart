import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/app_format.dart';
import '../../../../core/widgets/app_status_badge.dart';
import '../../../../core/widgets/async_states.dart';
import '../../../support/data/support_models.dart';
import '../../../support/presentation/support_presentation_helpers.dart';
import '../../../support/realtime/support_realtime_service.dart';
import '../application/admin_support_inbox_controller.dart';
import '../application/admin_support_providers.dart';
import '../data/admin_support_models.dart';
import 'admin_support_quick_replies_sheet.dart';
import 'admin_support_text.dart';

class AdminSupportInboxScreen extends ConsumerWidget {
  const AdminSupportInboxScreen({super.key, this.onOpenConversation});

  final Future<void> Function(String conversationId)? onOpenConversation;

  Future<void> _openConversation(
    BuildContext context,
    WidgetRef ref,
    String conversationId,
  ) async {
    if (onOpenConversation != null) {
      await onOpenConversation!(conversationId);
    } else {
      await context.push('/admin/support/$conversationId');
    }
    if (context.mounted) {
      await ref.read(adminSupportInboxControllerProvider.notifier).load();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(adminSupportInboxControllerProvider);
    final controller = ref.read(adminSupportInboxControllerProvider.notifier);
    return _AdminInboxLifecycle(
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            adminSupportText(
              context,
              'admin.support.inbox.title',
              fa: 'صندوق پشتیبانی',
              en: 'Support inbox',
            ),
          ),
          actions: [
            IconButton(
              tooltip: adminSupportText(
                context,
                'admin.support.quickReplies.title',
                fa: 'پاسخ‌های آماده',
                en: 'Quick replies',
              ),
              onPressed: () => showAdminSupportQuickRepliesSheet(context),
              icon: const Icon(Icons.quickreply_outlined),
            ),
            IconButton(
              tooltip: context.l10n.tr('action.refresh'),
              onPressed: state.isLoading ? null : controller.load,
              icon: const Icon(Icons.refresh_rounded),
            ),
            const SizedBox(width: 4),
          ],
        ),
        body: _InboxBody(
          state: state,
          onRefresh: controller.load,
          onLoadMore: controller.loadMore,
          onSearch: controller.setSearchQuery,
          onStatus: controller.setStatusFilter,
          onCategory: controller.setCategoryFilter,
          onOpenConversation: (conversation) =>
              _openConversation(context, ref, conversation.id),
        ),
      ),
    );
  }
}

class _AdminInboxLifecycle extends ConsumerStatefulWidget {
  const _AdminInboxLifecycle({required this.child});

  final Widget child;

  @override
  ConsumerState<_AdminInboxLifecycle> createState() =>
      _AdminInboxLifecycleState();
}

class _AdminInboxLifecycleState extends ConsumerState<_AdminInboxLifecycle> {
  late final AppLifecycleListener _lifecycleListener;

  @override
  void initState() {
    super.initState();
    _lifecycleListener = AppLifecycleListener(
      onPause: () =>
          ref.read(adminSupportInboxControllerProvider.notifier).onAppPaused(),
      onResume: () => unawaited(
        ref.read(adminSupportInboxControllerProvider.notifier).onAppResumed(),
      ),
    );
  }

  @override
  void dispose() {
    _lifecycleListener.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _InboxBody extends StatelessWidget {
  const _InboxBody({
    required this.state,
    required this.onRefresh,
    required this.onLoadMore,
    required this.onSearch,
    required this.onStatus,
    required this.onCategory,
    required this.onOpenConversation,
  });

  final AdminSupportInboxState state;
  final Future<void> Function() onRefresh;
  final Future<void> Function() onLoadMore;
  final ValueChanged<String> onSearch;
  final Future<void> Function(SupportConversationStatus?) onStatus;
  final Future<void> Function(String?) onCategory;
  final ValueChanged<AdminSupportConversation> onOpenConversation;

  @override
  Widget build(BuildContext context) {
    if (state.isLoading && state.conversations.isEmpty) {
      return const AppLoadingView();
    }
    if (state.error != null && state.conversations.isEmpty) {
      return AppErrorView(error: state.error!, onRetry: onRefresh);
    }
    final visible = state.visibleConversations;
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification.metrics.extentAfter < 420 &&
              state.hasMore &&
              !state.isLoadingMore) {
            onLoadMore();
          }
          return false;
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 820),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _InboxSummary(state: state),
                    const SizedBox(height: 16),
                    _InboxFilters(
                      state: state,
                      onSearch: onSearch,
                      onStatus: onStatus,
                      onCategory: onCategory,
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            adminSupportText(
                              context,
                              'admin.support.inbox.conversations',
                              fa: 'گفت‌وگوها',
                              en: 'Conversations',
                            ),
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        Text(
                          AppFormat.number(context, visible.length),
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(color: AppColors.ink500),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (visible.isEmpty)
                      Card(
                        child: EmptyState(
                          icon: Icons.inbox_outlined,
                          message: state.searchQuery.trim().isNotEmpty
                              ? adminSupportText(
                                  context,
                                  'admin.support.inbox.noSearchResults',
                                  fa: 'گفت‌وگویی با این جست‌وجو پیدا نشد.',
                                  en: 'No conversation matches this search.',
                                )
                              : adminSupportText(
                                  context,
                                  'admin.support.inbox.empty',
                                  fa: 'گفت‌وگویی برای این فیلتر وجود ندارد.',
                                  en: 'No conversations match these filters.',
                                ),
                        ),
                      )
                    else
                      ...visible.map(
                        (conversation) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _AdminConversationCard(
                            conversation: conversation,
                            onTap: () => onOpenConversation(conversation),
                          ),
                        ),
                      ),
                    if (state.paginationError != null)
                      AppErrorView(
                        error: state.paginationError!,
                        onRetry: onLoadMore,
                        compact: true,
                      )
                    else if (state.isLoadingMore)
                      const AppLoadingView(compact: true)
                    else if (state.hasMore)
                      Center(
                        child: OutlinedButton.icon(
                          onPressed: onLoadMore,
                          icon: const Icon(Icons.expand_more_rounded),
                          label: Text(
                            adminSupportText(
                              context,
                              'admin.support.inbox.loadMore',
                              fa: 'گفت‌وگوهای بیشتر',
                              en: 'Load more conversations',
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InboxSummary extends StatelessWidget {
  const _InboxSummary({required this.state});

  final AdminSupportInboxState state;

  @override
  Widget build(BuildContext context) {
    final connected =
        state.realtimeState == SupportRealtimeConnectionState.connected;
    final connecting =
        state.realtimeState == SupportRealtimeConnectionState.connecting ||
        state.realtimeState == SupportRealtimeConnectionState.reconnecting;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[AppColors.inverse, AppColors.brand800],
        ),
        borderRadius: BorderRadius.circular(AppTheme.panelRadius),
      ),
      child: Wrap(
        spacing: 16,
        runSpacing: 14,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.support_agent_rounded, color: Colors.white),
          ),
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 180, maxWidth: 460),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  adminSupportText(
                    context,
                    'admin.support.inbox.subtitle',
                    fa: 'پاسخ‌گویی عملیاتی به کاربران',
                    en: 'Operational customer support',
                  ),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  state.unreadMessages > 0
                      ? adminSupportText(
                          context,
                          'admin.support.inbox.unread',
                          fa: '{count} پیام خوانده‌نشده در صف است.',
                          en: '{count} unread messages are waiting.',
                          values: <String, Object?>{
                            'count': AppFormat.number(
                              context,
                              state.unreadMessages,
                            ),
                          },
                        )
                      : adminSupportText(
                          context,
                          'admin.support.inbox.caughtUp',
                          fa: 'پیام خوانده‌نشده‌ای در صف نیست.',
                          en: 'There are no unread messages in the queue.',
                        ),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: .78),
                  ),
                ),
              ],
            ),
          ),
          AppStatusBadge(
            label: connected
                ? context.l10n.tr('common.online')
                : connecting
                ? adminSupportText(
                    context,
                    'admin.support.realtime.reconnecting',
                    fa: 'در حال اتصال',
                    en: 'Connecting',
                  )
                : context.l10n.tr('common.offline'),
            color: connected
                ? AppColors.success
                : connecting
                ? AppColors.warning
                : AppColors.ink500,
            backgroundAlpha: .18,
            borderAlpha: .4,
            textStyle: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _InboxFilters extends StatelessWidget {
  const _InboxFilters({
    required this.state,
    required this.onSearch,
    required this.onStatus,
    required this.onCategory,
  });

  final AdminSupportInboxState state;
  final ValueChanged<String> onSearch;
  final Future<void> Function(SupportConversationStatus?) onStatus;
  final Future<void> Function(String?) onCategory;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              onChanged: onSearch,
              textDirection: state.searchQuery.trim().isEmpty
                  ? Directionality.of(context)
                  : firstStrongTextDirection(state.searchQuery),
              textAlign: TextAlign.start,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search_rounded),
                labelText: adminSupportText(
                  context,
                  'admin.support.inbox.search',
                  fa: 'جست‌وجوی عنوان، کاربر یا متن پیام',
                  en: 'Search title, customer, or message',
                ),
              ),
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _StatusFilterChip(
                    label: adminSupportText(
                      context,
                      'admin.support.inbox.allStatuses',
                      fa: 'همه وضعیت‌ها',
                      en: 'All statuses',
                    ),
                    selected: state.statusFilter == null,
                    onSelected: () => onStatus(null),
                  ),
                  for (final status in SupportConversationStatus.values)
                    if (status != SupportConversationStatus.unknown) ...[
                      const SizedBox(width: 7),
                      _StatusFilterChip(
                        label: supportStatusLabel(context, status),
                        selected: state.statusFilter == status,
                        onSelected: () => onStatus(status),
                      ),
                    ],
                ],
              ),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              key: ValueKey(state.categoryFilter),
              initialValue: state.categoryFilter ?? '',
              decoration: InputDecoration(
                labelText: context.l10n.tr('support.category'),
              ),
              items: <DropdownMenuItem<String>>[
                DropdownMenuItem<String>(
                  value: '',
                  child: Text(
                    adminSupportText(
                      context,
                      'admin.support.inbox.allCategories',
                      fa: 'همه موضوع‌ها',
                      en: 'All categories',
                    ),
                  ),
                ),
                for (final category in supportCategories)
                  DropdownMenuItem<String>(
                    value: category,
                    child: Text(supportCategoryLabel(context, category)),
                  ),
              ],
              onChanged: onCategory,
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusFilterChip extends StatelessWidget {
  const _StatusFilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
    );
  }
}

class _AdminConversationCard extends StatelessWidget {
  const _AdminConversationCard({
    required this.conversation,
    required this.onTap,
  });

  final AdminSupportConversation conversation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final owner = conversation.owner;
    final ownerName = switch (owner.type) {
      AdminSupportOwnerType.anonymous => adminSupportText(
        context,
        'admin.support.owner.anonymous',
        fa: 'کاربر مهمان',
        en: 'Guest customer',
      ),
      AdminSupportOwnerType.user =>
        owner.fullName ?? owner.email ?? '#${owner.userId ?? '-'}',
      AdminSupportOwnerType.unknown => adminSupportText(
        context,
        'admin.support.owner.unknown',
        fa: 'کاربر ناشناخته',
        en: 'Unknown customer',
      ),
    };
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
                  CircleAvatar(
                    backgroundColor: AppColors.brand50,
                    foregroundColor: AppColors.brand700,
                    child: Icon(switch (owner.type) {
                      AdminSupportOwnerType.anonymous =>
                        Icons.person_outline_rounded,
                      AdminSupportOwnerType.user => Icons.person_rounded,
                      AdminSupportOwnerType.unknown =>
                        Icons.help_outline_rounded,
                    }),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        FirstStrongText(
                          conversation.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 3),
                        FirstStrongText(
                          ownerName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppColors.ink500),
                        ),
                      ],
                    ),
                  ),
                  if (conversation.unreadCount > 0)
                    Container(
                      constraints: const BoxConstraints(minWidth: 24),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.brand600,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        conversation.unreadCount > 99
                            ? '${AppFormat.number(context, 99)}+'
                            : AppFormat.number(
                                context,
                                conversation.unreadCount,
                              ),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SupportStatusChip(status: conversation.status),
                  if (conversation.category != null)
                    Chip(
                      visualDensity: VisualDensity.compact,
                      label: Text(
                        supportCategoryLabel(context, conversation.category!),
                      ),
                    ),
                  if (conversation.isAssignedToCurrentAdmin)
                    AppStatusBadge(
                      label: adminSupportText(
                        context,
                        'admin.support.assignment.mine',
                        fa: 'در اختیار من',
                        en: 'Assigned to me',
                      ),
                      color: AppColors.info,
                    )
                  else if (conversation.isAssigned)
                    AppStatusBadge(
                      label: adminSupportText(
                        context,
                        'admin.support.assignment.other',
                        fa: 'در اختیار همکار',
                        en: 'Assigned to another Admin',
                      ),
                      color: AppColors.ink500,
                    ),
                ],
              ),
              if (conversation.lastMessage case final lastMessage?) ...[
                const SizedBox(height: 12),
                FirstStrongText(
                  lastMessage.preview,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.ink600,
                    height: 1.5,
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Directionality(
                textDirection: TextDirection.ltr,
                child: Text(
                  AppFormat.dateTime(context, conversation.updatedAt),
                  textAlign: TextAlign.end,
                  style: Theme.of(
                    context,
                  ).textTheme.labelSmall?.copyWith(color: AppColors.ink500),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
