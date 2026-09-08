import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/network/error_presenter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/app_format.dart';
import '../../../core/widgets/async_states.dart';
import '../application/support_conversation_controller.dart';
import '../application/support_providers.dart';
import '../data/support_models.dart';
import '../realtime/support_realtime_service.dart';
import 'support_presentation_helpers.dart';

class SupportConversationScreen extends ConsumerStatefulWidget {
  const SupportConversationScreen({super.key, required this.conversationId});

  final String conversationId;

  @override
  ConsumerState<SupportConversationScreen> createState() =>
      _SupportConversationScreenState();
}

class _SupportConversationScreenState
    extends ConsumerState<SupportConversationScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _composerController = TextEditingController();
  final FocusNode _composerFocus = FocusNode();
  late final AppLifecycleListener _lifecycleListener;
  bool _initialScrollCompleted = false;

  @override
  void initState() {
    super.initState();
    _lifecycleListener = AppLifecycleListener(
      onPause: () => ref
          .read(
            supportConversationControllerProvider(
              widget.conversationId,
            ).notifier,
          )
          .onAppPaused(),
      onResume: () => unawaited(
        ref
            .read(
              supportConversationControllerProvider(
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
    _scrollController.dispose();
    _composerController.dispose();
    _composerFocus.dispose();
    super.dispose();
  }

  bool get _nearBottom {
    if (!_scrollController.hasClients) {
      return true;
    }
    return _scrollController.position.maxScrollExtent -
            _scrollController.offset <
        120;
  }

  void _scrollToBottom({bool animate = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) {
        return;
      }
      final target = _scrollController.position.maxScrollExtent;
      if (animate && !MediaQuery.disableAnimationsOf(context)) {
        unawaited(
          _scrollController.animateTo(
            target,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
          ),
        );
      } else {
        _scrollController.jumpTo(target);
      }
    });
  }

  Future<void> _loadOlder() async {
    final oldExtent = _scrollController.hasClients
        ? _scrollController.position.maxScrollExtent
        : 0.0;
    final oldOffset = _scrollController.hasClients
        ? _scrollController.offset
        : 0.0;

    await ref
        .read(
          supportConversationControllerProvider(widget.conversationId).notifier,
        )
        .loadOlder();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) {
        return;
      }
      final addedExtent =
          _scrollController.position.maxScrollExtent - oldExtent;
      _scrollController.jumpTo(
        (oldOffset + addedExtent).clamp(
          0.0,
          _scrollController.position.maxScrollExtent,
        ),
      );
    });
  }

  void _submit() {
    final provider = supportConversationControllerProvider(
      widget.conversationId,
    );
    final state = ref.read(provider);
    final content = _composerController.text.trim();
    if (!state.canSend || content.isEmpty) {
      return;
    }

    _composerController.clear();
    setState(() {});
    unawaited(ref.read(provider.notifier).send(content));
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final provider = supportConversationControllerProvider(
      widget.conversationId,
    );
    final state = ref.watch(provider);
    final controller = ref.read(provider.notifier);

    ref.listen<SupportConversationState>(provider, (previous, next) {
      final oldTail = previous?.messages.lastOrNull?.id;
      final newTail = next.messages.lastOrNull?.id;
      final pendingChanged =
          previous?.pendingSend?.clientMessageId !=
              next.pendingSend?.clientMessageId ||
          previous?.pendingSend?.status != next.pendingSend?.status;
      if (!_initialScrollCompleted &&
          !next.isLoading &&
          (next.messages.isNotEmpty || next.pendingSend != null)) {
        _initialScrollCompleted = true;
        _scrollToBottom(animate: false);
      } else if ((oldTail != newTail || pendingChanged) && _nearBottom) {
        _scrollToBottom();
      }
    });

    final conversation = state.conversation;
    return Scaffold(
      appBar: AppBar(
        title: conversation == null
            ? Text(context.l10n.tr('support.title'))
            : FirstStrongText(
                conversation.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).appBarTheme.titleTextStyle,
              ),
        actions: [
          _RealtimeIndicator(state: state.realtimeState),
          IconButton(
            tooltip: context.l10n.tr('action.refresh'),
            onPressed: state.isReconciling
                ? null
                : () => controller.reconcile(reportError: true),
            icon: state.isReconciling
                ? const SizedBox.square(
                    dimension: 19,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            if (conversation != null)
              _ConversationHeader(conversation: conversation),
            if (state.realtimeState ==
                    SupportRealtimeConnectionState.reconnecting ||
                state.realtimeState ==
                    SupportRealtimeConnectionState.disconnected)
              _RealtimeNotice(state: state.realtimeState),
            if (conversation != null &&
                conversation.status != SupportConversationStatus.aiActive)
              _ConversationStateNotice(status: conversation.status),
            if (state.actionError != null)
              _ActionError(
                error: state.actionError!,
                onDismiss: controller.clearActionError,
              ),
            Expanded(
              child: _ConversationBody(
                state: state,
                scrollController: _scrollController,
                onReload: controller.reload,
                onLoadOlder: _loadOlder,
                onRetrySend: () => unawaited(controller.retryFailedSend()),
                onDiscardSend: controller.discardFailedSend,
              ),
            ),
            if (conversation?.status == SupportConversationStatus.closed)
              _ClosedConversationAction(
                onNewConversation: () => context.push('/support'),
              )
            else if (conversation != null)
              _ConversationComposer(
                controller: _composerController,
                focusNode: _composerFocus,
                state: state,
                onChanged: () => setState(() {}),
                onSend: _submit,
                onRequestAdmin: () => unawaited(controller.requestAdmin()),
              ),
          ],
        ),
      ),
    );
  }
}

class _ConversationHeader extends StatelessWidget {
  const _ConversationHeader({required this.conversation});

  final SupportConversation conversation;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 9, 16, 10),
      child: Row(
        children: [
          SupportStatusChip(status: conversation.status),
          if (conversation.category != null) ...[
            const SizedBox(width: 10),
            Expanded(
              child: FirstStrongText(
                supportCategoryLabel(context, conversation.category!),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.labelMedium?.copyWith(color: AppColors.ink500),
              ),
            ),
          ] else
            const Spacer(),
        ],
      ),
    );
  }
}

class _RealtimeIndicator extends StatelessWidget {
  const _RealtimeIndicator({required this.state});

  final SupportRealtimeConnectionState state;

  @override
  Widget build(BuildContext context) {
    final connected = state == SupportRealtimeConnectionState.connected;
    final connecting =
        state == SupportRealtimeConnectionState.connecting ||
        state == SupportRealtimeConnectionState.reconnecting;
    return Tooltip(
      message: connected
          ? context.l10n.tr('common.online')
          : connecting
          ? context.l10n.tr('support.realtime.reconnecting')
          : context.l10n.tr('common.offline'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Icon(
          connected
              ? Icons.wifi_rounded
              : connecting
              ? Icons.sync_rounded
              : Icons.wifi_off_rounded,
          size: 18,
          color: connected
              ? AppColors.success
              : connecting
              ? AppColors.warning
              : AppColors.ink500,
        ),
      ),
    );
  }
}

class _RealtimeNotice extends StatelessWidget {
  const _RealtimeNotice({required this.state});

  final SupportRealtimeConnectionState state;

  @override
  Widget build(BuildContext context) {
    final reconnecting = state == SupportRealtimeConnectionState.reconnecting;
    return Container(
      width: double.infinity,
      color: const Color(0xFFFFF7E8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.wifi_off_rounded,
            size: 15,
            color: AppColors.warning,
          ),
          const SizedBox(width: 7),
          Flexible(
            child: Text(
              reconnecting
                  ? context.l10n.tr('support.realtime.reconnectingNotice')
                  : context.l10n.tr('support.realtime.offlineNotice'),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: const Color(0xFF8A4B06),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConversationStateNotice extends StatelessWidget {
  const _ConversationStateNotice({required this.status});

  final SupportConversationStatus status;

  @override
  Widget build(BuildContext context) {
    final (icon, color, background, message) = switch (status) {
      SupportConversationStatus.waitingForAdmin => (
        Icons.schedule_rounded,
        AppColors.warning,
        const Color(0xFFFFF7E8),
        context.l10n.tr('support.waitingNotice'),
      ),
      SupportConversationStatus.adminActive => (
        Icons.support_agent_rounded,
        AppColors.info,
        AppColors.brand50,
        context.l10n.tr('support.adminNotice'),
      ),
      SupportConversationStatus.resolved => (
        Icons.check_circle_outline_rounded,
        AppColors.success,
        const Color(0xFFECFBF5),
        context.l10n.tr('support.resolved'),
      ),
      SupportConversationStatus.closed => (
        Icons.lock_outline_rounded,
        AppColors.ink600,
        AppColors.muted,
        context.l10n.tr('support.closed'),
      ),
      SupportConversationStatus.aiActive => (
        Icons.smart_toy_outlined,
        AppColors.brand600,
        AppColors.brand50,
        '',
      ),
      SupportConversationStatus.unknown => (
        Icons.help_outline_rounded,
        AppColors.ink600,
        AppColors.muted,
        context.l10n.tr('support.statusUnknownNotice'),
      ),
    };

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppTheme.controlRadius),
        border: Border.all(color: color.withValues(alpha: .2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: color),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              message,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: color, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionError extends StatelessWidget {
  const _ActionError({required this.error, required this.onDismiss});

  final Object error;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
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
            size: 17,
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
            visualDensity: VisualDensity.compact,
            onPressed: onDismiss,
            icon: const Icon(Icons.close_rounded, size: 18),
          ),
        ],
      ),
    );
  }
}

class _ConversationBody extends StatelessWidget {
  const _ConversationBody({
    required this.state,
    required this.scrollController,
    required this.onReload,
    required this.onLoadOlder,
    required this.onRetrySend,
    required this.onDiscardSend,
  });

  final SupportConversationState state;
  final ScrollController scrollController;
  final VoidCallback onReload;
  final Future<void> Function() onLoadOlder;
  final VoidCallback onRetrySend;
  final VoidCallback onDiscardSend;

  @override
  Widget build(BuildContext context) {
    if (state.isLoading && state.messages.isEmpty) {
      return const AppLoadingView();
    }
    if (state.error != null && state.messages.isEmpty) {
      return AppErrorView(error: state.error!, onRetry: onReload);
    }

    return Semantics(
      liveRegion: true,
      label: context.l10n.tr('support.messagesSemantic'),
      child: ListView(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(14, 18, 14, 20),
        children: [
          if (state.paginationError != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                children: [
                  Text(
                    presentError(context, state.paginationError!),
                    textAlign: TextAlign.center,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: AppColors.danger),
                  ),
                  TextButton.icon(
                    onPressed: onLoadOlder,
                    icon: const Icon(Icons.refresh_rounded, size: 17),
                    label: Text(context.l10n.tr('action.retry')),
                  ),
                ],
              ),
            )
          else if (state.hasMore)
            Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: Center(
                child: OutlinedButton.icon(
                  onPressed: state.isLoadingOlder ? null : onLoadOlder,
                  icon: state.isLoadingOlder
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.history_rounded, size: 18),
                  label: Text(
                    context.l10n.tr(
                      state.isLoadingOlder
                          ? 'support.olderLoading'
                          : 'support.olderMessages',
                    ),
                  ),
                ),
              ),
            ),
          if (state.messages.isEmpty && state.pendingSend == null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 56),
              child: EmptyState(
                icon: Icons.forum_outlined,
                message: context.l10n.tr('support.noMessages'),
              ),
            )
          else
            for (final message in state.messages) ...[
              _MessageBubble(message: message),
              const SizedBox(height: 18),
            ],
          if (state.pendingSend != null)
            _PendingMessageBubble(
              pending: state.pendingSend!,
              onRetry: onRetrySend,
              onDiscard: onDiscardSend,
            ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final SupportMessage message;

  @override
  Widget build(BuildContext context) {
    final mine = message.senderType == SupportParticipantType.user;
    final background = mine
        ? AppColors.brand600
        : message.senderType == SupportParticipantType.ai
        ? AppColors.brand50
        : Colors.white;
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
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
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
                const SizedBox(height: 6),
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
                    border: mine
                        ? null
                        : Border.all(
                            color:
                                message.senderType == SupportParticipantType.ai
                                ? AppColors.brand100
                                : AppColors.border,
                          ),
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
                const SizedBox(height: 5),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Directionality(
                    textDirection: TextDirection.ltr,
                    child: Text(
                      AppFormat.dateTime(context, message.createdAt),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.ink500,
                        fontSize: 10,
                      ),
                    ),
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

class _PendingMessageBubble extends StatelessWidget {
  const _PendingMessageBubble({
    required this.pending,
    required this.onRetry,
    required this.onDiscard,
  });

  final PendingSupportSend pending;
  final VoidCallback onRetry;
  final VoidCallback onDiscard;

  @override
  Widget build(BuildContext context) {
    final failed = pending.status == PendingSupportSendStatus.failed;
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Align(
        alignment: Alignment.centerRight,
        child: FractionallySizedBox(
          widthFactor: .88,
          alignment: Alignment.centerRight,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.person_outline_rounded,
                      size: 14,
                      color: AppColors.ink500,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      context.l10n.tr('support.you'),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.ink500,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 15,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: failed
                      ? AppColors.danger
                      : AppColors.brand600.withValues(alpha: .78),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(18),
                    topRight: Radius.circular(18),
                    bottomLeft: Radius.circular(18),
                    bottomRight: Radius.circular(5),
                  ),
                ),
                child: Directionality(
                  textDirection: firstStrongTextDirection(pending.content),
                  child: SelectableText(
                    pending.content,
                    textAlign: TextAlign.start,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white,
                      height: 1.65,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 3),
              if (failed)
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  alignment: WrapAlignment.end,
                  spacing: 2,
                  children: [
                    Text(
                      context.l10n.tr('support.failed'),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.danger,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: onRetry,
                      icon: const Icon(Icons.refresh_rounded, size: 15),
                      label: Text(context.l10n.tr('action.retry')),
                    ),
                    IconButton(
                      tooltip: context.l10n.tr('action.cancel'),
                      visualDensity: VisualDensity.compact,
                      onPressed: onDiscard,
                      icon: const Icon(Icons.close_rounded, size: 17),
                    ),
                  ],
                )
              else
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox.square(
                        dimension: 11,
                        child: CircularProgressIndicator(strokeWidth: 1.5),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        context.l10n.tr('support.sending'),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.ink500,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConversationComposer extends StatelessWidget {
  const _ConversationComposer({
    required this.controller,
    required this.focusNode,
    required this.state,
    required this.onChanged,
    required this.onSend,
    required this.onRequestAdmin,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final SupportConversationState state;
  final VoidCallback onChanged;
  final VoidCallback onSend;
  final VoidCallback onRequestAdmin;

  @override
  Widget build(BuildContext context) {
    final conversation = state.conversation!;
    final pending = state.pendingSend;
    final canCompose = state.canSend;
    final canRequestAdmin =
        conversation.status == SupportConversationStatus.aiActive &&
        !state.isRequestingAdmin &&
        pending?.status != PendingSupportSendStatus.sending;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (conversation.status == SupportConversationStatus.aiActive)
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 4, bottom: 7),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      context.l10n.tr('support.aiHint'),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppColors.ink500,
                        height: 1.4,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: canRequestAdmin ? onRequestAdmin : null,
                    icon: state.isRequestingAdmin
                        ? const SizedBox.square(
                            dimension: 13,
                            child: CircularProgressIndicator(strokeWidth: 1.7),
                          )
                        : const Icon(Icons.support_agent_rounded, size: 16),
                    label: Text(context.l10n.tr('support.handoff')),
                  ),
                ],
              ),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  enabled: canCompose,
                  minLines: 1,
                  maxLines: 5,
                  maxLength: 4000,
                  textDirection: firstStrongTextDirection(controller.text),
                  textAlign: TextAlign.start,
                  keyboardType: TextInputType.multiline,
                  textInputAction: TextInputAction.newline,
                  onChanged: (_) => onChanged(),
                  decoration: InputDecoration(
                    hintText:
                        conversation.status ==
                            SupportConversationStatus.resolved
                        ? context.l10n.tr('support.resolved')
                        : context.l10n.tr('support.placeholder'),
                    counterText: '',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                tooltip: context.l10n.tr('action.send'),
                onPressed: canCompose && controller.text.trim().isNotEmpty
                    ? onSend
                    : null,
                icon: const Icon(Icons.send_rounded),
              ),
            ],
          ),
          if (controller.text.length > 3600)
            Padding(
              padding: const EdgeInsetsDirectional.only(top: 4, end: 52),
              child: Text(
                '${AppFormat.number(context, controller.text.length)}/${AppFormat.number(context, 4000)}',
                textAlign: TextAlign.end,
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(color: AppColors.ink500),
              ),
            ),
        ],
      ),
    );
  }
}

class _ClosedConversationAction extends StatelessWidget {
  const _ClosedConversationAction({required this.onNewConversation});

  final VoidCallback onNewConversation;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: FilledButton.icon(
        onPressed: onNewConversation,
        icon: const Icon(Icons.add_comment_outlined),
        label: Text(context.l10n.tr('support.new')),
      ),
    );
  }
}
