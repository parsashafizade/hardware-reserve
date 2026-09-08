import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/network/error_presenter.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/async_states.dart';
import '../../../support/presentation/support_presentation_helpers.dart';
import '../application/admin_support_providers.dart';
import '../data/admin_support_models.dart';
import 'admin_support_text.dart';

Future<String?> showAdminSupportQuickRepliesSheet(
  BuildContext context, {
  bool allowSelection = false,
}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) =>
        AdminSupportQuickRepliesSheet(allowSelection: allowSelection),
  );
}

class AdminSupportQuickRepliesSheet extends ConsumerWidget {
  const AdminSupportQuickRepliesSheet({super.key, this.allowSelection = false});

  final bool allowSelection;

  Future<void> _edit(
    BuildContext context,
    WidgetRef ref, [
    AdminSupportQuickReply? reply,
  ]) async {
    final request = await showDialog<UpsertAdminSupportQuickReplyRequest>(
      context: context,
      builder: (_) => _QuickReplyEditorDialog(reply: reply),
    );
    if (request == null || !context.mounted) return;
    try {
      final controller = ref.read(
        adminSupportQuickRepliesControllerProvider.notifier,
      );
      if (reply == null) {
        await controller.create(request);
      } else {
        await controller.update(reply.id, request);
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              adminSupportText(
                context,
                'admin.support.quickReplies.saved',
                fa: 'پاسخ آماده ذخیره شد.',
                en: 'Quick reply saved.',
              ),
            ),
          ),
        );
      }
    } on Object catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(presentError(context, error))));
      }
    }
  }

  Future<void> _deactivate(
    BuildContext context,
    WidgetRef ref,
    AdminSupportQuickReply reply,
  ) async {
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(
              adminSupportText(
                context,
                'admin.support.quickReplies.deactivateTitle',
                fa: 'غیرفعال‌کردن پاسخ آماده',
                en: 'Deactivate quick reply',
              ),
            ),
            content: Text(
              adminSupportText(
                context,
                'admin.support.quickReplies.deactivateConfirm',
                fa: 'این پاسخ از فهرست پاسخ‌های قابل استفاده حذف می‌شود.',
                en: 'This removes the reply from the available reply list.',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text(context.l10n.tr('action.cancel')),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(
                  adminSupportText(
                    context,
                    'admin.support.quickReplies.deactivate',
                    fa: 'غیرفعال کن',
                    en: 'Deactivate',
                  ),
                ),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !context.mounted) return;
    try {
      await ref
          .read(adminSupportQuickRepliesControllerProvider.notifier)
          .deactivate(reply.id);
    } on Object catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(presentError(context, error))));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(adminSupportQuickRepliesControllerProvider);
    final controller = ref.read(
      adminSupportQuickRepliesControllerProvider.notifier,
    );
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * .9,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 10, 8, 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        adminSupportText(
                          context,
                          'admin.support.quickReplies.title',
                          fa: 'پاسخ‌های آماده',
                          en: 'Quick replies',
                        ),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(
                        allowSelection
                            ? adminSupportText(
                                context,
                                'admin.support.quickReplies.selectionHint',
                                fa: 'یک پاسخ را انتخاب و پیش از ارسال ویرایش کنید.',
                                en: 'Choose a reply, then edit it before sending.',
                              )
                            : adminSupportText(
                                context,
                                'admin.support.quickReplies.manageHint',
                                fa: 'پاسخ‌های پرتکرار تیم را مدیریت کنید.',
                                en: 'Manage the team’s reusable responses.',
                              ),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.ink500,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: context.l10n.tr('action.refresh'),
                  onPressed: state.isLoading ? null : controller.load,
                  icon: const Icon(Icons.refresh_rounded),
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
            child: state.isLoading && state.replies.isEmpty
                ? const AppLoadingView()
                : state.error != null && state.replies.isEmpty
                ? AppErrorView(error: state.error!, onRetry: controller.load)
                : RefreshIndicator(
                    onRefresh: controller.load,
                    child: state.replies.isEmpty
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              SizedBox(
                                height: 420,
                                child: EmptyState(
                                  icon: Icons.quickreply_outlined,
                                  message: adminSupportText(
                                    context,
                                    'admin.support.quickReplies.empty',
                                    fa: 'هنوز پاسخ آماده‌ای ساخته نشده است.',
                                    en: 'No quick replies have been created.',
                                  ),
                                ),
                              ),
                            ],
                          )
                        : ListView.separated(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                            itemCount: state.replies.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final reply = state.replies[index];
                              final deactivating = state.deactivatingIds
                                  .contains(reply.id);
                              return Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: FirstStrongText(
                                              reply.title,
                                              style: Theme.of(
                                                context,
                                              ).textTheme.titleMedium,
                                            ),
                                          ),
                                          if (!reply.isActive)
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 4,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: AppColors.muted,
                                                borderRadius:
                                                    BorderRadius.circular(999),
                                              ),
                                              child: Text(
                                                adminSupportText(
                                                  context,
                                                  'admin.support.quickReplies.inactive',
                                                  fa: 'غیرفعال',
                                                  en: 'Inactive',
                                                ),
                                                style: Theme.of(
                                                  context,
                                                ).textTheme.labelSmall,
                                              ),
                                            ),
                                        ],
                                      ),
                                      if (reply.category != null) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          supportCategoryLabel(
                                            context,
                                            reply.category!,
                                          ),
                                          style: Theme.of(context)
                                              .textTheme
                                              .labelSmall
                                              ?.copyWith(
                                                color: AppColors.ink500,
                                              ),
                                        ),
                                      ],
                                      const SizedBox(height: 10),
                                      FirstStrongText(
                                        reply.content,
                                        maxLines: 4,
                                        overflow: TextOverflow.ellipsis,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(height: 1.55),
                                      ),
                                      const SizedBox(height: 14),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        alignment: WrapAlignment.end,
                                        children: [
                                          if (allowSelection && reply.isActive)
                                            FilledButton.tonalIcon(
                                              onPressed: () => Navigator.pop(
                                                context,
                                                reply.content,
                                              ),
                                              icon: const Icon(
                                                Icons.add_comment_outlined,
                                              ),
                                              label: Text(
                                                adminSupportText(
                                                  context,
                                                  'admin.support.quickReplies.use',
                                                  fa: 'استفاده در پاسخ',
                                                  en: 'Use in reply',
                                                ),
                                              ),
                                            ),
                                          OutlinedButton.icon(
                                            onPressed: state.isSaving
                                                ? null
                                                : () => _edit(
                                                    context,
                                                    ref,
                                                    reply,
                                                  ),
                                            icon: const Icon(
                                              Icons.edit_outlined,
                                            ),
                                            label: Text(
                                              adminSupportText(
                                                context,
                                                'admin.support.quickReplies.edit',
                                                fa: 'ویرایش',
                                                en: 'Edit',
                                              ),
                                            ),
                                          ),
                                          if (reply.isActive)
                                            TextButton.icon(
                                              onPressed: deactivating
                                                  ? null
                                                  : () => _deactivate(
                                                      context,
                                                      ref,
                                                      reply,
                                                    ),
                                              icon: deactivating
                                                  ? const SizedBox.square(
                                                      dimension: 16,
                                                      child:
                                                          CircularProgressIndicator(
                                                            strokeWidth: 2,
                                                          ),
                                                    )
                                                  : const Icon(
                                                      Icons.block_outlined,
                                                    ),
                                              label: Text(
                                                adminSupportText(
                                                  context,
                                                  'admin.support.quickReplies.deactivate',
                                                  fa: 'غیرفعال',
                                                  en: 'Deactivate',
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: state.isSaving ? null : () => _edit(context, ref),
                  icon: const Icon(Icons.add_rounded),
                  label: Text(
                    adminSupportText(
                      context,
                      'admin.support.quickReplies.add',
                      fa: 'پاسخ آماده جدید',
                      en: 'New quick reply',
                    ),
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

class _QuickReplyEditorDialog extends StatefulWidget {
  const _QuickReplyEditorDialog({this.reply});

  final AdminSupportQuickReply? reply;

  @override
  State<_QuickReplyEditorDialog> createState() =>
      _QuickReplyEditorDialogState();
}

class _QuickReplyEditorDialogState extends State<_QuickReplyEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _contentController;
  late final TextEditingController _categoryController;
  late final TextEditingController _orderController;
  late bool _isActive;

  @override
  void initState() {
    super.initState();
    final reply = widget.reply;
    _titleController = TextEditingController(text: reply?.title);
    _contentController = TextEditingController(text: reply?.content);
    _categoryController = TextEditingController(text: reply?.category);
    _orderController = TextEditingController(text: '${reply?.sortOrder ?? 0}');
    _isActive = reply?.isActive ?? true;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _categoryController.dispose();
    _orderController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.pop(
      context,
      UpsertAdminSupportQuickReplyRequest(
        title: _titleController.text,
        content: _contentController.text,
        category: _categoryController.text,
        isActive: _isActive,
        sortOrder: int.parse(_orderController.text),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.reply == null
            ? adminSupportText(
                context,
                'admin.support.quickReplies.add',
                fa: 'پاسخ آماده جدید',
                en: 'New quick reply',
              )
            : adminSupportText(
                context,
                'admin.support.quickReplies.edit',
                fa: 'ویرایش پاسخ آماده',
                en: 'Edit quick reply',
              ),
      ),
      content: SizedBox(
        width: 520,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _titleController,
                  builder: (context, value, _) => TextFormField(
                    controller: _titleController,
                    maxLength: 120,
                    textDirection: value.text.trim().isEmpty
                        ? Directionality.of(context)
                        : firstStrongTextDirection(value.text),
                    textAlign: TextAlign.start,
                    decoration: InputDecoration(
                      labelText: adminSupportText(
                        context,
                        'admin.support.quickReplies.formTitle',
                        fa: 'عنوان',
                        en: 'Title',
                      ),
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? context.l10n.tr('error.validation')
                        : null,
                  ),
                ),
                const SizedBox(height: 10),
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _contentController,
                  builder: (context, value, _) => TextFormField(
                    controller: _contentController,
                    minLines: 4,
                    maxLines: 8,
                    maxLength: 2000,
                    textDirection: value.text.trim().isEmpty
                        ? Directionality.of(context)
                        : firstStrongTextDirection(value.text),
                    textAlign: TextAlign.start,
                    decoration: InputDecoration(
                      labelText: adminSupportText(
                        context,
                        'admin.support.quickReplies.formContent',
                        fa: 'متن پاسخ',
                        en: 'Reply content',
                      ),
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? context.l10n.tr('error.validation')
                        : null,
                  ),
                ),
                const SizedBox(height: 10),
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: _categoryController,
                  builder: (context, value, _) => TextFormField(
                    controller: _categoryController,
                    maxLength: 80,
                    textDirection: value.text.trim().isEmpty
                        ? Directionality.of(context)
                        : firstStrongTextDirection(value.text),
                    textAlign: TextAlign.start,
                    decoration: InputDecoration(
                      labelText: adminSupportText(
                        context,
                        'admin.support.quickReplies.formCategory',
                        fa: 'دسته‌بندی (اختیاری)',
                        en: 'Category (optional)',
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _orderController,
                  keyboardType: TextInputType.number,
                  textDirection: TextDirection.ltr,
                  decoration: InputDecoration(
                    labelText: adminSupportText(
                      context,
                      'admin.support.quickReplies.formOrder',
                      fa: 'ترتیب نمایش',
                      en: 'Sort order',
                    ),
                  ),
                  validator: (value) {
                    final order = int.tryParse(value ?? '');
                    return order == null || order < 0 || order > 10000
                        ? context.l10n.tr('error.validation')
                        : null;
                  },
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: _isActive,
                  onChanged: (value) => setState(() => _isActive = value),
                  title: Text(
                    adminSupportText(
                      context,
                      'admin.support.quickReplies.formActive',
                      fa: 'فعال و قابل استفاده',
                      en: 'Active and available',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.l10n.tr('action.cancel')),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(context.l10n.tr('action.save')),
        ),
      ],
    );
  }
}
