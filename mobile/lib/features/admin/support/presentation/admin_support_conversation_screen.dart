import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/network/error_presenter.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/app_format.dart';
import '../../../../core/widgets/app_status_badge.dart';
import '../../../../core/widgets/async_states.dart';
import '../../../support/data/support_models.dart';
import '../../../support/presentation/support_presentation_helpers.dart';
import '../../../support/realtime/support_realtime_service.dart';
import '../application/admin_support_conversation_controller.dart';
import '../application/admin_support_providers.dart';
import '../data/admin_support_models.dart';
import 'admin_support_quick_replies_sheet.dart';
import 'admin_support_text.dart';

enum _ConversationMenuAction { editTitle, timeline, resolve, close }

class AdminSupportConversationScreen extends ConsumerStatefulWidget {
  const AdminSupportConversationScreen({
    super.key,
    required this.conversationId,
  });

  final String conversationId;

  @override
  ConsumerState<AdminSupportConversationScreen> createState() =>
      _AdminSupportConversationScreenState();
}

class _AdminSupportConversationScreenState
    extends ConsumerState<AdminSupportConversationScreen> {
  final _composerController = TextEditingController();
  final _composerFocusNode = FocusNode();
  final _scrollController = ScrollController();
  late final AppLifecycleListener _lifecycleListener;

  @override
  void initState() {
    super.initState();
    _lifecycleListener = AppLifecycleListener(
      onPause: () => ref
          .read(
            adminSupportConversationControllerProvider(
              widget.conversationId,
            ).notifier,
          )
          .onAppPaused(),
      onResume: () => unawaited(
        ref
            .read(
              adminSupportConversationControllerProvider(
                widget.conversationId,
              ).notifier,
            )
            .onAppResumed(),
      ),
    );
  }

  @override
  void dispose() {
    _lifecycleListener.dispose();
    _composerController.dispose();
    _composerFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToLatest() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final target = _scrollController.position.maxScrollExtent;
      if (MediaQuery.disableAnimationsOf(context)) {
        _scrollController.jumpTo(target);
      } else {
        unawaited(
          _scrollController.animateTo(
            target,
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOut,
          ),
        );
      }
    });
  }

  Future<void> _useQuickReply() async {
    final content = await showAdminSupportQuickRepliesSheet(
      context,
      allowSelection: true,
    );
    if (content == null || !mounted) return;
    _setComposerDraft(content);
  }

  void _setComposerDraft(String content) {
    _composerController.value = TextEditingValue(
      text: content,
      selection: TextSelection.collapsed(offset: content.length),
    );
    _composerFocusNode.requestFocus();
  }

  Future<void> _send(AdminSupportConversationController controller) async {
    final sent = await controller.send(_composerController.text);
    if (sent && mounted) {
      _composerController.clear();
      _scrollToLatest();
    }
  }

  Future<void> _retry(
    AdminSupportConversationController controller,
    String content,
  ) async {
    final sent = await controller.retryFailedSend();
    if (sent && mounted) {
      if (_composerController.text.trim() == content) {
        _composerController.clear();
      }
      _scrollToLatest();
    }
  }

  Future<void> _editTitle(
    AdminSupportConversationController controller,
    String currentTitle,
  ) async {
    final textController = TextEditingController(text: currentTitle);
    final title = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          adminSupportText(
            context,
            'admin.support.conversation.editTitle',
            fa: 'ویرایش عنوان گفت‌وگو',
            en: 'Edit conversation title',
          ),
        ),
        content: ValueListenableBuilder<TextEditingValue>(
          valueListenable: textController,
          builder: (context, value, _) => TextField(
            controller: textController,
            maxLength: 160,
            autofocus: true,
            textDirection: value.text.trim().isEmpty
                ? Directionality.of(context)
                : firstStrongTextDirection(value.text),
            textAlign: TextAlign.start,
            decoration: InputDecoration(
              labelText: adminSupportText(
                context,
                'admin.support.conversation.titleField',
                fa: 'عنوان',
                en: 'Title',
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(context.l10n.tr('action.cancel')),
          ),
          FilledButton(
            onPressed: () {
              final normalized = textController.text.trim();
              if (normalized.isNotEmpty) {
                Navigator.pop(dialogContext, normalized);
              }
            },
            child: Text(context.l10n.tr('action.save')),
          ),
        ],
      ),
    );
    textController.dispose();
    if (title != null && mounted) await controller.updateTitle(title);
  }

  Future<void> _confirmLifecycle(
    AdminSupportConversationController controller,
    _ConversationMenuAction action,
  ) async {
    final resolving = action == _ConversationMenuAction.resolve;
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(
              resolving
                  ? adminSupportText(
                      context,
                      'admin.support.conversation.resolveTitle',
                      fa: 'حل‌شده علامت‌گذاری شود؟',
                      en: 'Mark as resolved?',
                    )
                  : adminSupportText(
                      context,
                      'admin.support.conversation.closeTitle',
                      fa: 'گفت‌وگو بسته شود؟',
                      en: 'Close conversation?',
                    ),
            ),
            content: Text(
              resolving
                  ? adminSupportText(
                      context,
                      'admin.support.conversation.resolveConfirm',
                      fa: 'وضعیت برای همه شرکت‌کنندگان به حل‌شده تغییر می‌کند.',
                      en: 'All participants will see this as resolved.',
                    )
                  : adminSupportText(
                      context,
                      'admin.support.conversation.closeConfirm',
                      fa: 'گفت‌وگوی بسته دیگر پیام جدید نمی‌پذیرد.',
                      en: 'A closed conversation no longer accepts messages.',
                    ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text(context.l10n.tr('action.cancel')),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(context.l10n.tr('action.confirm')),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !mounted) return;
    if (resolving) {
      await controller.resolve();
    } else {
      await controller.close();
    }
  }

  void _showTimeline() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) =>
          _ConversationTimelineSheet(conversationId: widget.conversationId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = adminSupportConversationControllerProvider(
      widget.conversationId,
    );
    final state = ref.watch(provider);
    final controller = ref.read(provider.notifier);

    ref.listen<Object?>(provider.select((value) => value.actionError), (
      previous,
      next,
    ) {
      if (next == null || identical(previous, next)) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(presentError(context, next))));
      controller.clearActionError();
    });
    ref.listen<int>(provider.select((value) => value.messages.length), (
      previous,
      next,
    ) {
      if (previous != null && next > previous) _scrollToLatest();
    });

    final conversation = state.conversation;
    final conversationTitle =
        conversation?.title ??
        adminSupportText(
          context,
          'admin.support.conversation.title',
          fa: 'گفت‌وگوی پشتیبانی',
          en: 'Support conversation',
        );
    return Scaffold(
      appBar: AppBar(
        title: Directionality(
          textDirection: firstStrongTextDirection(conversationTitle),
          child: Text(
            conversationTitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        actions: [
          if (state.isReconciling)
            const Padding(
              padding: EdgeInsets.all(14),
              child: SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              tooltip: context.l10n.tr('action.refresh'),
              onPressed: () => controller.reconcile(reportError: true),
              icon: const Icon(Icons.refresh_rounded),
            ),
          PopupMenuButton<_ConversationMenuAction>(
            onSelected: (action) async {
              switch (action) {
                case _ConversationMenuAction.editTitle:
                  if (conversation != null) {
                    await _editTitle(controller, conversation.title);
                  }
                case _ConversationMenuAction.timeline:
                  _showTimeline();
                case _ConversationMenuAction.resolve:
                case _ConversationMenuAction.close:
                  await _confirmLifecycle(controller, action);
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: _ConversationMenuAction.editTitle,
                enabled: conversation != null && !state.isUpdatingTitle,
                child: _MenuRow(
                  icon: Icons.edit_outlined,
                  label: adminSupportText(
                    context,
                    'admin.support.conversation.editTitle',
                    fa: 'ویرایش عنوان',
                    en: 'Edit title',
                  ),
                ),
              ),
              PopupMenuItem(
                value: _ConversationMenuAction.timeline,
                child: _MenuRow(
                  icon: Icons.history_rounded,
                  label: adminSupportText(
                    context,
                    'admin.support.conversation.timeline',
                    fa: 'تاریخچه رویدادها',
                    en: 'Event history',
                  ),
                ),
              ),
              PopupMenuItem(
                value: _ConversationMenuAction.resolve,
                enabled: state.canResolve,
                child: _MenuRow(
                  icon: Icons.check_circle_outline_rounded,
                  label: adminSupportText(
                    context,
                    'admin.support.conversation.resolve',
                    fa: 'حل‌شده',
                    en: 'Resolve',
                  ),
                ),
              ),
              PopupMenuItem(
                value: _ConversationMenuAction.close,
                enabled: state.canClose,
                child: _MenuRow(
                  icon: Icons.lock_outline_rounded,
                  label: adminSupportText(
                    context,
                    'admin.support.conversation.close',
                    fa: 'بستن گفت‌وگو',
                    en: 'Close conversation',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      body: state.isLoading && conversation == null
          ? const AppLoadingView()
          : state.error != null && conversation == null
          ? AppErrorView(error: state.error!, onRetry: controller.reload)
          : conversation == null
          ? EmptyState(
              icon: Icons.forum_outlined,
              message: context.l10n.tr('common.empty'),
            )
          : LayoutBuilder(
              builder: (context, constraints) => Column(
                children: [
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: () => controller.reconcile(reportError: true),
                      child: ListView(
                        controller: _scrollController,
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                        children: [
                          Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 760),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _ConversationHeader(
                                    state: state,
                                    onClaim: controller.claim,
                                  ),
                                  if (conversation.aiHandoffSummary != null ||
                                      conversation.aiHandoffReason != null) ...[
                                    const SizedBox(height: 10),
                                    _AiHandoffCard(conversation: conversation),
                                  ],
                                  const SizedBox(height: 16),
                                  if (state.hasMoreMessages ||
                                      state.messagePaginationError != null)
                                    Center(
                                      child:
                                          state.messagePaginationError != null
                                          ? TextButton.icon(
                                              onPressed:
                                                  controller.loadOlderMessages,
                                              icon: const Icon(
                                                Icons.refresh_rounded,
                                              ),
                                              label: Text(
                                                context.l10n.tr('action.retry'),
                                              ),
                                            )
                                          : OutlinedButton.icon(
                                              onPressed:
                                                  state.isLoadingOlderMessages
                                                  ? null
                                                  : controller
                                                        .loadOlderMessages,
                                              icon: state.isLoadingOlderMessages
                                                  ? const SizedBox.square(
                                                      dimension: 16,
                                                      child:
                                                          CircularProgressIndicator(
                                                            strokeWidth: 2,
                                                          ),
                                                    )
                                                  : const Icon(
                                                      Icons.expand_less_rounded,
                                                    ),
                                              label: Text(
                                                adminSupportText(
                                                  context,
                                                  'admin.support.conversation.olderMessages',
                                                  fa: 'پیام‌های قدیمی‌تر',
                                                  en: 'Older messages',
                                                ),
                                              ),
                                            ),
                                    ),
                                  const SizedBox(height: 10),
                                  if (state.messages.isEmpty)
                                    EmptyState(
                                      icon: Icons.chat_bubble_outline_rounded,
                                      message: adminSupportText(
                                        context,
                                        'admin.support.conversation.noMessages',
                                        fa: 'هنوز پیامی در این گفت‌وگو نیست.',
                                        en: 'There are no messages yet.',
                                      ),
                                    )
                                  else
                                    for (final message in state.messages)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 14,
                                        ),
                                        child: _AdminMessageBubble(
                                          message: message,
                                        ),
                                      ),
                                  if (state.pendingSend case final pending?)
                                    _PendingAdminMessageBubble(
                                      pending: pending,
                                      onRetry: () =>
                                          _retry(controller, pending.content),
                                      onDiscard: controller.discardFailedSend,
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight:
                          constraints.maxHeight *
                          (constraints.maxHeight >= 500 ? .68 : .62),
                    ),
                    child: _ConversationComposer(
                      state: state,
                      textController: _composerController,
                      focusNode: _composerFocusNode,
                      onSend: () => _send(controller),
                      onQuickReply: _useQuickReply,
                      onSuggest: controller.generateSuggestedReply,
                      onUseSuggestion: () {
                        final suggestion = state.suggestedReply;
                        if (suggestion == null) return;
                        _setComposerDraft(suggestion.draft);
                        controller.dismissSuggestedReply();
                      },
                      onDismissSuggestion: controller.dismissSuggestedReply,
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [Icon(icon, size: 19), const SizedBox(width: 10), Text(label)],
    );
  }
}

class _ConversationHeader extends StatelessWidget {
  const _ConversationHeader({required this.state, required this.onClaim});

  final AdminSupportConversationState state;
  final Future<void> Function() onClaim;

  @override
  Widget build(BuildContext context) {
    final conversation = state.conversation!;
    final owner = conversation.owner;
    final ownerTitle = switch (owner.type) {
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
    final connected =
        state.realtimeState == SupportRealtimeConnectionState.connected;
    return Card(
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
                    AdminSupportOwnerType.unknown => Icons.help_outline_rounded,
                  }),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      FirstStrongText(
                        ownerTitle,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      if (owner.email != null) ...[
                        const SizedBox(height: 2),
                        Directionality(
                          textDirection: TextDirection.ltr,
                          child: SelectableText(
                            owner.email!,
                            textAlign: TextAlign.start,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: AppColors.ink500),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(
                  connected ? Icons.wifi_rounded : Icons.wifi_off_rounded,
                  size: 18,
                  color: connected ? AppColors.success : AppColors.ink500,
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 7,
              runSpacing: 7,
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
                  ),
              ],
            ),
            if (state.canClaim) ...[
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: state.isClaiming ? null : onClaim,
                icon: state.isClaiming
                    ? const SizedBox.square(
                        dimension: 17,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.assignment_ind_outlined),
                label: Text(
                  adminSupportText(
                    context,
                    'admin.support.conversation.claim',
                    fa: 'پذیرش و شروع پاسخ‌گویی',
                    en: 'Claim and start replying',
                  ),
                ),
              ),
            ] else if (conversation.isAssigned &&
                !conversation.isAssignedToCurrentAdmin) ...[
              const SizedBox(height: 12),
              Text(
                adminSupportText(
                  context,
                  'admin.support.assignment.otherHint',
                  fa: 'این گفت‌وگو در اختیار مدیر دیگری است.',
                  en: 'This conversation is assigned to another Admin.',
                ),
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.warning),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AiHandoffCard extends StatelessWidget {
  const _AiHandoffCard({required this.conversation});

  final AdminSupportConversation conversation;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.brand50,
        borderRadius: BorderRadius.circular(AppTheme.controlRadius),
        border: Border.all(color: AppColors.brand100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.auto_awesome_rounded,
                size: 18,
                color: AppColors.brand700,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  adminSupportText(
                    context,
                    'admin.support.conversation.aiHandoff',
                    fa: 'خلاصه تحویل از دستیار هوشمند',
                    en: 'AI handoff summary',
                  ),
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(color: AppColors.brand800),
                ),
              ),
            ],
          ),
          if (conversation.aiHandoffReason case final reason?) ...[
            const SizedBox(height: 8),
            FirstStrongText(reason),
          ],
          if (conversation.aiHandoffSummary case final summary?) ...[
            const SizedBox(height: 8),
            Directionality(
              textDirection: firstStrongTextDirection(summary),
              child: SelectableText(summary, textAlign: TextAlign.start),
            ),
          ],
        ],
      ),
    );
  }
}

class _AdminMessageBubble extends StatelessWidget {
  const _AdminMessageBubble({required this.message});

  final SupportMessage message;

  @override
  Widget build(BuildContext context) {
    final mine = message.senderType == SupportParticipantType.admin;
    final background = mine ? AppColors.brand700 : Colors.white;
    final foreground = mine ? Colors.white : AppColors.ink900;
    final icon = switch (message.senderType) {
      SupportParticipantType.user => Icons.person_outline_rounded,
      SupportParticipantType.ai => Icons.smart_toy_outlined,
      SupportParticipantType.admin => Icons.support_agent_rounded,
      SupportParticipantType.unknown => Icons.help_outline_rounded,
    };
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Align(
        alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: .88,
          alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
          child: Column(
            crossAxisAlignment: mine
                ? CrossAxisAlignment.end
                : CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 14, color: AppColors.ink500),
                    const SizedBox(width: 5),
                    Text(
                      supportSenderLabel(context, message.senderType),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.ink500,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 5),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 15,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: background,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(18),
                    topRight: const Radius.circular(18),
                    bottomLeft: Radius.circular(mine ? 18 : 5),
                    bottomRight: Radius.circular(mine ? 5 : 18),
                  ),
                  border: mine ? null : Border.all(color: AppColors.border),
                ),
                child: Directionality(
                  textDirection: firstStrongTextDirection(message.content),
                  child: SelectableText(
                    message.content,
                    textAlign: TextAlign.start,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: foreground,
                      height: 1.65,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                AppFormat.dateTime(context, message.createdAt),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.ink500,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PendingAdminMessageBubble extends StatelessWidget {
  const _PendingAdminMessageBubble({
    required this.pending,
    required this.onRetry,
    required this.onDiscard,
  });

  final AdminPendingSupportSend pending;
  final Future<void> Function() onRetry;
  final VoidCallback onDiscard;

  @override
  Widget build(BuildContext context) {
    final failed = pending.status == AdminPendingSendStatus.failed;
    return Align(
      alignment: AlignmentDirectional.centerEnd,
      child: FractionallySizedBox(
        widthFactor: .88,
        alignment: AlignmentDirectional.centerEnd,
        child: Card(
          color: failed ? const Color(0xFFFFF3F5) : AppColors.brand50,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FirstStrongText(pending.content),
                const SizedBox(height: 10),
                if (failed)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.end,
                    children: [
                      TextButton(
                        onPressed: onDiscard,
                        child: Text(context.l10n.tr('action.cancel')),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: onRetry,
                        icon: const Icon(Icons.refresh_rounded),
                        label: Text(context.l10n.tr('action.retry')),
                      ),
                    ],
                  )
                else
                  const Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
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

class _ConversationComposer extends StatelessWidget {
  const _ConversationComposer({
    required this.state,
    required this.textController,
    required this.focusNode,
    required this.onSend,
    required this.onQuickReply,
    required this.onSuggest,
    required this.onUseSuggestion,
    required this.onDismissSuggestion,
  });

  final AdminSupportConversationState state;
  final TextEditingController textController;
  final FocusNode focusNode;
  final Future<void> Function() onSend;
  final Future<void> Function() onQuickReply;
  final Future<void> Function() onSuggest;
  final VoidCallback onUseSuggestion;
  final VoidCallback onDismissSuggestion;

  @override
  Widget build(BuildContext context) {
    final conversation = state.conversation!;
    Widget? blocked;
    if (conversation.status == SupportConversationStatus.closed) {
      blocked = _ComposerNotice(
        icon: Icons.lock_outline_rounded,
        message: adminSupportText(
          context,
          'admin.support.conversation.closedNotice',
          fa: 'این گفت‌وگو بسته است و پیام جدید نمی‌پذیرد.',
          en: 'This conversation is closed and cannot accept messages.',
        ),
      );
    } else if (conversation.status == SupportConversationStatus.resolved) {
      blocked = _ComposerNotice(
        icon: Icons.check_circle_outline_rounded,
        message: adminSupportText(
          context,
          'admin.support.conversation.resolvedNotice',
          fa: 'گفت‌وگو حل شده است. در صورت نیاز آن را ببندید.',
          en: 'This conversation is resolved. Close it when appropriate.',
        ),
      );
    } else if (conversation.status ==
        SupportConversationStatus.waitingForAdmin) {
      blocked = _ComposerNotice(
        icon: Icons.assignment_ind_outlined,
        message: adminSupportText(
          context,
          'admin.support.conversation.claimBeforeReply',
          fa: 'پیش از پاسخ‌گویی، گفت‌وگو را بپذیرید.',
          en: 'Claim the conversation before replying.',
        ),
      );
    } else if (!conversation.isAssignedToCurrentAdmin) {
      blocked = _ComposerNotice(
        icon: Icons.person_off_outlined,
        message: adminSupportText(
          context,
          'admin.support.assignment.otherHint',
          fa: 'این گفت‌وگو در اختیار مدیر دیگری است.',
          en: 'This conversation is assigned to another Admin.',
        ),
      );
    }

    return Material(
      elevation: 10,
      color: Colors.white,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child:
                  blocked ??
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Flexible(
                        fit: FlexFit.loose,
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (state.suggestedReply
                                  case final suggestion?) ...[
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppColors.brand50,
                                    borderRadius: BorderRadius.circular(
                                      AppTheme.controlRadius,
                                    ),
                                    border: Border.all(
                                      color: AppColors.brand100,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Row(
                                        children: [
                                          const Icon(
                                            Icons.auto_awesome_rounded,
                                            size: 18,
                                            color: AppColors.brand700,
                                          ),
                                          const SizedBox(width: 7),
                                          Expanded(
                                            child: Text(
                                              adminSupportText(
                                                context,
                                                'admin.support.suggestion.title',
                                                fa: 'پیشنهاد دستیار هوشمند',
                                                en: 'AI reply suggestion',
                                              ),
                                              style: Theme.of(
                                                context,
                                              ).textTheme.titleSmall,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      FirstStrongText(
                                        suggestion.draft,
                                        maxLines: 4,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        adminSupportText(
                                          context,
                                          'admin.support.suggestion.neverAutoSend',
                                          fa: 'این متن خودکار ارسال نمی‌شود.',
                                          en: 'This draft is never sent automatically.',
                                        ),
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelSmall
                                            ?.copyWith(color: AppColors.ink500),
                                      ),
                                      Wrap(
                                        alignment: WrapAlignment.end,
                                        spacing: 8,
                                        runSpacing: 4,
                                        children: [
                                          TextButton(
                                            onPressed: onDismissSuggestion,
                                            child: Text(
                                              context.l10n.tr('action.cancel'),
                                            ),
                                          ),
                                          FilledButton.tonal(
                                            onPressed: onUseSuggestion,
                                            child: Text(
                                              adminSupportText(
                                                context,
                                                'admin.support.suggestion.useDraft',
                                                fa: 'انتقال به ویرایشگر',
                                                en: 'Use as editable draft',
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 8),
                              ],
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: state.pendingSend == null
                                          ? onQuickReply
                                          : null,
                                      icon: const Icon(
                                        Icons.quickreply_outlined,
                                      ),
                                      label: Text(
                                        adminSupportText(
                                          context,
                                          'admin.support.quickReplies.use',
                                          fa: 'پاسخ آماده',
                                          en: 'Quick reply',
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed:
                                          state.isSuggesting ||
                                              state.pendingSend != null
                                          ? null
                                          : onSuggest,
                                      icon: state.isSuggesting
                                          ? const SizedBox.square(
                                              dimension: 16,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                            )
                                          : const Icon(
                                              Icons.auto_awesome_rounded,
                                            ),
                                      label: Text(
                                        adminSupportText(
                                          context,
                                          'admin.support.suggestion.generate',
                                          fa: 'پیشنهاد پاسخ',
                                          en: 'Suggest reply',
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      ValueListenableBuilder<TextEditingValue>(
                        valueListenable: textController,
                        builder: (context, value, _) => Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              child: TextField(
                                controller: textController,
                                focusNode: focusNode,
                                enabled: state.pendingSend == null,
                                minLines: 1,
                                maxLines: 5,
                                maxLength: 4000,
                                textCapitalization:
                                    TextCapitalization.sentences,
                                textDirection: value.text.trim().isEmpty
                                    ? Directionality.of(context)
                                    : firstStrongTextDirection(value.text),
                                textAlign: TextAlign.start,
                                decoration: InputDecoration(
                                  hintText: context.l10n.tr(
                                    'support.placeholder',
                                  ),
                                  counterText: '',
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton.filled(
                              tooltip: context.l10n.tr('action.send'),
                              onPressed:
                                  state.canSend && value.text.trim().isNotEmpty
                                  ? onSend
                                  : null,
                              icon: const Icon(Icons.send_rounded),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ComposerNotice extends StatelessWidget {
  const _ComposerNotice({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.ink500),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            message,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.ink600),
          ),
        ),
      ],
    );
  }
}

class _ConversationTimelineSheet extends ConsumerWidget {
  const _ConversationTimelineSheet({required this.conversationId});

  final String conversationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = adminSupportConversationControllerProvider(conversationId);
    final state = ref.watch(provider);
    final controller = ref.read(provider.notifier);
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * .82,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 10, 8, 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    adminSupportText(
                      context,
                      'admin.support.conversation.timeline',
                      fa: 'تاریخچه رویدادها',
                      en: 'Event history',
                    ),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  tooltip: context.l10n.tr('action.close'),
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: state.eventsError != null && state.events.isEmpty
                ? AppErrorView(
                    error: state.eventsError!,
                    onRetry: () => controller.reconcile(reportError: true),
                  )
                : state.events.isEmpty
                ? EmptyState(
                    icon: Icons.history_rounded,
                    message: context.l10n.tr('common.empty'),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount:
                        state.events.length +
                        (state.hasMoreEvents ||
                                state.eventPaginationError != null
                            ? 1
                            : 0),
                    separatorBuilder: (_, _) => const Divider(height: 20),
                    itemBuilder: (context, index) {
                      if (index == state.events.length) {
                        return Center(
                          child: state.eventPaginationError != null
                              ? OutlinedButton.icon(
                                  onPressed: controller.loadOlderEvents,
                                  icon: const Icon(Icons.refresh_rounded),
                                  label: Text(context.l10n.tr('action.retry')),
                                )
                              : OutlinedButton.icon(
                                  onPressed: state.isLoadingOlderEvents
                                      ? null
                                      : controller.loadOlderEvents,
                                  icon: state.isLoadingOlderEvents
                                      ? const SizedBox.square(
                                          dimension: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(Icons.expand_more_rounded),
                                  label: Text(
                                    adminSupportText(
                                      context,
                                      'admin.support.conversation.olderEvents',
                                      fa: 'رویدادهای قدیمی‌تر',
                                      en: 'Older events',
                                    ),
                                  ),
                                ),
                        );
                      }
                      return _EventTile(event: state.events[index]);
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _EventTile extends StatelessWidget {
  const _EventTile({required this.event});

  final AdminSupportConversationEvent event;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: const BoxDecoration(
            color: AppColors.muted,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.history_rounded, size: 17),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _eventLabel(context, event.eventType),
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 3),
              Text(
                event.actorType,
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(color: AppColors.ink500),
              ),
              if (event.details case final details?) ...[
                const SizedBox(height: 6),
                FirstStrongText(details),
              ],
              const SizedBox(height: 5),
              Text(
                AppFormat.dateTime(context, event.occurredAt),
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(color: AppColors.ink500),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

String _eventLabel(BuildContext context, String eventType) {
  return switch (eventType) {
    'ConversationCreated' => adminSupportText(
      context,
      'admin.support.event.created',
      fa: 'گفت‌وگو ایجاد شد',
      en: 'Conversation created',
    ),
    'AdminHandoffRequested' => adminSupportText(
      context,
      'admin.support.event.handoff',
      fa: 'درخواست پشتیبان انسانی',
      en: 'Human support requested',
    ),
    'AdminClaimed' => adminSupportText(
      context,
      'admin.support.event.claimed',
      fa: 'گفت‌وگو پذیرفته شد',
      en: 'Conversation claimed',
    ),
    'Resolved' || 'AiResolved' => adminSupportText(
      context,
      'admin.support.event.resolved',
      fa: 'گفت‌وگو حل شد',
      en: 'Conversation resolved',
    ),
    'Reopened' => adminSupportText(
      context,
      'admin.support.event.reopened',
      fa: 'گفت‌وگو دوباره باز شد',
      en: 'Conversation reopened',
    ),
    'Closed' => adminSupportText(
      context,
      'admin.support.event.closed',
      fa: 'گفت‌وگو بسته شد',
      en: 'Conversation closed',
    ),
    'TitleChanged' || 'AiTitleGenerated' => adminSupportText(
      context,
      'admin.support.event.titleChanged',
      fa: 'عنوان تغییر کرد',
      en: 'Title changed',
    ),
    'AiEscalated' => adminSupportText(
      context,
      'admin.support.event.aiEscalated',
      fa: 'دستیار هوشمند گفت‌وگو را ارجاع داد',
      en: 'AI escalated the conversation',
    ),
    'AiProcessingFailed' => adminSupportText(
      context,
      'admin.support.event.aiFailed',
      fa: 'پردازش دستیار هوشمند ناموفق بود',
      en: 'AI processing failed',
    ),
    _ => eventType,
  };
}
