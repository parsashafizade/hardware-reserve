import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/network/api_providers.dart';
import '../../../core/network/error_presenter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/app_format.dart';
import '../../../core/widgets/async_states.dart';
import '../data/reservation_models.dart';
import 'reservation_widgets.dart';

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key, required this.reservationId});

  final int reservationId;

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  late Future<ReservationCockpitModel> _cockpitFuture;
  ReservationCockpitModel? _cockpit;
  PaymentResultModel? _paymentResult;
  Object? _paymentError;
  bool _paying = false;
  bool _attemptedPayment = false;
  bool _retryLocked = false;

  @override
  void initState() {
    super.initState();
    _cockpitFuture = _loadCockpit();
  }

  Future<ReservationCockpitModel> _loadCockpit() async {
    final cockpit = await ref
        .read(reservationRepositoryProvider)
        .getCockpit(widget.reservationId);
    _cockpit = cockpit;
    _retryLocked = false;
    return cockpit;
  }

  Future<void> _reload() async {
    final future = _loadCockpit();
    setState(() {
      _cockpitFuture = future;
      _paymentError = null;
    });
    await future;
  }

  bool _paid(ReservationCockpitModel cockpit) =>
      cockpit.paymentId != null ||
      cockpit.paymentStatus == 'Completed' ||
      cockpit.status == 'Paid';

  Future<void> _pay() async {
    if (_paying || _retryLocked) return;
    final current = _cockpit;
    if (current == null || _paid(current)) return;
    setState(() {
      _paying = true;
      _paymentError = null;
    });

    try {
      // Every explicit retry first reconciles the preceding attempt with the
      // authoritative cockpit. A payment POST is never retried automatically.
      if (_attemptedPayment) {
        final reconciled = await ref
            .read(reservationRepositoryProvider)
            .getCockpit(widget.reservationId);
        if (!mounted) return;
        setState(() => _cockpit = reconciled);
        if (_paid(reconciled)) return;
      }

      _attemptedPayment = true;
      final result = await ref
          .read(reservationRepositoryProvider)
          .payReservation(widget.reservationId);
      final reconciled = await ref
          .read(reservationRepositoryProvider)
          .getCockpit(widget.reservationId);
      if (!mounted) return;
      setState(() {
        _paymentResult = result;
        _cockpit = reconciled;
        _paymentError = null;
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _retryLocked = true);
      try {
        final reconciled = await ref
            .read(reservationRepositoryProvider)
            .getCockpit(widget.reservationId);
        if (!mounted) return;
        setState(() {
          _cockpit = reconciled;
          _retryLocked = false;
          if (!_paid(reconciled)) _paymentError = error;
        });
      } on Object {
        if (!mounted) return;
        setState(() => _paymentError = error);
      }
    } finally {
      if (mounted) setState(() => _paying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.tr('payment.title'))),
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
          final cockpit = _cockpit ?? snapshot.requireData;
          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 32),
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ReservationServerCard(server: cockpit.server),
                        const SizedBox(height: 16),
                        ReservationTimeCard(
                          startTime: cockpit.startTime,
                          endTime: cockpit.endTime,
                        ),
                        const SizedBox(height: 16),
                        _PaymentReviewCard(cockpit: cockpit),
                        const SizedBox(height: 16),
                        if (_paid(cockpit))
                          _PaymentCompleteCard(
                            cockpit: cockpit,
                            result: _paymentResult,
                          )
                        else ...[
                          if (_paymentError case final error?) ...[
                            _PaymentErrorCard(
                              message: presentError(context, error),
                              reconcileRequired: _retryLocked,
                              onRefresh: _reload,
                            ),
                            const SizedBox(height: 12),
                          ],
                          FilledButton.icon(
                            onPressed: _paying || _retryLocked ? null : _pay,
                            icon: _paying
                                ? const SizedBox.square(
                                    dimension: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.lock_rounded),
                            label: Text(
                              _retryLocked
                                  ? context.l10n.tr('action.refresh')
                                  : context.l10n.tr('action.pay'),
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
        },
      ),
    );
  }
}

class _PaymentReviewCard extends StatelessWidget {
  const _PaymentReviewCard({required this.cockpit});

  final ReservationCockpitModel cockpit;

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
                Expanded(
                  child: Text(
                    context.l10n.tr('reservation.total'),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                ReservationStatusChip(status: cockpit.paymentStatus),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              AppFormat.money(
                context,
                cockpit.totalPrice,
                context.l10n.tr('common.toman'),
              ),
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(color: AppColors.brand700),
            ),
            const SizedBox(height: 12),
            Text(
              reservationText(
                context,
                fa: 'مبلغ از رزرو ذخیره‌شده روی سرور خوانده می‌شود.',
                en: 'The amount is read from the server-authoritative reservation.',
              ),
              style: const TextStyle(color: AppColors.ink500, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentCompleteCard extends StatelessWidget {
  const _PaymentCompleteCard({required this.cockpit, this.result});

  final ReservationCockpitModel cockpit;
  final PaymentResultModel? result;

  @override
  Widget build(BuildContext context) {
    final paymentId = result?.paymentId ?? cockpit.paymentId;
    final paymentDate = result?.paymentDate ?? cockpit.paymentDate;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        border: Border.all(color: AppColors.success.withValues(alpha: .28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(
            Icons.verified_rounded,
            color: AppColors.success,
            size: 42,
          ),
          const SizedBox(height: 11),
          Text(
            context.l10n.tr('payment.completed'),
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(color: AppColors.success),
          ),
          if (paymentId != null) ...[
            const SizedBox(height: 16),
            ReservationDetailLine(
              icon: Icons.receipt_long_rounded,
              label: reservationText(
                context,
                fa: 'شماره پرداخت',
                en: 'Payment ID',
              ),
              value: AppFormat.number(context, paymentId),
            ),
          ],
          if (paymentDate != null) ...[
            const Divider(height: 22),
            ReservationDetailLine(
              icon: Icons.schedule_rounded,
              label: reservationText(context, fa: 'زمان پرداخت', en: 'Paid at'),
              value: AppFormat.dateTime(context, paymentDate),
            ),
          ],
          const SizedBox(height: 18),
          FilledButton(
            onPressed: () =>
                context.go('/reservations/${cockpit.reservationId}'),
            child: Text(context.l10n.tr('action.continue')),
          ),
        ],
      ),
    );
  }
}

class _PaymentErrorCard extends StatelessWidget {
  const _PaymentErrorCard({
    required this.message,
    required this.reconcileRequired,
    required this.onRefresh,
  });

  final String message;
  final bool reconcileRequired;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: .07),
        borderRadius: BorderRadius.circular(AppTheme.controlRadius),
        border: Border.all(color: AppColors.danger.withValues(alpha: .22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.error_outline_rounded, color: AppColors.danger),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(color: AppColors.danger),
                ),
              ),
            ],
          ),
          if (reconcileRequired) ...[
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: onRefresh,
              icon: const Icon(Icons.sync_rounded),
              label: Text(context.l10n.tr('action.refresh')),
            ),
          ],
        ],
      ),
    );
  }
}
