import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/network/api_failure.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/app_format.dart';
import '../../../../core/widgets/app_status_badge.dart';
import '../../../../core/widgets/async_states.dart';
import '../../../../core/widgets/first_strong_text.dart';
import '../../../catalog/data/server_model.dart';
import '../application/admin_server_providers.dart';
import '../data/admin_server_contracts.dart';
import 'admin_server_presentation.dart';

class AdminServerDetailScreen extends ConsumerStatefulWidget {
  const AdminServerDetailScreen({super.key, required this.serverId});

  final int serverId;

  @override
  ConsumerState<AdminServerDetailScreen> createState() =>
      _AdminServerDetailScreenState();
}

class _AdminServerDetailScreenState
    extends ConsumerState<AdminServerDetailScreen> {
  bool _isDeleting = false;
  final Set<String> _removingWindowIds = <String>{};
  Object? _actionError;

  Future<void> _refresh() async {
    ref.invalidate(adminServersProvider);
    ref.invalidate(adminServerProvider(widget.serverId));
    ref.invalidate(adminServerMaintenanceProvider(widget.serverId));
    try {
      await Future.wait<void>([
        ref.read(adminServerProvider(widget.serverId).future).then((_) {}),
        ref
            .read(adminServerMaintenanceProvider(widget.serverId).future)
            .then((_) {}),
      ]);
    } on Object {
      // The provider-backed body presents the authoritative read failure.
    }
  }

  Future<void> _edit() async {
    final updatedId = await context.push<int>(
      '/admin/servers/${widget.serverId}/edit',
    );
    if (!mounted || updatedId == null) return;
    ref.invalidate(adminServersProvider);
    ref.invalidate(adminServerProvider(widget.serverId));
  }

  Future<void> _softDelete(ServerModel server) async {
    if (_isDeleting || !server.isActive) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded, color: AppColors.danger),
        title: Text(context.l10n.tr('admin.servers.deleteTitle')),
        content: Text(
          context.l10n.tr('admin.servers.deleteBody', <String, Object?>{
            'id': server.id,
          }),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(context.l10n.tr('action.cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(context.l10n.tr('admin.servers.disable')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _isDeleting = true;
      _actionError = null;
    });
    try {
      await ref
          .read(adminServerRepositoryProvider)
          .softDeleteServer(widget.serverId);
      if (!mounted) return;
      ref.invalidate(adminServersProvider);
      ref.invalidate(adminServerProvider(widget.serverId));
      ref.invalidate(adminServerMaintenanceProvider(widget.serverId));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.tr('admin.servers.disabled'))),
      );
    } on Object catch (error) {
      if (mounted) {
        setState(() => _actionError = error);
        ref.invalidate(adminServersProvider);
        ref.invalidate(adminServerProvider(widget.serverId));
      }
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  Future<void> _createMaintenance() async {
    final created = await showModalBottomSheet<AdminMaintenanceWindow>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _CreateMaintenanceSheet(serverId: widget.serverId),
    );
    if (!mounted || created == null) return;
    ref.invalidate(adminServerMaintenanceProvider(widget.serverId));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.l10n.tr('admin.servers.maintenanceCreated')),
      ),
    );
  }

  Future<void> _removeMaintenance(AdminMaintenanceWindow window) async {
    if (_removingWindowIds.contains(window.id)) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.tr('admin.servers.removeMaintenanceTitle')),
        content: Text(context.l10n.tr('admin.servers.removeMaintenanceBody')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(context.l10n.tr('action.cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(context.l10n.tr('admin.servers.removeMaintenance')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _removingWindowIds.add(window.id);
      _actionError = null;
    });
    try {
      await ref
          .read(adminServerRepositoryProvider)
          .removeMaintenance(widget.serverId, window.id);
      if (!mounted) return;
      ref.invalidate(adminServerMaintenanceProvider(widget.serverId));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.tr('admin.servers.maintenanceRemoved')),
        ),
      );
    } on Object catch (error) {
      if (mounted) {
        setState(() => _actionError = error);
        ref.invalidate(adminServerMaintenanceProvider(widget.serverId));
      }
    } finally {
      if (mounted) setState(() => _removingWindowIds.remove(window.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final server = ref.watch(adminServerProvider(widget.serverId));
    return Scaffold(
      appBar: AppBar(
        title: Text(
          context.l10n.tr('admin.servers.serverNumber', <String, Object?>{
            'id': widget.serverId,
          }),
        ),
        actions: [
          IconButton(
            tooltip: context.l10n.tr('action.refresh'),
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
          IconButton(
            tooltip: context.l10n.tr('admin.servers.edit'),
            onPressed: _edit,
            icon: const Icon(Icons.edit_outlined),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: server.when(
        loading: () => const AppLoadingView(),
        error: (error, _) => AppErrorView(
          error: error,
          onRetry: () => ref.invalidate(adminServerProvider(widget.serverId)),
        ),
        data: (value) => _buildBody(value),
      ),
    );
  }

  Widget _buildBody(ServerModel server) {
    final status = AdminServerOperationalStatus.fromWire(
      server.operationalStatus,
    );
    final tier = AdminServerPerformanceTier.fromWire(server.performanceTier);
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 36),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_actionError != null) ...[
                    AdminServerInlineError(error: _actionError!),
                    const SizedBox(height: 12),
                  ],
                  _ServerOverviewCard(
                    server: server,
                    status: status,
                    tier: tier,
                  ),
                  const SizedBox(height: 12),
                  _ServerSpecsCard(server: server),
                  const SizedBox(height: 12),
                  _ManagedConfigurationCard(server: server, tier: tier),
                  const SizedBox(height: 12),
                  _WorkloadCapabilitiesCard(server: server),
                  const SizedBox(height: 18),
                  _MaintenanceSection(
                    serverId: widget.serverId,
                    serverActive: server.isActive,
                    removingWindowIds: _removingWindowIds,
                    onCreate: _createMaintenance,
                    onRemove: _removeMaintenance,
                  ),
                  if (server.isActive) ...[
                    const SizedBox(height: 24),
                    OutlinedButton.icon(
                      onPressed: _isDeleting ? null : () => _softDelete(server),
                      icon: _isDeleting
                          ? const SizedBox.square(
                              dimension: 17,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(
                              Icons.block_rounded,
                              color: AppColors.danger,
                            ),
                      label: Text(
                        context.l10n.tr('admin.servers.disable'),
                        style: const TextStyle(color: AppColors.danger),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ServerOverviewCard extends StatelessWidget {
  const _ServerOverviewCard({
    required this.server,
    required this.status,
    required this.tier,
  });

  final ServerModel server;
  final AdminServerOperationalStatus status;
  final AdminServerPerformanceTier tier;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.inverse, AppColors.inverseRaised],
        ),
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .09),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(Icons.dns_rounded, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  server.gpu.trim().toLowerCase() == 'none'
                      ? server.cpu
                      : server.gpu,
                  textDirection: TextDirection.ltr,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: AdminServerStatusBadge(status: status),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _OverviewMetric(
                label: context.l10n.tr('admin.servers.performanceTier'),
                value: adminServerTierLabel(context, tier),
              ),
              _OverviewMetric(
                label: context.l10n.tr('admin.servers.hourlyPrice'),
                value: AppFormat.money(
                  context,
                  server.pricePerHour,
                  context.l10n.tr('common.toman'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OverviewMetric extends StatelessWidget {
  const _OverviewMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .07),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white60, fontSize: 11),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ServerSpecsCard extends StatelessWidget {
  const _ServerSpecsCard({required this.server});

  final ServerModel server;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.l10n.tr('server.specs'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            AdminServerDetailRow(
              label: 'CPU',
              value: server.cpu,
              valueDirection: TextDirection.ltr,
            ),
            AdminServerDetailRow(
              label: 'GPU',
              value: server.gpu,
              valueDirection: TextDirection.ltr,
            ),
            AdminServerDetailRow(
              label: 'RAM',
              value: server.ram,
              valueDirection: TextDirection.ltr,
            ),
            AdminServerDetailRow(
              label: context.l10n.tr('admin.servers.storage'),
              value: server.storage,
              valueDirection: TextDirection.ltr,
            ),
            AdminServerDetailRow(
              label: 'OS',
              value: server.os,
              valueDirection: TextDirection.ltr,
            ),
            const Divider(height: 22),
            AdminServerDetailRow(
              label: context.l10n.tr('admin.servers.hourlyPrice'),
              value: AppFormat.money(
                context,
                server.pricePerHour,
                context.l10n.tr('common.toman'),
              ),
            ),
            AdminServerDetailRow(
              label: context.l10n.tr('admin.servers.dailyPrice'),
              value: AppFormat.money(
                context,
                server.pricePerDay,
                context.l10n.tr('common.toman'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ManagedConfigurationCard extends StatelessWidget {
  const _ManagedConfigurationCard({required this.server, required this.tier});

  final ServerModel server;
  final AdminServerPerformanceTier tier;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.l10n.tr('admin.servers.managedConfiguration'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            AdminServerDetailRow(
              label: context.l10n.tr('admin.servers.performanceTier'),
              value: adminServerTierLabel(context, tier),
            ),
            AdminServerDetailRow(
              label: context.l10n.tr('admin.servers.cpuCapability'),
              value: '${AppFormat.number(context, server.cpuCapabilityLevel)}%',
            ),
            AdminServerDetailRow(
              label: context.l10n.tr('admin.servers.gpuCapability'),
              value: '${AppFormat.number(context, server.gpuCapabilityLevel)}%',
            ),
            AdminServerDetailRow(
              label: context.l10n.tr('admin.servers.finderEligible'),
              value: context.l10n.tr(
                server.finderEligible
                    ? 'admin.servers.yes'
                    : 'admin.servers.no',
              ),
            ),
            AdminServerDetailRow(
              label: context.l10n.tr('admin.servers.activeState'),
              value: context.l10n.tr(
                server.isActive
                    ? 'admin.servers.active'
                    : 'admin.servers.inactive',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WorkloadCapabilitiesCard extends StatelessWidget {
  const _WorkloadCapabilitiesCard({required this.server});

  final ServerModel server;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.l10n.tr('admin.servers.workloadCapabilities'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            if (server.workloadCapabilities.isEmpty)
              Text(
                context.l10n.tr('admin.servers.noWorkloads'),
                style: const TextStyle(color: AppColors.ink500),
              )
            else
              for (final capability in server.workloadCapabilities)
                AdminServerDetailRow(
                  label: adminServerWorkloadLabel(
                    context,
                    AdminServerWorkloadType.fromWire(capability.workloadType),
                  ),
                  value:
                      '${AppFormat.number(context, capability.suitabilityLevel)}'
                      '/${AppFormat.number(context, 5)}',
                ),
          ],
        ),
      ),
    );
  }
}

class _MaintenanceSection extends ConsumerWidget {
  const _MaintenanceSection({
    required this.serverId,
    required this.serverActive,
    required this.removingWindowIds,
    required this.onCreate,
    required this.onRemove,
  });

  final int serverId;
  final bool serverActive;
  final Set<String> removingWindowIds;
  final VoidCallback onCreate;
  final ValueChanged<AdminMaintenanceWindow> onRemove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final windows = ref.watch(adminServerMaintenanceProvider(serverId));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          context.l10n.tr('admin.servers.maintenanceTitle'),
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: FilledButton.tonalIcon(
            onPressed: serverActive ? onCreate : null,
            icon: const Icon(Icons.add_rounded),
            label: Text(context.l10n.tr('admin.servers.addMaintenance')),
          ),
        ),
        const SizedBox(height: 10),
        if (!serverActive) ...[
          Text(
            context.l10n.tr('admin.servers.maintenanceInactiveHint'),
            style: const TextStyle(color: AppColors.ink500),
          ),
          const SizedBox(height: 10),
        ],
        windows.when(
          loading: () => const Card(
            child: SizedBox(height: 150, child: AppLoadingView(compact: true)),
          ),
          error: (error, _) => Card(
            child: SizedBox(
              height: 190,
              child: AppErrorView(
                compact: true,
                error: error,
                onRetry: () =>
                    ref.invalidate(adminServerMaintenanceProvider(serverId)),
              ),
            ),
          ),
          data: (values) {
            if (values.isEmpty) {
              return Card(
                child: EmptyState(
                  icon: Icons.build_circle_outlined,
                  message: context.l10n.tr('admin.servers.maintenanceEmpty'),
                ),
              );
            }
            return Column(
              children: [
                for (final window in values)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _MaintenanceCard(
                      window: window,
                      isRemoving: removingWindowIds.contains(window.id),
                      onRemove: () => onRemove(window),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _MaintenanceCard extends StatelessWidget {
  const _MaintenanceCard({
    required this.window,
    required this.isRemoving,
    required this.onRemove,
  });

  final AdminMaintenanceWindow window;
  final bool isRemoving;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now().toUtc();
    final (labelKey, color) = now.isBefore(window.startTime)
        ? ('admin.servers.maintenanceUpcoming', AppColors.info)
        : now.isBefore(window.endTime)
        ? ('admin.servers.maintenanceActive', AppColors.warning)
        : ('admin.servers.maintenanceCompleted', AppColors.ink500);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: AppStatusBadge(
                      label: context.l10n.tr(labelKey),
                      color: color,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: context.l10n.tr('admin.servers.removeMaintenance'),
                  onPressed: isRemoving ? null : onRemove,
                  icon: isRemoving
                      ? const SizedBox.square(
                          dimension: 17,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(
                          Icons.delete_outline_rounded,
                          color: AppColors.danger,
                        ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            AdminServerDetailRow(
              label: context.l10n.tr('reservation.start'),
              value: AppFormat.dateTime(context, window.startTime),
            ),
            AdminServerDetailRow(
              label: context.l10n.tr('reservation.end'),
              value: AppFormat.dateTime(context, window.endTime),
            ),
            if (window.reason case final reason?) ...[
              const Divider(height: 20),
              Text(reason, style: const TextStyle(color: AppColors.ink600)),
            ],
          ],
        ),
      ),
    );
  }
}

class _CreateMaintenanceSheet extends ConsumerStatefulWidget {
  const _CreateMaintenanceSheet({required this.serverId});

  final int serverId;

  @override
  ConsumerState<_CreateMaintenanceSheet> createState() =>
      _CreateMaintenanceSheetState();
}

class _CreateMaintenanceSheetState
    extends ConsumerState<_CreateMaintenanceSheet> {
  late DateTime _start = _roundedLocalTime(
    DateTime.now().add(const Duration(hours: 1)),
  );
  late DateTime _end = _start.add(const Duration(hours: 1));
  final TextEditingController _reason = TextEditingController();
  bool _isSubmitting = false;
  Object? _error;
  Map<String, List<String>> _fieldErrors = const <String, List<String>>{};

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<DateTime?> _pickDateTime(DateTime initial) async {
    final now = DateTime.now();
    final firstDate = DateUtils.dateOnly(now);
    final initialDate = initial.isBefore(firstDate) ? firstDate : initial;
    final date = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: DateTime(now.year + 5, 12, 31),
    );
    if (date == null || !mounted) return null;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    setState(() {
      _error = null;
      _fieldErrors = const <String, List<String>>{};
    });
    if (!_start.isAfter(DateTime.now()) || !_end.isAfter(_start)) {
      setState(() => _error = _LocalValidationFailure());
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final result = await ref
          .read(adminServerRepositoryProvider)
          .createMaintenance(
            widget.serverId,
            AdminCreateMaintenanceRequest(
              startTime: _start,
              endTime: _end,
              reason: _reason.text,
            ),
          );
      if (mounted) Navigator.pop(context, result);
    } on Object catch (error) {
      if (mounted) {
        final failure = ApiFailure.from(error);
        setState(() {
          _error = error;
          _fieldErrors = failure.fieldErrors;
        });
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  String? _fieldError(String field) {
    final normalized = field.toLowerCase();
    for (final entry in _fieldErrors.entries) {
      if (entry.key.toLowerCase() == normalized && entry.value.isNotEmpty) {
        return entry.value.first;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
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
            const SizedBox(height: 20),
            Text(
              context.l10n.tr('admin.servers.addMaintenance'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 6),
            Text(
              context.l10n.tr('admin.servers.maintenanceHelp'),
              style: const TextStyle(color: AppColors.ink600),
            ),
            const SizedBox(height: 18),
            _MaintenanceDateButton(
              icon: Icons.play_circle_outline_rounded,
              label: context.l10n.tr('reservation.start'),
              value: _start,
              errorText: _fieldError('StartTime'),
              onPressed: _isSubmitting
                  ? null
                  : () async {
                      final value = await _pickDateTime(_start);
                      if (value == null || !mounted) return;
                      setState(() {
                        _start = value;
                        if (!_end.isAfter(_start)) {
                          _end = _start.add(const Duration(hours: 1));
                        }
                      });
                    },
            ),
            const SizedBox(height: 10),
            _MaintenanceDateButton(
              icon: Icons.stop_circle_outlined,
              label: context.l10n.tr('reservation.end'),
              value: _end,
              errorText: _fieldError('EndTime'),
              onPressed: _isSubmitting
                  ? null
                  : () async {
                      final value = await _pickDateTime(_end);
                      if (value != null && mounted) {
                        setState(() => _end = value);
                      }
                    },
            ),
            const SizedBox(height: 12),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _reason,
              builder: (context, value, _) => TextField(
                controller: _reason,
                enabled: !_isSubmitting,
                minLines: 2,
                maxLines: 4,
                maxLength: 300,
                textDirection: value.text.trim().isEmpty
                    ? Directionality.of(context)
                    : firstStrongTextDirection(value.text),
                textAlign: TextAlign.start,
                decoration: InputDecoration(
                  labelText: context.l10n.tr('admin.servers.maintenanceReason'),
                  errorText: _fieldError('Reason'),
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              if (_error is _LocalValidationFailure)
                Text(
                  context.l10n.tr('admin.servers.maintenanceTimeInvalid'),
                  style: const TextStyle(color: AppColors.danger),
                )
              else
                AdminServerInlineError(error: _error!),
            ],
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _isSubmitting ? null : _submit,
              icon: _isSubmitting
                  ? const SizedBox.square(
                      dimension: 17,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.build_rounded),
              label: Text(context.l10n.tr('admin.servers.createMaintenance')),
            ),
            TextButton(
              onPressed: _isSubmitting ? null : () => Navigator.pop(context),
              child: Text(context.l10n.tr('action.cancel')),
            ),
          ],
        ),
      ),
    );
  }
}

class _MaintenanceDateButton extends StatelessWidget {
  const _MaintenanceDateButton({
    required this.icon,
    required this.label,
    required this.value,
    required this.onPressed,
    this.errorText,
  });

  final IconData icon;
  final String label;
  final DateTime value;
  final VoidCallback? onPressed;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton(
          onPressed: onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                Icon(icon, color: AppColors.brand700),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(
                          color: AppColors.ink500,
                          fontSize: 11,
                        ),
                      ),
                      Text(
                        AppFormat.dateTime(context, value),
                        style: const TextStyle(
                          color: AppColors.ink900,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.edit_calendar_outlined, size: 19),
              ],
            ),
          ),
        ),
        if (errorText != null)
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 12, top: 5),
            child: Text(
              errorText!,
              style: const TextStyle(color: AppColors.danger, fontSize: 12),
            ),
          ),
      ],
    );
  }
}

DateTime _roundedLocalTime(DateTime value) {
  return DateTime(value.year, value.month, value.day, value.hour, 0);
}

class _LocalValidationFailure implements Exception {}
