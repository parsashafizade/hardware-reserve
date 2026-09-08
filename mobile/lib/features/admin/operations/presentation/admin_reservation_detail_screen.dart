import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/network/api_failure.dart';
import '../../../../core/network/error_presenter.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/app_format.dart';
import '../../../../core/widgets/async_states.dart';
import '../application/admin_operations_providers.dart';
import '../application/admin_reservation_detail_controller.dart';
import '../data/admin_operations_models.dart';
import 'admin_operations_widgets.dart';

typedef AdminUserOpener = FutureOr<void> Function(int userId);

class AdminReservationDetailScreen extends ConsumerStatefulWidget {
  const AdminReservationDetailScreen({
    super.key,
    required this.reservationId,
    this.onOpenUser,
  });

  final int reservationId;
  final AdminUserOpener? onOpenUser;

  @override
  ConsumerState<AdminReservationDetailScreen> createState() =>
      _AdminReservationDetailScreenState();
}

class _AdminReservationDetailScreenState
    extends ConsumerState<AdminReservationDetailScreen> {
  final _credentialsFormKey = GlobalKey<FormState>();
  late final TextEditingController _ipController;
  late final TextEditingController _usernameController;
  late final TextEditingController _passwordController;
  bool _obscurePassword = true;
  bool _revealAssignedPassword = false;
  String? _ipServerError;
  String? _usernameServerError;
  String? _passwordServerError;
  String? _actionError;

  @override
  void initState() {
    super.initState();
    _ipController = TextEditingController();
    _usernameController = TextEditingController();
    _passwordController = TextEditingController();
  }

  @override
  void dispose() {
    _ipController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  AdminReservationDetailController get _controller => ref.read(
    adminReservationDetailControllerProvider(widget.reservationId).notifier,
  );

  Future<void> _cancel(AdminOrderModel order) async {
    if (!order.canCancelAt()) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.tr('admin.reservationDetail.cancelTitle')),
        content: Text(context.l10n.tr('admin.reservationDetail.cancelConfirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.tr('action.close')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            child: Text(context.l10n.tr('admin.reservationDetail.cancel')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _actionError = null);
    try {
      final updated = await _controller.cancelReservation();
      if (!mounted || updated == null) return;
      _showMessage('admin.reservationDetail.cancelSuccess');
    } on Object catch (error) {
      if (mounted) setState(() => _actionError = _actionMessage(error));
    }
  }

  Future<void> _assign(AdminOrderModel order) async {
    if (!_credentialsFormKey.currentState!.validate()) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          context.l10n.tr(
            order.credentialsAssigned
                ? 'admin.reservationDetail.reassignTitle'
                : 'admin.reservationDetail.assignTitle',
          ),
        ),
        content: Text(
          context.l10n.tr(
            order.credentialsAssigned
                ? 'admin.reservationDetail.reassignConfirm'
                : 'admin.reservationDetail.assignConfirm',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.tr('action.close')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.tr('admin.reservationDetail.assign')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _actionError = null;
      _ipServerError = null;
      _usernameServerError = null;
      _passwordServerError = null;
    });
    try {
      final assigned = await _controller.assignCredentials(
        assignedIp: _ipController.text,
        assignedUsername: _usernameController.text,
        assignedPassword: _passwordController.text,
      );
      if (!mounted || !assigned) return;
      // Never retain secrets in editable form fields after persistence. The
      // protected detail state keeps the current values available for review.
      _ipController.clear();
      _usernameController.clear();
      _passwordController.clear();
      setState(() => _revealAssignedPassword = false);
      _credentialsFormKey.currentState?.reset();
      _showMessage('admin.reservationDetail.assignSuccess');
    } on Object catch (error) {
      if (!mounted) return;
      final failure = ApiFailure.from(error);
      setState(() {
        _ipServerError = failure.fieldMessage('assignedIp');
        _usernameServerError = failure.fieldMessage('assignedUsername');
        _passwordServerError = failure.fieldMessage('assignedPassword');
        _actionError = _actionMessage(error);
      });
    }
  }

  String _actionMessage(Object error) {
    final failure = ApiFailure.from(error);
    final key = switch (failure.code) {
      'ADMIN_RESERVATION_TRANSITION_INVALID' =>
        'admin.reservationDetail.cancelInvalid',
      _ => null,
    };
    return key == null ? presentError(context, error) : context.l10n.tr(key);
  }

  void _showMessage(String key) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(context.l10n.tr(key))));
  }

  @override
  Widget build(BuildContext context) {
    final provider = adminReservationDetailControllerProvider(
      widget.reservationId,
    );
    final state = ref.watch(provider);
    final order = state.order;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          context.l10n.tr('admin.reservationDetail.title', <String, Object?>{
            'id': AppFormat.number(context, widget.reservationId),
          }),
        ),
        actions: [
          IconButton(
            tooltip: context.l10n.tr('action.refresh'),
            onPressed: state.isLoading || state.isRefreshing || state.isMutating
                ? null
                : () => unawaited(_controller.refresh()),
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
      body: state.isLoading && order == null
          ? const AppLoadingView()
          : state.error != null && order == null
          ? AppErrorView(error: state.error!, onRetry: _controller.load)
          : RefreshIndicator(
              onRefresh: _controller.refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 36),
                children: [
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 760),
                      child: _buildContent(context, state, order!),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    AdminReservationDetailState state,
    AdminOrderModel order,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (state.error != null) ...[
          AdminInlineError(
            error: state.error!,
            onRetry: () => unawaited(_controller.refresh()),
          ),
          const SizedBox(height: 12),
        ],
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  order.hardwareLabel,
                  textDirection: TextDirection.ltr,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
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
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        _CustomerCard(order: order, onOpenUser: widget.onOpenUser),
        const SizedBox(height: 12),
        _HardwareCard(order: order),
        const SizedBox(height: 12),
        _ScheduleCard(order: order),
        const SizedBox(height: 12),
        _CredentialsAssignmentCard(
          order: order,
          formKey: _credentialsFormKey,
          ipController: _ipController,
          usernameController: _usernameController,
          passwordController: _passwordController,
          obscurePassword: _obscurePassword,
          revealAssignedPassword: _revealAssignedPassword,
          ipServerError: _ipServerError,
          usernameServerError: _usernameServerError,
          passwordServerError: _passwordServerError,
          busy: state.isAssigningCredentials,
          onTogglePassword: () =>
              setState(() => _obscurePassword = !_obscurePassword),
          onToggleAssignedPassword: () => setState(
            () => _revealAssignedPassword = !_revealAssignedPassword,
          ),
          onSubmit: () => unawaited(_assign(order)),
        ),
        if (_actionError != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: AppColors.danger.withValues(alpha: .08),
              borderRadius: BorderRadius.circular(AppTheme.controlRadius),
              border: Border.all(
                color: AppColors.danger.withValues(alpha: .25),
              ),
            ),
            child: Text(
              _actionError!,
              style: const TextStyle(color: AppColors.danger),
            ),
          ),
        ],
        if (order.canCancelAt()) ...[
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: state.isMutating
                ? null
                : () => unawaited(_cancel(order)),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.danger,
              side: const BorderSide(color: AppColors.danger),
            ),
            icon: state.isCancelling
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.cancel_outlined),
            label: Text(context.l10n.tr('admin.reservationDetail.cancel')),
          ),
        ],
      ],
    );
  }
}

class _CustomerCard extends StatelessWidget {
  const _CustomerCard({required this.order, this.onOpenUser});

  final AdminOrderModel order;
  final AdminUserOpener? onOpenUser;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.l10n.tr('admin.reservationDetail.customer'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            AdminDetailLine(
              label: context.l10n.tr('admin.reservationDetail.userName'),
              value: order.userFullName,
            ),
            AdminDetailLine(
              label: context.l10n.tr('admin.reservationDetail.email'),
              value: order.userEmail,
              valueDirection: TextDirection.ltr,
            ),
            AdminDetailLine(
              label: context.l10n.tr('admin.reservationDetail.userId'),
              value: AppFormat.number(context, order.userId),
              valueDirection: TextDirection.ltr,
            ),
            if (onOpenUser != null) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => Future.sync(() => onOpenUser!(order.userId)),
                icon: const Icon(Icons.open_in_new_rounded),
                label: Text(
                  context.l10n.tr('admin.reservationDetail.openUser'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _HardwareCard extends StatelessWidget {
  const _HardwareCard({required this.order});

  final AdminOrderModel order;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.l10n.tr('admin.reservationDetail.hardware'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            AdminDetailLine(label: 'CPU', value: order.cpu),
            AdminDetailLine(label: 'GPU', value: order.gpu),
            AdminDetailLine(label: 'RAM', value: order.ram),
            AdminDetailLine(
              label: context.l10n.tr('admin.reservationDetail.storage'),
              value: order.storage,
            ),
            AdminDetailLine(label: 'OS', value: order.os),
            AdminDetailLine(
              label: context.l10n.tr('admin.reservationDetail.serverId'),
              value: AppFormat.number(context, order.serverId),
              valueDirection: TextDirection.ltr,
            ),
          ],
        ),
      ),
    );
  }
}

class _ScheduleCard extends StatelessWidget {
  const _ScheduleCard({required this.order});

  final AdminOrderModel order;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.l10n.tr('admin.reservationDetail.schedulePayment'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            AdminDetailLine(
              label: context.l10n.tr('admin.reservationDetail.start'),
              value: AppFormat.dateTime(context, order.startTime),
            ),
            AdminDetailLine(
              label: context.l10n.tr('admin.reservationDetail.end'),
              value: AppFormat.dateTime(context, order.endTime),
            ),
            AdminDetailLine(
              label: context.l10n.tr('admin.reservationDetail.total'),
              value: AppFormat.money(
                context,
                order.totalPrice,
                context.l10n.tr('common.toman'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CredentialsAssignmentCard extends StatelessWidget {
  const _CredentialsAssignmentCard({
    required this.order,
    required this.formKey,
    required this.ipController,
    required this.usernameController,
    required this.passwordController,
    required this.obscurePassword,
    required this.revealAssignedPassword,
    required this.ipServerError,
    required this.usernameServerError,
    required this.passwordServerError,
    required this.busy,
    required this.onTogglePassword,
    required this.onToggleAssignedPassword,
    required this.onSubmit,
  });

  final AdminOrderModel order;
  final GlobalKey<FormState> formKey;
  final TextEditingController ipController;
  final TextEditingController usernameController;
  final TextEditingController passwordController;
  final bool obscurePassword;
  final bool revealAssignedPassword;
  final String? ipServerError;
  final String? usernameServerError;
  final String? passwordServerError;
  final bool busy;
  final VoidCallback onTogglePassword;
  final VoidCallback onToggleAssignedPassword;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.key_rounded, color: AppColors.brand700),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    context.l10n.tr('admin.reservationDetail.credentials'),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                AdminProvisioningBadge(
                  credentialsAssigned: order.credentialsAssigned,
                ),
              ],
            ),
            const SizedBox(height: 9),
            Text(
              context.l10n.tr(
                !order.isPaid
                    ? 'admin.reservationDetail.credentialsUnpaid'
                    : order.credentialsAssigned
                    ? 'admin.reservationDetail.credentialsReassignHint'
                    : 'admin.reservationDetail.credentialsHint',
              ),
              style: const TextStyle(color: AppColors.ink500, fontSize: 12),
            ),
            if (order.hasReadableCredentials) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: .07),
                  borderRadius: BorderRadius.circular(AppTheme.controlRadius),
                  border: Border.all(
                    color: AppColors.success.withValues(alpha: .2),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      context.l10n.tr(
                        'admin.reservationDetail.currentCredentials',
                      ),
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppColors.success,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 7),
                    AdminDetailLine(
                      label: context.l10n.tr('admin.reservationDetail.ip'),
                      value: order.assignedIp!,
                      valueDirection: TextDirection.ltr,
                    ),
                    AdminDetailLine(
                      label: context.l10n.tr(
                        'admin.reservationDetail.username',
                      ),
                      value: order.assignedUsername!,
                      valueDirection: TextDirection.ltr,
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: AdminDetailLine(
                            label: context.l10n.tr(
                              'admin.reservationDetail.password',
                            ),
                            value: revealAssignedPassword
                                ? order.assignedPassword!
                                : '••••••••••••',
                            valueDirection: TextDirection.ltr,
                          ),
                        ),
                        IconButton(
                          tooltip: context.l10n.tr(
                            revealAssignedPassword
                                ? 'admin.reservationDetail.hidePassword'
                                : 'admin.reservationDetail.revealPassword',
                          ),
                          onPressed: onToggleAssignedPassword,
                          icon: Icon(
                            revealAssignedPassword
                                ? Icons.visibility_off_rounded
                                : Icons.visibility_rounded,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
            if (order.isPaid) ...[
              const SizedBox(height: 16),
              Form(
                key: formKey,
                child: Column(
                  children: [
                    TextFormField(
                      controller: ipController,
                      enabled: !busy,
                      textDirection: TextDirection.ltr,
                      textAlign: TextAlign.left,
                      maxLength: 100,
                      autocorrect: false,
                      enableSuggestions: false,
                      autofillHints: const <String>[],
                      decoration: InputDecoration(
                        labelText: context.l10n.tr(
                          'admin.reservationDetail.ip',
                        ),
                        errorText: ipServerError,
                      ),
                      validator: (value) => _requiredMax100(context, value),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: usernameController,
                      enabled: !busy,
                      textDirection: TextDirection.ltr,
                      textAlign: TextAlign.left,
                      maxLength: 100,
                      autocorrect: false,
                      enableSuggestions: false,
                      autofillHints: const <String>[],
                      decoration: InputDecoration(
                        labelText: context.l10n.tr(
                          'admin.reservationDetail.username',
                        ),
                        errorText: usernameServerError,
                      ),
                      validator: (value) => _requiredMax100(context, value),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: passwordController,
                      enabled: !busy,
                      textDirection: TextDirection.ltr,
                      textAlign: TextAlign.left,
                      maxLength: 100,
                      obscureText: obscurePassword,
                      autocorrect: false,
                      enableSuggestions: false,
                      autofillHints: const <String>[],
                      decoration: InputDecoration(
                        labelText: context.l10n.tr(
                          'admin.reservationDetail.password',
                        ),
                        errorText: passwordServerError,
                        suffixIcon: IconButton(
                          onPressed: busy ? null : onTogglePassword,
                          icon: Icon(
                            obscurePassword
                                ? Icons.visibility_rounded
                                : Icons.visibility_off_rounded,
                          ),
                        ),
                      ),
                      validator: (value) => _requiredMax100(context, value),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: busy ? null : onSubmit,
                        icon: busy
                            ? const SizedBox.square(
                                dimension: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.key_rounded),
                        label: Text(
                          context.l10n.tr(
                            busy
                                ? 'admin.reservationDetail.assigning'
                                : order.credentialsAssigned
                                ? 'admin.reservationDetail.reassign'
                                : 'admin.reservationDetail.assign',
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String? _requiredMax100(BuildContext context, String? value) {
    final length = value?.trim().length ?? 0;
    if (length == 0) {
      return context.l10n.tr('admin.validation.required');
    }
    if (length > 100) {
      return context.l10n.tr('admin.validation.max100');
    }
    return null;
  }
}
