import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/network/error_presenter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/app_format.dart';
import '../../../core/widgets/async_states.dart';
import '../application/support_history_controller.dart';
import '../application/support_providers.dart';
import '../data/support_models.dart';
import 'support_presentation_helpers.dart';

class SupportScreen extends ConsumerStatefulWidget {
  const SupportScreen({super.key});

  @override
  ConsumerState<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends ConsumerState<SupportScreen> {
  late final AppLifecycleListener _lifecycleListener;

  @override
  void initState() {
    super.initState();
    _lifecycleListener = AppLifecycleListener(
      onPause: () =>
          ref.read(supportHistoryControllerProvider.notifier).onAppPaused(),
      onResume: () => unawaited(
        ref.read(supportHistoryControllerProvider.notifier).onAppResumed(),
      ),
    );
  }

  @override
  void dispose() {
    _lifecycleListener.dispose();
    super.dispose();
  }

  Future<void> _startConversation(BuildContext context) async {
    final selection = await showModalBottomSheet<_NewConversationSelection>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const _NewConversationSheet(),
    );
    if (selection == null || !context.mounted) {
      return;
    }

    try {
      final conversation = await ref
          .read(supportHistoryControllerProvider.notifier)
          .createConversation(category: selection.category);
      if (!context.mounted) {
        return;
      }
      await context.push('/support/${conversation.id}');
      if (context.mounted) {
        await ref.read(supportHistoryControllerProvider.notifier).load();
      }
    } on Object catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(presentError(context, error))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(supportHistoryControllerProvider);
    final controller = ref.read(supportHistoryControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.tr('support.title')),
        actions: [
          IconButton(
            tooltip: context.l10n.tr('action.refresh'),
            onPressed: state.isLoading ? null : controller.load,
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: state.conversations.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: state.isCreating
                  ? null
                  : () => _startConversation(context),
              icon: state.isCreating
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add_comment_outlined),
              label: Text(context.l10n.tr('support.new')),
            ),
      body: _SupportHistoryBody(
        state: state,
        onRefresh: controller.load,
        onLoadMore: controller.loadMore,
        onNewConversation: () => _startConversation(context),
        onOpenConversation: (conversation) async {
          await context.push('/support/${conversation.id}');
          if (context.mounted) {
            await controller.load();
          }
        },
      ),
    );
  }
}

class _SupportHistoryBody extends StatelessWidget {
  const _SupportHistoryBody({
    required this.state,
    required this.onRefresh,
    required this.onLoadMore,
    required this.onNewConversation,
    required this.onOpenConversation,
  });

  final SupportHistoryState state;
  final Future<void> Function() onRefresh;
  final Future<void> Function() onLoadMore;
  final VoidCallback onNewConversation;
  final ValueChanged<SupportConversation> onOpenConversation;

  @override
  Widget build(BuildContext context) {
    if (state.isLoading && state.conversations.isEmpty) {
      return const AppLoadingView();
    }
    if (state.error != null && state.conversations.isEmpty) {
      return AppErrorView(error: state.error!, onRetry: onRefresh);
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 104),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _SupportSummaryCard(
                    unreadMessages: state.unreadMessages,
                    onNewConversation: onNewConversation,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    context.l10n.tr('support.history'),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  if (state.conversations.isEmpty)
                    Card(
                      child: EmptyState(
                        icon: Icons.forum_outlined,
                        message: context.l10n.tr('support.empty'),
                        action: FilledButton.icon(
                          onPressed: onNewConversation,
                          icon: const Icon(Icons.add_rounded),
                          label: Text(context.l10n.tr('support.new')),
                        ),
                      ),
                    )
                  else
                    ...state.conversations.map(
                      (conversation) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _ConversationCard(
                          conversation: conversation,
                          onTap: () => onOpenConversation(conversation),
                        ),
                      ),
                    ),
                  if (state.paginationError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: AppErrorView(
                        error: state.paginationError!,
                        onRetry: onLoadMore,
                        compact: true,
                      ),
                    )
                  else if (state.hasMore)
                    Center(
                      child: OutlinedButton.icon(
                        onPressed: state.isLoadingMore ? null : onLoadMore,
                        icon: state.isLoadingMore
                            ? const SizedBox.square(
                                dimension: 17,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.expand_more_rounded),
                        label: Text(context.l10n.tr('support.loadMore')),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SupportSummaryCard extends StatelessWidget {
  const _SupportSummaryCard({
    required this.unreadMessages,
    required this.onNewConversation,
  });

  final int unreadMessages;
  final VoidCallback onNewConversation;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.inverse, AppColors.brand800],
        ),
        borderRadius: BorderRadius.circular(AppTheme.panelRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.support_agent_rounded, color: Colors.white),
          ),
          const SizedBox(height: 16),
          Text(
            context.l10n.tr('support.summary.title'),
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            unreadMessages > 0
                ? context.l10n.tr(
                    unreadMessages == 1
                        ? 'support.summary.unreadOne'
                        : 'support.summary.unreadMany',
                    <String, Object?>{
                      'count': AppFormat.number(context, unreadMessages),
                    },
                  )
                : context.l10n.tr('support.summary.description'),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: .78),
            ),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppColors.brand700,
            ),
            onPressed: onNewConversation,
            icon: const Icon(Icons.add_comment_outlined),
            label: Text(context.l10n.tr('support.new')),
          ),
        ],
      ),
    );
  }
}

class _ConversationCard extends StatelessWidget {
  const _ConversationCard({required this.conversation, required this.onTap});

  final SupportConversation conversation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final lastMessage = conversation.lastMessage;
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
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        FirstStrongText(
                          conversation.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(color: AppColors.ink900),
                        ),
                        if (conversation.category != null) ...[
                          const SizedBox(height: 3),
                          FirstStrongText(
                            supportCategoryLabel(
                              context,
                              conversation.category!,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: AppColors.ink500),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (conversation.unreadCount > 0) ...[
                    const SizedBox(width: 12),
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
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              if (lastMessage != null) ...[
                const SizedBox(height: 10),
                FirstStrongText(
                  lastMessage.preview,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.ink600,
                    height: 1.5,
                  ),
                ),
              ],
              const SizedBox(height: 14),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Row(
                children: [
                  SupportStatusChip(status: conversation.status),
                  const Spacer(),
                  const Icon(
                    Icons.schedule_rounded,
                    size: 14,
                    color: AppColors.ink500,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    AppFormat.dateTime(
                      context,
                      lastMessage?.sentAt ?? conversation.updatedAt,
                    ),
                    style: Theme.of(
                      context,
                    ).textTheme.labelSmall?.copyWith(color: AppColors.ink500),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: AppColors.ink500,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NewConversationSelection {
  const _NewConversationSelection({this.category});

  final String? category;
}

class _NewConversationSheet extends StatefulWidget {
  const _NewConversationSheet();

  @override
  State<_NewConversationSheet> createState() => _NewConversationSheetState();
}

class _NewConversationSheetState extends State<_NewConversationSheet> {
  String? _category;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          const SizedBox(height: 22),
          Text(
            context.l10n.tr('support.new'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 6),
          Text(
            context.l10n.tr('support.newHelp'),
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.ink600),
          ),
          const SizedBox(height: 20),
          Text(
            context.l10n.tr('support.category'),
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: supportCategories.map((category) {
              return ChoiceChip(
                label: Text(supportCategoryLabel(context, category)),
                selected: _category == category,
                onSelected: (selected) {
                  setState(() => _category = selected ? category : null);
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => Navigator.pop(
              context,
              _NewConversationSelection(category: _category),
            ),
            icon: const Icon(Icons.arrow_forward_rounded),
            label: Text(context.l10n.tr('support.new')),
          ),
        ],
      ),
    );
  }
}
