import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/network/error_presenter.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/app_format.dart';
import '../../../../core/widgets/app_status_badge.dart';
import '../../../../core/widgets/async_states.dart';
import '../../../../core/widgets/first_strong_text.dart';
import '../application/admin_operations_providers.dart';
import '../application/admin_users_controller.dart';
import '../data/admin_operations_models.dart';
import 'admin_operations_widgets.dart';

typedef AdminUserOverviewOpener = FutureOr<void> Function(int userId);

class AdminUsersScreen extends ConsumerStatefulWidget {
  const AdminUsersScreen({super.key, this.onOpenUser});

  final AdminUserOverviewOpener? onOpenUser;

  @override
  ConsumerState<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends ConsumerState<AdminUsersScreen> {
  late final TextEditingController _queryController;

  @override
  void initState() {
    super.initState();
    _queryController = TextEditingController();
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  Future<void> _openUser(int userId) async {
    final callback = widget.onOpenUser;
    if (callback == null) return;
    await callback(userId);
    if (mounted) {
      await ref.read(adminUsersControllerProvider.notifier).refresh();
    }
  }

  Future<void> _showCreateAdmin() async {
    final created = await showDialog<AdminUserModel>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _CreateAdminDialog(
        onCreate: ref.read(adminUsersControllerProvider.notifier).createAdmin,
      ),
    );
    if (!mounted || created == null) return;
    _queryController.clear();
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context.l10n.tr('admin.users.createSuccess', <String, Object?>{
            'email': '\u2066${created.email}\u2069',
          }),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adminUsersControllerProvider);
    final controller = ref.read(adminUsersControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.tr('admin.users.title')),
        actions: [
          IconButton(
            tooltip: context.l10n.tr('admin.users.createAction'),
            onPressed: state.isLoading || state.isRefreshing
                ? null
                : () => unawaited(_showCreateAdmin()),
            icon: const Icon(Icons.person_add_alt_1_rounded),
          ),
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
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 7, 16, 12),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: TextField(
                  controller: _queryController,
                  textDirection: _queryController.text.trim().isEmpty
                      ? Directionality.of(context)
                      : firstStrongTextDirection(_queryController.text),
                  textAlign: TextAlign.start,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) =>
                      unawaited(controller.search(_queryController.text)),
                  decoration: InputDecoration(
                    labelText: context.l10n.tr('admin.users.search'),
                    hintText: context.l10n.tr('admin.users.searchPlaceholder'),
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _queryController.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: context.l10n.tr('admin.users.clearSearch'),
                            onPressed: state.isLoading || state.isRefreshing
                                ? null
                                : () {
                                    _queryController.clear();
                                    setState(() {});
                                    unawaited(controller.clearSearch());
                                  },
                            icon: const Icon(Icons.close_rounded),
                          ),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ),
          ),
          if (state.error != null && state.items.isNotEmpty)
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 10),
              child: MaterialBanner(
                content: Text(presentError(context, state.error!)),
                actions: [
                  TextButton(
                    onPressed: controller.refresh,
                    child: Text(context.l10n.tr('action.retry')),
                  ),
                ],
              ),
            ),
          Expanded(child: _buildResults(context, state, controller)),
        ],
      ),
    );
  }

  Widget _buildResults(
    BuildContext context,
    AdminUsersState state,
    AdminUsersController controller,
  ) {
    if (state.isLoading && state.items.isEmpty) {
      return const AppLoadingView();
    }
    if (state.error != null && state.items.isEmpty) {
      return AppErrorView(error: state.error!, onRetry: controller.load);
    }
    if (state.items.isEmpty) {
      return RefreshIndicator(
        onRefresh: controller.refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            SizedBox(
              height: MediaQuery.sizeOf(context).height * .55,
              child: EmptyState(
                icon: Icons.group_outlined,
                message: context.l10n.tr('admin.users.empty'),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: controller.refresh,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 16, 28),
        itemCount: state.items.length + 1,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          if (index == state.items.length) {
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Padding(
                  padding: const EdgeInsets.only(top: 5),
                  child: AdminPaginationBar(
                    page: state.page,
                    totalCount: state.totalCount,
                    hasPrevious: state.hasPrevious,
                    hasNext: state.hasNext,
                    busy: state.isLoading || state.isRefreshing,
                    onPrevious: () => unawaited(controller.previousPage()),
                    onNext: () => unawaited(controller.nextPage()),
                  ),
                ),
              ),
            );
          }
          final user = state.items[index];
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: _AdminUserCard(
                user: user,
                onTap: widget.onOpenUser == null
                    ? null
                    : () => unawaited(_openUser(user.id)),
              ),
            ),
          );
        },
      ),
    );
  }
}

typedef _CreateAdminCallback = Future<AdminUserModel> Function(
  CreateAdminRequestModel request,
);

class _CreateAdminDialog extends StatefulWidget {
  const _CreateAdminDialog({required this.onCreate});

  final _CreateAdminCallback onCreate;

  @override
  State<_CreateAdminDialog> createState() => _CreateAdminDialogState();
}

class _CreateAdminDialogState extends State<_CreateAdminDialog> {
  final _formKey = GlobalKey<FormState>();
  final _fullName = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  bool _submitting = false;
  bool _obscurePassword = true;
  String? _error;

  @override
  void dispose() {
    _fullName.dispose();
    _email.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting || !_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final created = await widget.onCreate(
        CreateAdminRequestModel(
          fullName: _fullName.text,
          email: _email.text,
          password: _password.text,
        ),
      );
      _password.clear();
      _confirmPassword.clear();
      if (mounted) Navigator.of(context).pop(created);
    } on Object catch (error) {
      if (mounted) setState(() => _error = presentError(context, error));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String? _required(String? value) => value == null || value.trim().isEmpty
      ? context.l10n.tr('admin.validation.required')
      : null;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.l10n.tr('admin.users.createTitle')),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  context.l10n.tr('admin.users.createDescription'),
                  style: const TextStyle(color: AppColors.ink600),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _fullName,
                  maxLength: 200,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: context.l10n.tr('admin.users.fullName'),
                    prefixIcon: const Icon(Icons.person_outline_rounded),
                  ),
                  validator: _required,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _email,
                  maxLength: 320,
                  textDirection: TextDirection.ltr,
                  textAlign: TextAlign.left,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: context.l10n.tr('admin.users.email'),
                    prefixIcon: const Icon(Icons.alternate_email_rounded),
                  ),
                  validator: (value) => value != null && value.contains('@')
                      ? null
                      : context.l10n.tr('error.validation'),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _password,
                  maxLength: 128,
                  obscureText: _obscurePassword,
                  textDirection: TextDirection.ltr,
                  textAlign: TextAlign.left,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: context.l10n.tr('admin.users.password'),
                    prefixIcon: const Icon(Icons.lock_outline_rounded),
                    suffixIcon: IconButton(
                      onPressed: () => setState(
                        () => _obscurePassword = !_obscurePassword,
                      ),
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                  ),
                  validator: (value) {
                    final required = _required(value);
                    if (required != null) return required;
                    return value!.length < 8 || value.length > 128
                        ? context.l10n.tr('admin.users.passwordPolicy')
                        : null;
                  },
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _confirmPassword,
                  maxLength: 128,
                  obscureText: _obscurePassword,
                  textDirection: TextDirection.ltr,
                  textAlign: TextAlign.left,
                  onFieldSubmitted: (_) => unawaited(_submit()),
                  decoration: InputDecoration(
                    labelText: context.l10n.tr('admin.users.confirmPassword'),
                    prefixIcon: const Icon(Icons.lock_reset_rounded),
                  ),
                  validator: (value) => value != _password.text
                      ? context.l10n.tr('admin.users.passwordMismatch')
                      : _required(value),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: const TextStyle(color: AppColors.danger),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
          child: Text(context.l10n.tr('action.cancel')),
        ),
        FilledButton.icon(
          onPressed: _submitting ? null : _submit,
          icon: _submitting
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.person_add_alt_1_rounded),
          label: Text(
            context.l10n.tr(
              _submitting ? 'admin.users.creating' : 'admin.users.createAction',
            ),
          ),
        ),
      ],
    );
  }
}

class _AdminUserCard extends StatelessWidget {
  const _AdminUserCard({required this.user, this.onTap});

  final AdminUserModel user;
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
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          user.email,
                          textDirection: TextDirection.ltr,
                          textAlign: TextAlign.start,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.ink500,
                            fontSize: 12,
                          ),
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
                spacing: 8,
                runSpacing: 8,
                children: [
                  AppStatusBadge(
                    label: context.l10n.tr(
                      user.isAdmin
                          ? 'admin.users.roleAdmin'
                          : 'admin.users.roleUser',
                    ),
                    color: user.isAdmin ? AppColors.brand700 : AppColors.ink600,
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
              Row(
                children: [
                  Text(
                    context.l10n.tr(
                      'admin.users.accountNumber',
                      <String, Object?>{
                        'id': AppFormat.number(context, user.id),
                      },
                    ),
                    style: const TextStyle(
                      color: AppColors.ink500,
                      fontSize: 12,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    AppFormat.dateTime(context, user.createdAt),
                    style: const TextStyle(
                      color: AppColors.ink500,
                      fontSize: 12,
                    ),
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
