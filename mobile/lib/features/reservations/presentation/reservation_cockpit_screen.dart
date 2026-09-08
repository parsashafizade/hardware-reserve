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

class ReservationCockpitScreen extends ConsumerStatefulWidget {
  const ReservationCockpitScreen({super.key, required this.reservationId});

  final int reservationId;

  @override
  ConsumerState<ReservationCockpitScreen> createState() =>
      _ReservationCockpitScreenState();
}

class _ReservationCockpitScreenState
    extends ConsumerState<ReservationCockpitScreen> {
  late Future<ReservationCockpitModel> _cockpitFuture;

  @override
  void initState() {
    super.initState();
    _cockpitFuture = _load();
  }

  Future<ReservationCockpitModel> _load() {
    return ref
        .read(reservationRepositoryProvider)
        .getCockpit(widget.reservationId);
  }

  Future<void> _reload() async {
    final future = _load();
    setState(() => _cockpitFuture = future);
    await future;
  }

  @override
  Widget build(BuildContext context) {
    return RefreshOnResume(
      onResume: _reload,
      child: Scaffold(
      appBar: AppBar(title: Text(context.l10n.tr('reservations.title'))),
      body: FutureBuilder<ReservationCockpitModel>(
        future: _cockpitFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const AppLoadingView();
          }
          if (snapshot.hasError) {
            return AppErrorView(error: snapshot.error!, onRetry: _reload);
          }
          final cockpit = snapshot.requireData;
          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 32),
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 760),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _CockpitHero(cockpit: cockpit),
                        const SizedBox(height: 16),
                        ReservationServerCard(server: cockpit.server),
                        const SizedBox(height: 16),
                        ReservationTimeCard(
                          startTime: cockpit.startTime,
                          endTime: cockpit.endTime,
                        ),
                        const SizedBox(height: 16),
                        _PaymentCard(cockpit: cockpit),
                        if (cockpit.status == 'Paid') ...[
                          const SizedBox(height: 16),
                          CredentialsPanel(
                            ip: cockpit.assignedIp,
                            username: cockpit.assignedUsername,
                            password: cockpit.assignedPassword,
                          ),
                        ],
                        const SizedBox(height: 16),
                        if (cockpit.status == 'PendingPayment')
                          FilledButton.icon(
                            onPressed: () => context.push(
                              '/reservations/${cockpit.reservationId}/checkout',
                            ),
                            icon: const Icon(Icons.payment_rounded),
                            label: Text(context.l10n.tr('action.pay')),
                          )
                        else
                          OutlinedButton.icon(
                            onPressed: () => context.go('/services'),
                            icon: const Icon(Icons.cloud_done_rounded),
                            label: Text(context.l10n.tr('services.title')),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
      ),
    );
  }
}

class _CockpitHero extends StatelessWidget {
  const _CockpitHero({required this.cockpit});

  final ReservationCockpitModel cockpit;

  @override
  Widget build(BuildContext context) {
    final lifecycle = _lifecycle(context, cockpit);
    final color = switch (lifecycle.kind) {
      _LifecycleKind.active => AppColors.success,
      _LifecycleKind.upcoming => AppColors.info,
      _LifecycleKind.completed => AppColors.ink500,
      _LifecycleKind.cancelled => AppColors.danger,
      _LifecycleKind.awaitingPayment => AppColors.warning,
    };
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.panelRadius),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.inverseRaised, AppColors.inverse],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .18),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(lifecycle.icon, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lifecycle.label,
                      style: Theme.of(
                        context,
                      ).textTheme.titleLarge?.copyWith(color: Colors.white),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '#${AppFormat.number(context, cockpit.reservationId)}',
                      style: const TextStyle(color: Color(0xFFB8C6D6)),
                    ),
                  ],
                ),
              ),
              ReservationStatusChip(status: cockpit.status),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            reservationText(
              context,
              fa: 'زمان معتبر سرور: ${AppFormat.dateTime(context, cockpit.serverTimeUtc)}',
              en: 'Server time: ${AppFormat.dateTime(context, cockpit.serverTimeUtc)}',
            ),
            style: const TextStyle(color: Color(0xFFB8C6D6), fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _PaymentCard extends StatelessWidget {
  const _PaymentCard({required this.cockpit});

  final ReservationCockpitModel cockpit;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            ReservationDetailLine(
              icon: Icons.payments_outlined,
              label: context.l10n.tr('reservation.total'),
              value: AppFormat.money(
                context,
                cockpit.totalPrice,
                context.l10n.tr('common.toman'),
              ),
            ),
            const Divider(height: 24),
            Row(
              children: [
                const Icon(
                  Icons.verified_user_outlined,
                  size: 20,
                  color: AppColors.brand700,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    reservationText(
                      context,
                      fa: 'وضعیت پرداخت',
                      en: 'Payment status',
                    ),
                    style: const TextStyle(color: AppColors.ink500),
                  ),
                ),
                ReservationStatusChip(status: cockpit.paymentStatus),
              ],
            ),
            if (cockpit.paymentDate case final date?) ...[
              const Divider(height: 24),
              ReservationDetailLine(
                icon: Icons.schedule_rounded,
                label: reservationText(
                  context,
                  fa: 'زمان پرداخت',
                  en: 'Paid at',
                ),
                value: AppFormat.dateTime(context, date),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

enum _LifecycleKind { awaitingPayment, upcoming, active, completed, cancelled }

class _Lifecycle {
  const _Lifecycle(this.kind, this.label, this.icon);

  final _LifecycleKind kind;
  final String label;
  final IconData icon;
}

_Lifecycle _lifecycle(BuildContext context, ReservationCockpitModel cockpit) {
  if (cockpit.status == 'Cancelled') {
    return _Lifecycle(
      _LifecycleKind.cancelled,
      reservationText(context, fa: 'رزرو لغو شده', en: 'Reservation cancelled'),
      Icons.cancel_rounded,
    );
  }
  if (cockpit.status == 'PendingPayment') {
    return _Lifecycle(
      _LifecycleKind.awaitingPayment,
      context.l10n.tr('payment.pending'),
      Icons.hourglass_top_rounded,
    );
  }
  if (cockpit.serverTimeUtc.isBefore(cockpit.startTime)) {
    return _Lifecycle(
      _LifecycleKind.upcoming,
      reservationText(context, fa: 'سرویس آینده', en: 'Upcoming service'),
      Icons.upcoming_rounded,
    );
  }
  if (cockpit.serverTimeUtc.isBefore(cockpit.endTime)) {
    return _Lifecycle(
      _LifecycleKind.active,
      reservationText(context, fa: 'سرویس فعال', en: 'Service active'),
      Icons.cloud_done_rounded,
    );
  }
  return _Lifecycle(
    _LifecycleKind.completed,
    reservationText(context, fa: 'سرویس پایان یافته', en: 'Service completed'),
    Icons.task_alt_rounded,
  );
}
