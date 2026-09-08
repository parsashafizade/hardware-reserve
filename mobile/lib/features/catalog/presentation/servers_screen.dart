import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/network/api_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/app_format.dart';
import '../../../core/widgets/async_states.dart';
import '../../../core/widgets/first_strong_text.dart';
import '../data/server_model.dart';
import 'server_card.dart';

class ServersScreen extends ConsumerStatefulWidget {
  const ServersScreen({super.key});

  @override
  ConsumerState<ServersScreen> createState() => _ServersScreenState();
}

class _ServersScreenState extends ConsumerState<ServersScreen> {
  final _searchController = TextEditingController();
  late Future<List<ServerModel>> _serversFuture;
  _CatalogFilters _filters = const _CatalogFilters();

  @override
  void initState() {
    super.initState();
    _serversFuture = ref.read(serverRepositoryProvider).getServers();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_onSearchChanged)
      ..dispose();
    super.dispose();
  }

  void _onSearchChanged() => setState(() {});

  Future<void> _reload() async {
    final future = ref.read(serverRepositoryProvider).getServers();
    setState(() => _serversFuture = future);
    await future;
  }

  List<ServerModel> _visibleServers(List<ServerModel> servers) {
    final query = _searchController.text.trim().toLowerCase();
    return servers
        .where((server) {
          final matchesQuery =
              query.isEmpty ||
              <String>[
                server.cpu,
                server.gpu,
                server.ram,
                server.storage,
                server.os,
              ].any((value) => value.toLowerCase().contains(query));
          return matchesQuery && _filters.matches(server);
        })
        .toList(growable: false);
  }

  Future<void> _showFilters(List<ServerModel> servers) async {
    final result = await showModalBottomSheet<_CatalogFilters>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppTheme.panelRadius),
        ),
      ),
      builder: (context) =>
          _ServerFilterSheet(servers: servers, initial: _filters),
    );
    if (result != null && mounted) setState(() => _filters = result);
  }

  void _clearAll() {
    _searchController.clear();
    setState(() => _filters = const _CatalogFilters());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.tr('servers.title'))),
      body: FutureBuilder<List<ServerModel>>(
        future: _serversFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const AppLoadingView();
          }
          if (snapshot.hasError) {
            return AppErrorView(
              error: snapshot.error!,
              onRetry: () => _reload(),
            );
          }

          final servers = snapshot.data ?? const <ServerModel>[];
          final visible = _visibleServers(servers);
          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 28),
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 760),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          context.l10n.tr('servers.subtitle'),
                          style: const TextStyle(color: AppColors.ink500),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _searchController,
                                textInputAction: TextInputAction.search,
                                textDirection:
                                    _searchController.text.trim().isEmpty
                                    ? Directionality.of(context)
                                    : firstStrongTextDirection(
                                        _searchController.text,
                                      ),
                                textAlign: TextAlign.start,
                                decoration: InputDecoration(
                                  hintText: context.l10n.tr('servers.search'),
                                  prefixIcon: const Icon(Icons.search_rounded),
                                  suffixIcon: _searchController.text.isEmpty
                                      ? null
                                      : IconButton(
                                          onPressed: _searchController.clear,
                                          icon: const Icon(Icons.close_rounded),
                                        ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Badge(
                              isLabelVisible: _filters.activeCount > 0,
                              label: Text(
                                AppFormat.number(context, _filters.activeCount),
                              ),
                              child: IconButton.filledTonal(
                                tooltip: context.l10n.tr('servers.filters'),
                                onPressed: () => _showFilters(servers),
                                icon: const Icon(Icons.tune_rounded),
                              ),
                            ),
                          ],
                        ),
                        if (_filters.activeCount > 0) ...[
                          const SizedBox(height: 8),
                          Align(
                            alignment: AlignmentDirectional.centerStart,
                            child: TextButton.icon(
                              onPressed: () => setState(
                                () => _filters = const _CatalogFilters(),
                              ),
                              icon: const Icon(Icons.filter_alt_off_rounded),
                              label: Text(
                                context.l10n.tr('servers.clearFilters'),
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        if (visible.isEmpty)
                          SizedBox(
                            height: 360,
                            child: EmptyState(
                              icon: Icons.dns_outlined,
                              message: context.l10n.tr('servers.noResult'),
                              action: OutlinedButton.icon(
                                onPressed: _clearAll,
                                icon: const Icon(Icons.restart_alt_rounded),
                                label: Text(
                                  context.l10n.tr('servers.clearFilters'),
                                ),
                              ),
                            ),
                          )
                        else ...[
                          Padding(
                            padding: const EdgeInsetsDirectional.only(
                              start: 2,
                              bottom: 10,
                            ),
                            child: Text(
                              AppFormat.number(context, visible.length),
                              style: const TextStyle(
                                color: AppColors.ink500,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          for (final server in visible) ...[
                            ServerCard(
                              server: server,
                              onPressed: () =>
                                  context.push('/servers/${server.id}'),
                            ),
                            const SizedBox(height: 12),
                          ],
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ServerFilterSheet extends StatefulWidget {
  const _ServerFilterSheet({required this.servers, required this.initial});
  final List<ServerModel> servers;
  final _CatalogFilters initial;

  @override
  State<_ServerFilterSheet> createState() => _ServerFilterSheetState();
}

class _ServerFilterSheetState extends State<_ServerFilterSheet> {
  late _CatalogFilters _value = widget.initial;

  List<String> _values(String Function(ServerModel) select) {
    return widget.servers
        .map(select)
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: .82,
      minChildSize: .52,
      maxChildSize: .94,
      builder: (context, controller) => Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 42,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(20, 18, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    context.l10n.tr('servers.filters'),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                TextButton(
                  onPressed: () =>
                      setState(() => _value = const _CatalogFilters()),
                  child: Text(context.l10n.tr('servers.clearFilters')),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              controller: controller,
              padding: const EdgeInsetsDirectional.fromSTEB(20, 4, 20, 20),
              children: [
                _FilterSection(
                  title: 'CPU',
                  values: _values((server) => server.cpu),
                  selected: _value.cpu,
                  onSelected: (value) =>
                      setState(() => _value = _value.withCpu(value)),
                ),
                _FilterSection(
                  title: 'GPU',
                  values: _values((server) => server.gpu),
                  selected: _value.gpu,
                  onSelected: (value) =>
                      setState(() => _value = _value.withGpu(value)),
                ),
                _FilterSection(
                  title: 'RAM',
                  values: _values((server) => server.ram),
                  selected: _value.ram,
                  onSelected: (value) =>
                      setState(() => _value = _value.withRam(value)),
                ),
                _FilterSection(
                  title: context.l10n.tr('servers.storage'),
                  values: _values((server) => server.storage),
                  selected: _value.storage,
                  onSelected: (value) =>
                      setState(() => _value = _value.withStorage(value)),
                ),
                _FilterSection(
                  title: 'OS',
                  values: _values((server) => server.os),
                  selected: _value.os,
                  onSelected: (value) =>
                      setState(() => _value = _value.withOs(value)),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(20, 10, 20, 18),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => Navigator.of(context).pop(_value),
                icon: const Icon(Icons.check_rounded),
                label: Text(context.l10n.tr('action.confirm')),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterSection extends StatelessWidget {
  const _FilterSection({
    required this.title,
    required this.values,
    required this.selected,
    required this.onSelected,
  });

  final String title;
  final List<String> values;
  final String? selected;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 9),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final value in values)
                FilterChip(
                  selected: selected == value,
                  label: Text(value, textDirection: TextDirection.ltr),
                  onSelected: (enabled) => onSelected(enabled ? value : null),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CatalogFilters {
  const _CatalogFilters({this.cpu, this.gpu, this.ram, this.storage, this.os});
  final String? cpu;
  final String? gpu;
  final String? ram;
  final String? storage;
  final String? os;

  int get activeCount =>
      <String?>[cpu, gpu, ram, storage, os].whereType<String>().length;

  bool matches(ServerModel server) =>
      (cpu == null || server.cpu == cpu) &&
      (gpu == null || server.gpu == gpu) &&
      (ram == null || server.ram == ram) &&
      (storage == null || server.storage == storage) &&
      (os == null || server.os == os);

  _CatalogFilters withCpu(String? value) =>
      _CatalogFilters(cpu: value, gpu: gpu, ram: ram, storage: storage, os: os);
  _CatalogFilters withGpu(String? value) =>
      _CatalogFilters(cpu: cpu, gpu: value, ram: ram, storage: storage, os: os);
  _CatalogFilters withRam(String? value) =>
      _CatalogFilters(cpu: cpu, gpu: gpu, ram: value, storage: storage, os: os);
  _CatalogFilters withStorage(String? value) =>
      _CatalogFilters(cpu: cpu, gpu: gpu, ram: ram, storage: value, os: os);
  _CatalogFilters withOs(String? value) => _CatalogFilters(
    cpu: cpu,
    gpu: gpu,
    ram: ram,
    storage: storage,
    os: value,
  );
}
