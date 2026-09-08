import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/network/error_presenter.dart';
import '../../../../core/widgets/async_states.dart';
import '../../../../core/widgets/first_strong_text.dart';
import '../../../../core/widgets/refresh_on_resume.dart';
import '../application/admin_operations_providers.dart';
import '../application/admin_reservations_controller.dart';
import '../data/admin_operations_models.dart';
import 'admin_operations_widgets.dart';

typedef AdminReservationOpener = FutureOr<void> Function(int reservationId);

class AdminReservationsScreen extends ConsumerStatefulWidget {
  const AdminReservationsScreen({super.key, this.onOpenReservation});

  final AdminReservationOpener? onOpenReservation;

  @override
  ConsumerState<AdminReservationsScreen> createState() =>
      _AdminReservationsScreenState();
}

class _AdminReservationsScreenState
    extends ConsumerState<AdminReservationsScreen> {
  late final TextEditingController _queryController;
  AdminReservationFilter _draftStatus = AdminReservationFilter.all;
  AdminAssignmentFilter _draftAssignmentStatus = AdminAssignmentFilter.all;

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

  Future<void> _applyFilters() {
    return ref
        .read(adminReservationsControllerProvider.notifier)
        .applyFilters(
          query: _queryController.text,
          status: _draftStatus,
          assignmentStatus: _draftAssignmentStatus,
        );
  }

  Future<void> _clearFilters() async {
    _queryController.clear();
    setState(() {
      _draftStatus = AdminReservationFilter.all;
      _draftAssignmentStatus = AdminAssignmentFilter.all;
    });
    await ref.read(adminReservationsControllerProvider.notifier).clearFilters();
  }

  Future<void> _openReservation(int reservationId) async {
    final callback = widget.onOpenReservation;
    if (callback == null) return;
    await callback(reservationId);
    if (mounted) {
      await ref.read(adminReservationsControllerProvider.notifier).refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(adminReservationsControllerProvider);
    final controller = ref.read(adminReservationsControllerProvider.notifier);

    return RefreshOnResume(
      onResume: controller.refresh,
      child: Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.tr('admin.reservations.title')),
        actions: [
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
          _ReservationFilters(
            queryController: _queryController,
            status: _draftStatus,
            assignmentStatus: _draftAssignmentStatus,
            busy: state.isLoading || state.isRefreshing,
            onStatusChanged: (value) => setState(() => _draftStatus = value),
            onAssignmentStatusChanged: (value) =>
                setState(() => _draftAssignmentStatus = value),
            onApply: () => unawaited(_applyFilters()),
            onClear: () => unawaited(_clearFilters()),
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
      ),
    );
  }

  Widget _buildResults(
    BuildContext context,
    AdminReservationsState state,
    AdminReservationsController controller,
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
                icon: Icons.receipt_long_rounded,
                message: context.l10n.tr('admin.reservations.empty'),
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
        separatorBuilder: (_, _) => const SizedBox(height: 11),
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
          final AdminOrderModel order = state.items[index];
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: AdminOrderCard(
                order: order,
                onTap: widget.onOpenReservation == null
                    ? null
                    : () => unawaited(_openReservation(order.reservationId)),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ReservationFilters extends StatelessWidget {
  const _ReservationFilters({
    required this.queryController,
    required this.status,
    required this.assignmentStatus,
    required this.busy,
    required this.onStatusChanged,
    required this.onAssignmentStatusChanged,
    required this.onApply,
    required this.onClear,
  });

  final TextEditingController queryController;
  final AdminReservationFilter status;
  final AdminAssignmentFilter assignmentStatus;
  final bool busy;
  final ValueChanged<AdminReservationFilter> onStatusChanged;
  final ValueChanged<AdminAssignmentFilter> onAssignmentStatusChanged;
  final VoidCallback onApply;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 6, 16, 12),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    ValueListenableBuilder<TextEditingValue>(
                      valueListenable: queryController,
                      builder: (context, value, _) => TextField(
                        controller: queryController,
                        textDirection: value.text.trim().isEmpty
                            ? Directionality.of(context)
                            : firstStrongTextDirection(value.text),
                        textAlign: TextAlign.start,
                        textInputAction: TextInputAction.search,
                        onSubmitted: (_) => onApply(),
                        decoration: InputDecoration(
                          labelText: context.l10n.tr(
                            'admin.reservations.search',
                          ),
                          hintText: context.l10n.tr(
                            'admin.reservations.searchHint',
                          ),
                          prefixIcon: const Icon(Icons.search_rounded),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<AdminReservationFilter>(
                      key: ValueKey('reservation-status-${status.name}'),
                      initialValue: status,
                      decoration: InputDecoration(
                        labelText: context.l10n.tr(
                          'admin.reservations.statusFilter',
                        ),
                      ),
                      items: [
                        for (final filter in AdminReservationFilter.values)
                          DropdownMenuItem(
                            value: filter,
                            child: Text(
                              context.l10n.tr(
                                'admin.reservations.filter.${filter.name}',
                              ),
                            ),
                          ),
                      ],
                      onChanged: busy
                          ? null
                          : (value) {
                              if (value != null) onStatusChanged(value);
                            },
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<AdminAssignmentFilter>(
                      key: ValueKey(
                        'assignment-status-${assignmentStatus.name}',
                      ),
                      initialValue: assignmentStatus,
                      decoration: InputDecoration(
                        labelText: context.l10n.tr(
                          'admin.reservations.assignmentFilter',
                        ),
                      ),
                      items: [
                        for (final filter in AdminAssignmentFilter.values)
                          DropdownMenuItem(
                            value: filter,
                            child: Text(
                              context.l10n.tr(
                                'admin.reservations.assignment.${filter.name}',
                              ),
                            ),
                          ),
                      ],
                      onChanged: busy
                          ? null
                          : (value) {
                              if (value != null) {
                                onAssignmentStatusChanged(value);
                              }
                            },
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: busy ? null : onApply,
                            icon: const Icon(Icons.filter_alt_rounded),
                            label: Text(
                              context.l10n.tr(
                                'admin.reservations.applyFilters',
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 9),
                        IconButton.outlined(
                          tooltip: context.l10n.tr(
                            'admin.reservations.clearFilters',
                          ),
                          onPressed: busy ? null : onClear,
                          icon: const Icon(Icons.filter_alt_off_rounded),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
