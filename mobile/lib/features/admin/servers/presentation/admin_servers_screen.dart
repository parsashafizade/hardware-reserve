import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/app_format.dart';
import '../../../../core/widgets/async_states.dart';
import '../../../../core/widgets/first_strong_text.dart';
import '../../../catalog/data/server_model.dart';
import '../application/admin_server_providers.dart';
import '../data/admin_server_contracts.dart';
import 'admin_server_presentation.dart';

class AdminServersScreen extends ConsumerStatefulWidget {
  const AdminServersScreen({super.key});

  @override
  ConsumerState<AdminServersScreen> createState() => _AdminServersScreenState();
}

class _AdminServersScreenState extends ConsumerState<AdminServersScreen> {
  final TextEditingController _searchController = TextEditingController();
  AdminServerOperationalStatus? _statusFilter;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() => setState(() {});

  @override
  void dispose() {
    _searchController
      ..removeListener(_onSearchChanged)
      ..dispose();
    super.dispose();
  }

  List<ServerModel> _visibleServers(List<ServerModel> servers) {
    final query = _searchController.text.trim().toLowerCase();
    return servers
        .where((server) {
          final statusMatches =
              _statusFilter == null ||
              server.operationalStatus.toLowerCase() ==
                  _statusFilter!.wireValue.toLowerCase();
          if (!statusMatches) return false;
          if (query.isEmpty) return true;
          return server.id.toString() == query ||
              server.cpu.toLowerCase().contains(query) ||
              server.gpu.toLowerCase().contains(query) ||
              server.ram.toLowerCase().contains(query) ||
              server.storage.toLowerCase().contains(query) ||
              server.os.toLowerCase().contains(query);
        })
        .toList(growable: false);
  }

  Future<void> _openCreate() async {
    final createdId = await context.push<int>('/admin/servers/new');
    if (!mounted || createdId == null) return;
    ref.invalidate(adminServersProvider);
    await context.push<void>('/admin/servers/$createdId');
  }

  @override
  Widget build(BuildContext context) {
    final servers = ref.watch(adminServersProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.tr('admin.servers.title')),
        actions: [
          IconButton(
            tooltip: context.l10n.tr('action.refresh'),
            onPressed: () => ref.invalidate(adminServersProvider),
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreate,
        icon: const Icon(Icons.add_rounded),
        label: Text(context.l10n.tr('admin.servers.create')),
      ),
      body: servers.when(
        loading: () => const AppLoadingView(),
        error: (error, _) => AppErrorView(
          error: error,
          onRetry: () => ref.invalidate(adminServersProvider),
        ),
        data: (values) {
          final visible = _visibleServers(values);
          return RefreshIndicator(
            onRefresh: () => ref.refresh(adminServersProvider.future),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 104),
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 760),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          controller: _searchController,
                          textDirection: _searchController.text.trim().isEmpty
                              ? Directionality.of(context)
                              : firstStrongTextDirection(
                                  _searchController.text,
                                ),
                          textAlign: TextAlign.start,
                          textInputAction: TextInputAction.search,
                          decoration: InputDecoration(
                            labelText: context.l10n.tr('admin.servers.search'),
                            prefixIcon: const Icon(Icons.search_rounded),
                            suffixIcon: _searchController.text.isEmpty
                                ? null
                                : IconButton(
                                    tooltip: context.l10n.tr(
                                      'admin.servers.clearSearch',
                                    ),
                                    onPressed: _searchController.clear,
                                    icon: const Icon(Icons.close_rounded),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: _statusFilter?.wireValue ?? '',
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: context.l10n.tr(
                              'admin.servers.statusFilter',
                            ),
                            prefixIcon: const Icon(Icons.filter_alt_outlined),
                          ),
                          items: [
                            DropdownMenuItem<String>(
                              value: '',
                              child: Text(
                                context.l10n.tr('admin.servers.allStatuses'),
                              ),
                            ),
                            for (final status
                                in AdminServerOperationalStatus.values)
                              DropdownMenuItem<String>(
                                value: status.wireValue,
                                child: Text(
                                  adminServerStatusLabel(context, status),
                                ),
                              ),
                          ],
                          onChanged: (value) => setState(
                            () => _statusFilter = value == null || value.isEmpty
                                ? null
                                : AdminServerOperationalStatus.fromWire(value),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                context.l10n.tr('admin.servers.inventory'),
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                            ),
                            Text(
                              AppFormat.number(context, visible.length),
                              style: const TextStyle(
                                color: AppColors.ink500,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        if (visible.isEmpty)
                          SizedBox(
                            height: 330,
                            child: EmptyState(
                              icon: Icons.dns_outlined,
                              message: context.l10n.tr(
                                values.isEmpty
                                    ? 'admin.servers.empty'
                                    : 'admin.servers.noResults',
                              ),
                            ),
                          )
                        else
                          for (final server in visible) ...[
                            _AdminServerCard(
                              server: server,
                              onTap: () => context.push<void>(
                                '/admin/servers/${server.id}',
                              ),
                            ),
                            const SizedBox(height: 10),
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

class _AdminServerCard extends StatelessWidget {
  const _AdminServerCard({required this.server, required this.onTap});

  final ServerModel server;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final status = AdminServerOperationalStatus.fromWire(
      server.operationalStatus,
    );
    final tier = AdminServerPerformanceTier.fromWire(server.performanceTier);
    final headline = server.gpu.trim().toLowerCase() == 'none'
        ? server.cpu
        : server.gpu;
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
                      color: adminServerStatusColor(
                        status,
                      ).withValues(alpha: .1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      Icons.dns_rounded,
                      color: adminServerStatusColor(status),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          headline,
                          textDirection: TextDirection.ltr,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          context.l10n.tr(
                            'admin.servers.serverNumber',
                            <String, Object?>{'id': server.id},
                          ),
                          style: const TextStyle(
                            color: AppColors.ink500,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: AdminServerStatusBadge(status: status),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _CompactValue(icon: Icons.memory_rounded, value: server.cpu),
                  _CompactValue(
                    icon: Icons.sd_storage_rounded,
                    value: server.ram,
                  ),
                  _CompactValue(icon: Icons.computer_rounded, value: server.os),
                ],
              ),
              const Divider(height: 28),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      adminServerTierLabel(context, tier),
                      style: const TextStyle(
                        color: AppColors.ink600,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    AppFormat.money(
                      context,
                      server.pricePerHour,
                      context.l10n.tr('common.toman'),
                    ),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompactValue extends StatelessWidget {
  const _CompactValue({required this.icon, required this.value});

  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.muted,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.ink500),
          const SizedBox(width: 5),
          Text(
            value,
            textDirection: TextDirection.ltr,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
