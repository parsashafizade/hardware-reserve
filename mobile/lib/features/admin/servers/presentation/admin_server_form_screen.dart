import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/network/api_failure.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/app_format.dart';
import '../../../../core/widgets/async_states.dart';
import '../../../catalog/data/server_model.dart';
import '../application/admin_server_providers.dart';
import '../data/admin_server_contracts.dart';
import 'admin_server_presentation.dart';

class AdminServerFormScreen extends ConsumerWidget {
  const AdminServerFormScreen({super.key, this.serverId});

  final int? serverId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = serverId;
    if (id == null) {
      return const _AdminServerEditor();
    }

    final server = ref.watch(adminServerProvider(id));
    return server.when(
      loading: () => Scaffold(
        appBar: AppBar(title: Text(context.l10n.tr('admin.servers.edit'))),
        body: const AppLoadingView(),
      ),
      error: (error, _) => Scaffold(
        appBar: AppBar(title: Text(context.l10n.tr('admin.servers.edit'))),
        body: AppErrorView(
          error: error,
          onRetry: () => ref.invalidate(adminServerProvider(id)),
        ),
      ),
      data: (value) => _AdminServerEditor(
        key: ValueKey<int>(value.id),
        initialServer: value,
      ),
    );
  }
}

class _AdminServerEditor extends ConsumerStatefulWidget {
  const _AdminServerEditor({super.key, this.initialServer});

  final ServerModel? initialServer;

  @override
  ConsumerState<_AdminServerEditor> createState() => _AdminServerEditorState();
}

class _AdminServerEditorState extends ConsumerState<_AdminServerEditor> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _cpu;
  late final TextEditingController _gpu;
  late final TextEditingController _ram;
  late final TextEditingController _storage;
  late final TextEditingController _os;
  late final TextEditingController _hourlyPrice;
  late final TextEditingController _dailyPrice;
  late bool _isActive;
  late bool _finderEligible;
  late AdminServerOperationalStatus _operationalStatus;
  late AdminServerPerformanceTier _performanceTier;
  late int _cpuCapability;
  late int _gpuCapability;
  late Map<AdminServerWorkloadType, int> _workloads;
  bool _isSubmitting = false;
  bool _ambiguousCreateFailure = false;
  Object? _error;
  Map<String, List<String>> _fieldErrors = const <String, List<String>>{};

  bool get _editing => widget.initialServer != null;

  @override
  void initState() {
    super.initState();
    final server = widget.initialServer;
    _cpu = TextEditingController(text: server?.cpu ?? '');
    _gpu = TextEditingController(text: server?.gpu ?? '');
    _ram = TextEditingController(text: server?.ram ?? '');
    _storage = TextEditingController(text: server?.storage ?? '');
    _os = TextEditingController(text: server?.os ?? '');
    _hourlyPrice = TextEditingController(
      text: server == null ? '' : _formatNumber(server.pricePerHour),
    );
    _dailyPrice = TextEditingController(
      text: server == null ? '' : _formatNumber(server.pricePerDay),
    );
    _isActive = server?.isActive ?? true;
    _finderEligible = server?.finderEligible ?? true;
    _operationalStatus = server == null
        ? AdminServerOperationalStatus.available
        : AdminServerOperationalStatus.fromWire(server.operationalStatus);
    _performanceTier = server == null
        ? AdminServerPerformanceTier.standard
        : AdminServerPerformanceTier.fromWire(server.performanceTier);
    _cpuCapability = server?.cpuCapabilityLevel ?? 50;
    _gpuCapability = server?.gpuCapabilityLevel ?? 0;
    _workloads = <AdminServerWorkloadType, int>{
      if (server != null)
        for (final item in server.workloadCapabilities)
          AdminServerWorkloadType.fromWire(item.workloadType):
              item.suitabilityLevel,
    };
  }

  @override
  void dispose() {
    _cpu.dispose();
    _gpu.dispose();
    _ram.dispose();
    _storage.dispose();
    _os.dispose();
    _hourlyPrice.dispose();
    _dailyPrice.dispose();
    super.dispose();
  }

  String? _backendFieldError(String fieldName) {
    final normalized = fieldName.toLowerCase();
    for (final entry in _fieldErrors.entries) {
      if (entry.key.toLowerCase() == normalized && entry.value.isNotEmpty) {
        return entry.value.first;
      }
    }
    return null;
  }

  void _clearBackendField(String fieldName) {
    if (_fieldErrors.isEmpty) return;
    final updated = <String, List<String>>{};
    for (final entry in _fieldErrors.entries) {
      if (entry.key.toLowerCase() != fieldName.toLowerCase()) {
        updated[entry.key] = entry.value;
      }
    }
    if (updated.length != _fieldErrors.length) {
      setState(() => _fieldErrors = Map.unmodifiable(updated));
    }
  }

  String? _requiredValidator(String? value, String backendField) {
    final backendError = _backendFieldError(backendField);
    if (backendError != null) return backendError;
    if (value == null || value.trim().isEmpty) {
      return context.l10n.tr('admin.validation.required');
    }
    return null;
  }

  String? _priceValidator(String? value, String backendField) {
    final required = _requiredValidator(value, backendField);
    if (required != null) return required;
    final parsed = _parseNumber(value!);
    if (parsed == null) {
      return context.l10n.tr('admin.validation.number');
    }
    if (parsed <= 0) {
      return context.l10n.tr('admin.validation.positive');
    }
    return null;
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    setState(() {
      _error = null;
      _ambiguousCreateFailure = false;
      _fieldErrors = const <String, List<String>>{};
    });
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final request = AdminServerUpsertRequest(
      cpu: _cpu.text,
      gpu: _gpu.text,
      ram: _ram.text,
      storage: _storage.text,
      os: _os.text,
      pricePerHour: _parseNumber(_hourlyPrice.text)!,
      pricePerDay: _parseNumber(_dailyPrice.text)!,
      isActive: _isActive,
      operationalStatus: _operationalStatus,
      finderEligible: _finderEligible,
      cpuCapabilityLevel: _cpuCapability,
      gpuCapabilityLevel: _gpuCapability,
      performanceTier: _performanceTier,
      workloadCapabilities: Map<AdminServerWorkloadType, int>.unmodifiable(
        _workloads,
      ),
    );

    setState(() => _isSubmitting = true);
    try {
      final repository = ref.read(adminServerRepositoryProvider);
      final result = _editing
          ? await repository.updateServer(widget.initialServer!.id, request)
          : await repository.createServer(request);
      ref.invalidate(adminServersProvider);
      ref.invalidate(adminServerProvider(result.id));
      if (mounted) Navigator.pop(context, result.id);
    } on Object catch (error) {
      if (mounted) {
        final failure = ApiFailure.from(error);
        setState(() {
          _error = error;
          _fieldErrors = failure.fieldErrors;
          _ambiguousCreateFailure =
              !_editing && isAmbiguousAdminServerFailure(error);
        });
        _formKey.currentState?.validate();
        ref.invalidate(adminServersProvider);
        if (_editing) {
          ref.invalidate(adminServerProvider(widget.initialServer!.id));
        }
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          context.l10n.tr(
            _editing ? 'admin.servers.editTitle' : 'admin.servers.createTitle',
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 36),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_error != null) ...[
                        AdminServerInlineError(error: _error!),
                        if (_fieldErrors.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          _BackendValidationDetails(errors: _fieldErrors),
                        ],
                        if (_ambiguousCreateFailure) ...[
                          const SizedBox(height: 8),
                          Text(
                            context.l10n.tr(
                              'admin.servers.verifyCreateBeforeRetry',
                            ),
                            style: const TextStyle(
                              color: AppColors.warning,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                      ],
                      _HardwareFieldsCard(
                        cpu: _cpu,
                        gpu: _gpu,
                        ram: _ram,
                        storage: _storage,
                        os: _os,
                        enabled: !_isSubmitting,
                        validator: _requiredValidator,
                        onChanged: _clearBackendField,
                      ),
                      const SizedBox(height: 12),
                      _PricingFieldsCard(
                        hourly: _hourlyPrice,
                        daily: _dailyPrice,
                        enabled: !_isSubmitting,
                        validator: _priceValidator,
                        onChanged: _clearBackendField,
                      ),
                      const SizedBox(height: 12),
                      _AvailabilityCard(
                        isActive: _isActive,
                        finderEligible: _finderEligible,
                        operationalStatus: _operationalStatus,
                        enabled: !_isSubmitting,
                        statusError: _backendFieldError('OperationalStatus'),
                        onActiveChanged: (value) {
                          setState(() {
                            _isActive = value;
                            _operationalStatus = value
                                ? AdminServerOperationalStatus.available
                                : AdminServerOperationalStatus.disabled;
                          });
                        },
                        onFinderChanged: (value) =>
                            setState(() => _finderEligible = value),
                        onStatusChanged: (value) {
                          if (value == null) return;
                          setState(() {
                            _operationalStatus = value;
                            _isActive =
                                value != AdminServerOperationalStatus.disabled;
                          });
                          _clearBackendField('OperationalStatus');
                        },
                      ),
                      const SizedBox(height: 12),
                      _CapabilityCard(
                        performanceTier: _performanceTier,
                        cpuCapability: _cpuCapability,
                        gpuCapability: _gpuCapability,
                        enabled: !_isSubmitting,
                        tierError: _backendFieldError('PerformanceTier'),
                        onTierChanged: (value) {
                          if (value == null) return;
                          setState(() => _performanceTier = value);
                          _clearBackendField('PerformanceTier');
                        },
                        onCpuChanged: (value) =>
                            setState(() => _cpuCapability = value.round()),
                        onGpuChanged: (value) =>
                            setState(() => _gpuCapability = value.round()),
                      ),
                      const SizedBox(height: 12),
                      _WorkloadEditorCard(
                        workloads: _workloads,
                        enabled: !_isSubmitting,
                        onChanged: (value) =>
                            setState(() => _workloads = value),
                      ),
                      const SizedBox(height: 20),
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
                            : Icon(
                                _editing
                                    ? Icons.save_outlined
                                    : Icons.add_rounded,
                              ),
                        label: Text(
                          context.l10n.tr(
                            _editing
                                ? 'admin.servers.saveChanges'
                                : 'admin.servers.create',
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
      ),
    );
  }
}

class _HardwareFieldsCard extends StatelessWidget {
  const _HardwareFieldsCard({
    required this.cpu,
    required this.gpu,
    required this.ram,
    required this.storage,
    required this.os,
    required this.enabled,
    required this.validator,
    required this.onChanged,
  });

  final TextEditingController cpu;
  final TextEditingController gpu;
  final TextEditingController ram;
  final TextEditingController storage;
  final TextEditingController os;
  final bool enabled;
  final String? Function(String?, String) validator;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.l10n.tr('admin.servers.hardware'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 14),
            _TechnicalTextField(
              controller: cpu,
              label: 'CPU',
              maxLength: 120,
              enabled: enabled,
              validator: (value) => validator(value, 'CPU'),
              onChanged: (_) => onChanged('CPU'),
            ),
            const SizedBox(height: 12),
            _TechnicalTextField(
              controller: gpu,
              label: 'GPU',
              maxLength: 120,
              enabled: enabled,
              validator: (value) => validator(value, 'GPU'),
              onChanged: (_) => onChanged('GPU'),
            ),
            const SizedBox(height: 12),
            _TechnicalTextField(
              controller: ram,
              label: 'RAM',
              maxLength: 40,
              enabled: enabled,
              validator: (value) => validator(value, 'RAM'),
              onChanged: (_) => onChanged('RAM'),
            ),
            const SizedBox(height: 12),
            _TechnicalTextField(
              controller: storage,
              label: context.l10n.tr('admin.servers.storage'),
              maxLength: 40,
              enabled: enabled,
              validator: (value) => validator(value, 'Storage'),
              onChanged: (_) => onChanged('Storage'),
            ),
            const SizedBox(height: 12),
            _TechnicalTextField(
              controller: os,
              label: 'OS',
              maxLength: 100,
              enabled: enabled,
              validator: (value) => validator(value, 'OS'),
              onChanged: (_) => onChanged('OS'),
            ),
          ],
        ),
      ),
    );
  }
}

class _TechnicalTextField extends StatelessWidget {
  const _TechnicalTextField({
    required this.controller,
    required this.label,
    required this.maxLength,
    required this.enabled,
    required this.validator,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final int maxLength;
  final bool enabled;
  final FormFieldValidator<String> validator;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      maxLength: maxLength,
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.start,
      validator: validator,
      onChanged: onChanged,
      decoration: InputDecoration(labelText: label, counterText: ''),
    );
  }
}

class _PricingFieldsCard extends StatelessWidget {
  const _PricingFieldsCard({
    required this.hourly,
    required this.daily,
    required this.enabled,
    required this.validator,
    required this.onChanged,
  });

  final TextEditingController hourly;
  final TextEditingController daily;
  final bool enabled;
  final String? Function(String?, String) validator;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.l10n.tr('admin.servers.pricing'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              context.l10n.tr('admin.servers.pricingHelp'),
              style: const TextStyle(color: AppColors.ink500),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: hourly,
              enabled: enabled,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              textDirection: TextDirection.ltr,
              textAlign: TextAlign.start,
              validator: (value) => validator(value, 'PricePerHour'),
              onChanged: (_) => onChanged('PricePerHour'),
              decoration: InputDecoration(
                labelText: context.l10n.tr('admin.servers.hourlyPrice'),
                suffixText: context.l10n.tr('common.toman'),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: daily,
              enabled: enabled,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              textDirection: TextDirection.ltr,
              textAlign: TextAlign.start,
              validator: (value) => validator(value, 'PricePerDay'),
              onChanged: (_) => onChanged('PricePerDay'),
              decoration: InputDecoration(
                labelText: context.l10n.tr('admin.servers.dailyPrice'),
                suffixText: context.l10n.tr('common.toman'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AvailabilityCard extends StatelessWidget {
  const _AvailabilityCard({
    required this.isActive,
    required this.finderEligible,
    required this.operationalStatus,
    required this.enabled,
    required this.statusError,
    required this.onActiveChanged,
    required this.onFinderChanged,
    required this.onStatusChanged,
  });

  final bool isActive;
  final bool finderEligible;
  final AdminServerOperationalStatus operationalStatus;
  final bool enabled;
  final String? statusError;
  final ValueChanged<bool> onActiveChanged;
  final ValueChanged<bool> onFinderChanged;
  final ValueChanged<AdminServerOperationalStatus?> onStatusChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 14, 10, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                context.l10n.tr('admin.servers.availability'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            SwitchListTile.adaptive(
              value: isActive,
              onChanged: enabled ? onActiveChanged : null,
              title: Text(context.l10n.tr('admin.servers.activeState')),
              subtitle: Text(context.l10n.tr('admin.servers.activeHelp')),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: DropdownButtonFormField<AdminServerOperationalStatus>(
                key: ValueKey<AdminServerOperationalStatus>(operationalStatus),
                initialValue: operationalStatus,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: context.l10n.tr('admin.servers.status'),
                  errorText: statusError,
                ),
                items: [
                  for (final status in AdminServerOperationalStatus.values)
                    DropdownMenuItem(
                      value: status,
                      child: Text(adminServerStatusLabel(context, status)),
                    ),
                ],
                onChanged: enabled ? onStatusChanged : null,
              ),
            ),
            SwitchListTile.adaptive(
              value: finderEligible,
              onChanged: enabled ? onFinderChanged : null,
              title: Text(context.l10n.tr('admin.servers.finderEligible')),
              subtitle: Text(context.l10n.tr('admin.servers.finderHelp')),
            ),
          ],
        ),
      ),
    );
  }
}

class _CapabilityCard extends StatelessWidget {
  const _CapabilityCard({
    required this.performanceTier,
    required this.cpuCapability,
    required this.gpuCapability,
    required this.enabled,
    required this.tierError,
    required this.onTierChanged,
    required this.onCpuChanged,
    required this.onGpuChanged,
  });

  final AdminServerPerformanceTier performanceTier;
  final int cpuCapability;
  final int gpuCapability;
  final bool enabled;
  final String? tierError;
  final ValueChanged<AdminServerPerformanceTier?> onTierChanged;
  final ValueChanged<double> onCpuChanged;
  final ValueChanged<double> onGpuChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.l10n.tr('admin.servers.capabilities'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<AdminServerPerformanceTier>(
              initialValue: performanceTier,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: context.l10n.tr('admin.servers.performanceTier'),
                errorText: tierError,
              ),
              items: [
                for (final tier in AdminServerPerformanceTier.values)
                  DropdownMenuItem(
                    value: tier,
                    child: Text(adminServerTierLabel(context, tier)),
                  ),
              ],
              onChanged: enabled ? onTierChanged : null,
            ),
            const SizedBox(height: 18),
            _CapabilitySlider(
              label: context.l10n.tr('admin.servers.cpuCapability'),
              value: cpuCapability,
              enabled: enabled,
              onChanged: onCpuChanged,
            ),
            _CapabilitySlider(
              label: context.l10n.tr('admin.servers.gpuCapability'),
              value: gpuCapability,
              enabled: enabled,
              onChanged: onGpuChanged,
            ),
          ],
        ),
      ),
    );
  }
}

class _CapabilitySlider extends StatelessWidget {
  const _CapabilitySlider({
    required this.label,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final String label;
  final int value;
  final bool enabled;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text(label)),
            Text(
              '${AppFormat.number(context, value)}%',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        Slider(
          value: value.toDouble(),
          min: 0,
          max: 100,
          divisions: 20,
          label: '$value%',
          onChanged: enabled ? onChanged : null,
        ),
      ],
    );
  }
}

class _WorkloadEditorCard extends StatelessWidget {
  const _WorkloadEditorCard({
    required this.workloads,
    required this.enabled,
    required this.onChanged,
  });

  final Map<AdminServerWorkloadType, int> workloads;
  final bool enabled;
  final ValueChanged<Map<AdminServerWorkloadType, int>> onChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 16, 10, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                context.l10n.tr('admin.servers.workloadCapabilities'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 5, 8, 8),
              child: Text(
                context.l10n.tr('admin.servers.workloadHelp'),
                style: const TextStyle(color: AppColors.ink500),
              ),
            ),
            for (final workload in AdminServerWorkloadType.values)
              _WorkloadEditorRow(
                workload: workload,
                suitability: workloads[workload],
                enabled: enabled,
                onEnabledChanged: (selected) {
                  final updated = <AdminServerWorkloadType, int>{...workloads};
                  if (selected) {
                    updated[workload] = 3;
                  } else {
                    updated.remove(workload);
                  }
                  onChanged(updated);
                },
                onSuitabilityChanged: (level) {
                  if (level == null) return;
                  onChanged(<AdminServerWorkloadType, int>{
                    ...workloads,
                    workload: level,
                  });
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _WorkloadEditorRow extends StatelessWidget {
  const _WorkloadEditorRow({
    required this.workload,
    required this.suitability,
    required this.enabled,
    required this.onEnabledChanged,
    required this.onSuitabilityChanged,
  });

  final AdminServerWorkloadType workload;
  final int? suitability;
  final bool enabled;
  final ValueChanged<bool> onEnabledChanged;
  final ValueChanged<int?> onSuitabilityChanged;

  @override
  Widget build(BuildContext context) {
    final selected = suitability != null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Checkbox.adaptive(
            value: selected,
            onChanged: enabled
                ? (value) => onEnabledChanged(value ?? false)
                : null,
          ),
          Expanded(child: Text(adminServerWorkloadLabel(context, workload))),
          const SizedBox(width: 8),
          SizedBox(
            width: 92,
            child: DropdownButtonFormField<int>(
              key: ValueKey<String>(
                '${workload.wireValue}-${suitability ?? 'off'}',
              ),
              initialValue: suitability,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: context.l10n.tr('admin.servers.suitability'),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 10,
                ),
              ),
              items: [
                for (var level = 1; level <= 5; level++)
                  DropdownMenuItem(
                    value: level,
                    child: Text(AppFormat.number(context, level)),
                  ),
              ],
              onChanged: enabled && selected ? onSuitabilityChanged : null,
            ),
          ),
        ],
      ),
    );
  }
}

String _formatNumber(double value) {
  return value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toString();
}

double? _parseNumber(String input) {
  const persian = '۰۱۲۳۴۵۶۷۸۹';
  const arabic = '٠١٢٣٤٥٦٧٨٩';
  var normalized = input.trim();
  for (var index = 0; index < 10; index++) {
    normalized = normalized
        .replaceAll(persian[index], '$index')
        .replaceAll(arabic[index], '$index');
  }
  normalized = normalized
      .replaceAll(',', '')
      .replaceAll('٬', '')
      .replaceAll('٫', '.');
  return double.tryParse(normalized);
}

class _BackendValidationDetails extends StatelessWidget {
  const _BackendValidationDetails({required this.errors});

  final Map<String, List<String>> errors;

  @override
  Widget build(BuildContext context) {
    final messages = errors.values.expand((items) => items).toSet().toList();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(AppTheme.controlRadius),
        border: Border.all(color: AppColors.warning.withValues(alpha: .2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.l10n.tr('admin.validation.backendDetails'),
            style: const TextStyle(
              color: AppColors.warning,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 5),
          for (final message in messages)
            Text('• $message', style: const TextStyle(color: AppColors.ink700)),
        ],
      ),
    );
  }
}
