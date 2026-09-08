import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/network/api_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/app_format.dart';
import '../../../core/widgets/async_states.dart';
import '../../../core/widgets/refresh_on_resume.dart';
import '../data/reservation_models.dart';
import 'reservation_widgets.dart';

class MyReservationsScreen extends ConsumerStatefulWidget {
  const MyReservationsScreen({super.key});

  @override
  ConsumerState<MyReservationsScreen> createState() =>
      _MyReservationsScreenState();
}

class _MyReservationsScreenState extends ConsumerState<MyReservationsScreen> {
  late Future<List<MyReservationModel>> _reservationsFuture;

  @override
  void initState() {
    super.initState();
    _reservationsFuture = _load();
  }

  Future<List<MyReservationModel>> _load() {
    return ref.read(reservationRepositoryProvider).getMyReservations();
  }

  Future<void> _reload() async {
    final future = _load();
    setState(() => _reservationsFuture = future);
    await future;
  }

  @override
  Widget build(BuildContext context) {
    return RefreshOnResume(
      onResume: _reload,
      child: Scaffold(
      appBar: AppBar(title: Text(context.l10n.tr('reservations.title'))),
      body: FutureBuilder<List<MyReservationModel>>(
        future: _reservationsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const AppLoadingView();
          }
          if (snapshot.hasError) {
            return AppErrorView(error: snapshot.error!, onRetry: _reload);
          }
          final reservations = snapshot.data ?? const <MyReservationModel>[];
          if (reservations.isEmpty) {
            return RefreshIndicator(
              onRefresh: _reload,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(
                    height: MediaQuery.sizeOf(context).height * .7,
                    child: EmptyState(
                      icon: Icons.event_note_rounded,
                      message: context.l10n.tr('reservations.empty'),
                      action: FilledButton.icon(
                        onPressed: () => context.go('/servers'),
                        icon: const Icon(Icons.dns_rounded),
                        label: Text(context.l10n.tr('servers.title')),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 32),
              itemCount: reservations.length,
              separatorBuilder: (_, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final reservation = reservations[index];
                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 760),
                    child: _ReservationListCard(reservation: reservation),
                  ),
                );
              },
            ),
          );
        },
      ),
      ),
    );
  }
}

class _ReservationListCard extends StatelessWidget {
  const _ReservationListCard({required this.reservation});

  final MyReservationModel reservation;

  @override
  Widget build(BuildContext context) {
    final pending = reservation.status == 'PendingPayment';
    final headline = reservation.server.gpu.trim().toLowerCase() == 'none'
        ? reservation.server.cpu
        : reservation.server.gpu;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/reservations/${reservation.reservationId}'),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: AppColors.brand100,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.event_available_rounded,
                      color: AppColors.brand700,
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
                          textAlign: TextAlign.start,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 5),
                        Text(
                          '#${AppFormat.number(context, reservation.reservationId)}',
                          style: const TextStyle(
                            color: AppColors.ink500,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  ReservationStatusChip(status: reservation.status),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: AppColors.muted.withValues(alpha: .7),
                  borderRadius: BorderRadius.circular(AppTheme.controlRadius),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.schedule_rounded,
                          size: 17,
                          color: AppColors.ink500,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            AppFormat.dateTime(context, reservation.startTime),
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const SizedBox(width: 25),
                        Expanded(
                          child: Text(
                            AppFormat.dateTime(context, reservation.endTime),
                            style: const TextStyle(
                              color: AppColors.ink500,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      AppFormat.money(
                        context,
                        reservation.totalPrice,
                        context.l10n.tr('common.toman'),
                      ),
                      style: const TextStyle(
                        color: AppColors.brand700,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (pending)
                    FilledButton.icon(
                      onPressed: () => context.push(
                        '/reservations/${reservation.reservationId}/checkout',
                      ),
                      icon: const Icon(Icons.payment_rounded, size: 18),
                      label: Text(context.l10n.tr('action.pay')),
                    )
                  else
                    TextButton.icon(
                      onPressed: () => context.push(
                        '/reservations/${reservation.reservationId}',
                      ),
                      icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                      label: Text(context.l10n.tr('action.view')),
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
