import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/api_providers.dart';
import '../../../core/network/error_presenter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/app_format.dart';
import '../../../core/widgets/async_states.dart';
import '../../../core/widgets/refresh_on_resume.dart';
import '../../auth/application/auth_controller.dart';
import '../../catalog/data/server_model.dart';
import '../data/reservation_models.dart';
import 'reservation_widgets.dart';

class ReservationScreen extends ConsumerStatefulWidget {
  const ReservationScreen({super.key, required this.serverId});

  final int serverId;

  @override
  ConsumerState<ReservationScreen> createState() => _ReservationScreenState();
}

class _ReservationScreenState extends ConsumerState<ReservationScreen> {
  late DateTime _startLocal;
  late DateTime _endLocal;
  late Future<_ReservationSetup> _setupFuture;
  List<ReservationBusySlotModel> _busySlots = const [];
  ReservationQuoteModel? _quote;
  Object? _actionError;
  bool _quoting = false;
  bool _creating = false;
  bool _createRetryLocked = false;

  @override
  void initState() {
    super.initState();
    _startLocal = _nextWholeHour(DateTime.now());
    _endLocal = _startLocal.add(const Duration(hours: 4));
    _setupFuture = _loadSetup();
  }

  Future<_ReservationSetup> _loadSetup() async {
    final nowUtc = DateTime.now().toUtc();
    final serverFuture = ref
        .read(serverRepositoryProvider)
        .getServerById(widget.serverId);
    final slotsFuture = ref
        .read(reservationRepositoryProvider)
        .getBusySlots(
          widget.serverId,
          fromUtc: nowUtc,
          toUtc: nowUtc.add(const Duration(days: 30)),
        );
    final server = await serverFuture;
    final slots = await slotsFuture;
    _busySlots = slots;
    return _ReservationSetup(server: server);
  }

  Future<void> _reload() async {
    final future = _loadSetup();
    setState(() {
      _setupFuture = future;
      _quote = null;
      _actionError = null;
      _createRetryLocked = false;
    });
    await future;
  }

  void _selectionChanged({required DateTime start, required DateTime end}) {
    setState(() {
      _startLocal = start;
      _endLocal = end;
      _quote = null;
      _actionError = null;
      _createRetryLocked = false;
    });
  }

  Future<void> _pickDateTime({required bool start}) async {
    final current = start ? _startLocal : _endLocal;
    final today = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: current.isBefore(today) ? today : current,
      firstDate: DateTime(today.year, today.month, today.day),
      lastDate: today.add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(current),
    );
    if (time == null || !mounted) return;
    final picked = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    if (start) {
      final duration = _endLocal.difference(_startLocal);
      final safeDuration = duration > Duration.zero
          ? duration
          : const Duration(hours: 1);
      _selectionChanged(start: picked, end: picked.add(safeDuration));
    } else {
      _selectionChanged(start: _startLocal, end: picked);
    }
  }

  String? _validateSelection() {
    final now = DateTime.now();
    if (!_startLocal.isAfter(now)) {
      return reservationText(
        context,
        fa: 'زمان شروع باید در آینده باشد.',
        en: 'Start time must be in the future.',
      );
    }
    if (!_endLocal.isAfter(_startLocal)) {
      return reservationText(
        context,
        fa: 'زمان پایان باید بعد از شروع باشد.',
        en: 'End time must be after start time.',
      );
    }
    final startUtc = _startLocal.toUtc();
    final endUtc = _endLocal.toUtc();
    if (_busySlots.any(
      (slot) =>
          startUtc.isBefore(slot.endTime) && endUtc.isAfter(slot.startTime),
    )) {
      return context.l10n.tr('reservation.notAvailable');
    }
    return null;
  }

  CreateReservationRequestModel _request({double? quotedTotalPrice}) {
    return CreateReservationRequestModel(
      serverId: widget.serverId,
      startTime: _startLocal.toUtc(),
      endTime: _endLocal.toUtc(),
      quotedTotalPrice: quotedTotalPrice,
    );
  }

  Future<void> _fetchQuote() async {
    final validation = _validateSelection();
    if (validation != null) {
      setState(() {
        _quote = null;
        _actionError = _LocalMessage(validation);
      });
      return;
    }
    setState(() {
      _quoting = true;
      _quote = null;
      _actionError = null;
    });
    try {
      final quote = await ref
          .read(reservationRepositoryProvider)
          .quoteReservation(_request());
      if (!mounted) return;
      setState(() => _quote = quote);
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _actionError = error);
    } finally {
      if (mounted) setState(() => _quoting = false);
    }
  }

  Future<void> _create() async {
    final quote = _quote;
    if (_creating ||
        _createRetryLocked ||
        quote == null ||
        !quote.isAvailable) {
      return;
    }
    if (_validateSelection() != null ||
        quote.startTime != _startLocal.toUtc() ||
        quote.endTime != _endLocal.toUtc()) {
      setState(() {
        _quote = null;
        _actionError = _LocalMessage(
          reservationText(
            context,
            fa: 'بازه زمانی تغییر کرده است؛ قیمت را دوباره محاسبه کنید.',
            en: 'The time window changed. Calculate the quote again.',
          ),
        );
      });
      return;
    }

    setState(() {
      _creating = true;
      _actionError = null;
    });
    try {
      final result = await ref
          .read(reservationRepositoryProvider)
          .createReservation(_request(quotedTotalPrice: quote.totalPrice));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.tr('reservation.created'))),
      );
      context.go('/reservations/${result.reservationId}/checkout');
    } on Object catch (error) {
      if (!mounted) return;
      final failure = ApiFailure.from(error);
      if (failure.code == 'RESERVATION_TIME_CONFLICT' ||
          failure.statusCode == 409) {
        await _refreshBusySlots();
        if (!mounted) return;
        setState(() {
          _quote = null;
          _actionError = _LocalMessage(context.l10n.tr('reservation.conflict'));
        });
      } else if (failure.kind == ApiFailureKind.offline ||
          failure.kind == ApiFailureKind.timeout ||
          failure.kind == ApiFailureKind.unknown) {
        try {
          final reconciled = await _findMatchingReservation();
          if (!mounted) return;
          if (reconciled != null) {
            _goToCheckout(reconciled.reservationId);
            return;
          }
        } on Object {
          // The reconciliation read can fail for the same connectivity reason.
        }
        if (!mounted) return;
        setState(() {
          _createRetryLocked = true;
          _actionError = error;
        });
      } else {
        setState(() => _actionError = error);
      }
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  Future<MyReservationModel?> _findMatchingReservation() async {
    final reservations = await ref
        .read(reservationRepositoryProvider)
        .getMyReservations();
    final startUtc = _startLocal.toUtc();
    final endUtc = _endLocal.toUtc();
    for (final reservation in reservations) {
      if (reservation.server.serverId == widget.serverId &&
          reservation.status != 'Cancelled' &&
          reservation.startTime == startUtc &&
          reservation.endTime == endUtc) {
        return reservation;
      }
    }
    return null;
  }

  Future<void> _reconcileBeforeCreateRetry() async {
    if (_creating) return;
    setState(() {
      _creating = true;
      _actionError = null;
    });
    try {
      final reservation = await _findMatchingReservation();
      if (!mounted) return;
      if (reservation != null) {
        _goToCheckout(reservation.reservationId);
        return;
      }
      await _refreshBusySlots();
      if (!mounted) return;
      setState(() {
        _createRetryLocked = false;
        _quote = null;
        _actionError = _LocalMessage(
          reservationText(
            context,
            fa: 'وضعیت سرور به‌روز شد. پیش از تلاش دوباره، قیمت را محاسبه کنید.',
            en: 'Server state refreshed. Calculate a new quote before trying again.',
          ),
        );
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _actionError = error);
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  void _goToCheckout(int reservationId) {
    context.go('/reservations/$reservationId/checkout');
  }

  Future<void> _refreshBusySlots() async {
    final nowUtc = DateTime.now().toUtc();
    final slots = await ref
        .read(reservationRepositoryProvider)
        .getBusySlots(
          widget.serverId,
          fromUtc: nowUtc,
          toUtc: nowUtc.add(const Duration(days: 30)),
        );
    _busySlots = slots;
  }

  String _actionErrorText(Object error) {
    if (error is _LocalMessage) return error.value;
    return presentError(context, error);
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    if (auth.phase == AuthPhase.restoring) {
      return Scaffold(
        appBar: AppBar(title: Text(context.l10n.tr('reservation.title'))),
        body: const AppLoadingView(),
      );
    }
    if (!auth.isAuthenticated) {
      return Scaffold(
        appBar: AppBar(title: Text(context.l10n.tr('reservation.title'))),
        body: EmptyState(
          icon: Icons.lock_outline_rounded,
          message: context.l10n.tr('error.unauthorized'),
          action: FilledButton.icon(
            onPressed: () {
              final returnTo = '/servers/${widget.serverId}/reserve';
              context.go('/login?returnTo=${Uri.encodeComponent(returnTo)}');
            },
            icon: const Icon(Icons.login_rounded),
            label: Text(context.l10n.tr('action.login')),
          ),
        ),
      );
    }
    return RefreshOnResume(
      onResume: _reload,
      child: Scaffold(
      appBar: AppBar(title: Text(context.l10n.tr('reservation.title'))),
      body: FutureBuilder<_ReservationSetup>(
        future: _setupFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const AppLoadingView();
          }
          if (snapshot.hasError) {
            return AppErrorView(error: snapshot.error!, onRetry: _reload);
          }
          final setup = snapshot.requireData;
          if (!setup.server.isActive ||
              setup.server.operationalStatus != 'Available') {
            return EmptyState(
              icon: Icons.event_busy_rounded,
              message: context.l10n.tr('servers.unavailable'),
              action: OutlinedButton(
                onPressed: () => context.go('/servers'),
                child: Text(context.l10n.tr('servers.title')),
              ),
            );
          }
          return _buildForm(setup);
        },
      ),
      ),
    );
  }

  Widget _buildForm(_ReservationSetup setup) {
    final validation = _validateSelection();
    final duration = _endLocal.difference(_startLocal);
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
                  _SelectedServerSummary(server: setup.server),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            reservationText(
                              context,
                              fa: 'بازه زمانی',
                              en: 'Booking window',
                            ),
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 16),
                          _DateTimeButton(
                            label: context.l10n.tr('reservation.start'),
                            value: _startLocal,
                            icon: Icons.play_circle_outline_rounded,
                            onPressed: _creating
                                ? null
                                : () => _pickDateTime(start: true),
                          ),
                          const SizedBox(height: 10),
                          _DateTimeButton(
                            label: context.l10n.tr('reservation.end'),
                            value: _endLocal,
                            icon: Icons.stop_circle_outlined,
                            onPressed: _creating
                                ? null
                                : () => _pickDateTime(start: false),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              const Icon(
                                Icons.timelapse_rounded,
                                size: 18,
                                color: AppColors.ink500,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                reservationText(
                                  context,
                                  fa: 'مدت: ${AppFormat.number(context, duration.inMinutes / 60, decimalDigits: duration.inMinutes % 60 == 0 ? 0 : 1)} ساعت',
                                  en: 'Duration: ${AppFormat.number(context, duration.inMinutes / 60, decimalDigits: duration.inMinutes % 60 == 0 ? 0 : 1)} hours',
                                ),
                                style: const TextStyle(color: AppColors.ink500),
                              ),
                            ],
                          ),
                          if (validation != null) ...[
                            const SizedBox(height: 12),
                            _InlineNotice(
                              message: validation,
                              color: AppColors.warning,
                              icon: Icons.info_outline_rounded,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _BusySlotsCard(slots: _busySlots),
                  const SizedBox(height: 16),
                  if (_actionError case final error?) ...[
                    _InlineNotice(
                      message: _actionErrorText(error),
                      color: AppColors.danger,
                      icon: Icons.error_outline_rounded,
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (_quote case final ReservationQuoteModel quote) ...[
                    _QuoteCard(quote: quote),
                    const SizedBox(height: 12),
                  ],
                  FilledButton.icon(
                    onPressed: _quoting || _creating
                        ? null
                        : _createRetryLocked
                        ? _reconcileBeforeCreateRetry
                        : _quote == null
                        ? _fetchQuote
                        : (_quote!.isAvailable ? _create : _fetchQuote),
                    icon: _quoting || _creating
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(
                            _quote == null
                                ? Icons.receipt_long_rounded
                                : _createRetryLocked
                                ? Icons.sync_rounded
                                : _quote!.isAvailable
                                ? Icons.check_circle_rounded
                                : Icons.refresh_rounded,
                          ),
                    label: Text(
                      _creating
                          ? context.l10n.tr('common.loading')
                          : _createRetryLocked
                          ? context.l10n.tr('action.refresh')
                          : _quote == null
                          ? context.l10n.tr('reservation.quote')
                          : _quote!.isAvailable
                          ? context.l10n.tr('action.reserve')
                          : context.l10n.tr('action.retry'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReservationSetup {
  const _ReservationSetup({required this.server});

  final ServerModel server;
}

class _SelectedServerSummary extends StatelessWidget {
  const _SelectedServerSummary({required this.server});

  final ServerModel server;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        gradient: const LinearGradient(
          colors: [AppColors.inverseRaised, AppColors.inverse],
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.dns_rounded, color: AppColors.brand300, size: 32),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  server.gpu.trim().toLowerCase() == 'none'
                      ? server.cpu
                      : server.gpu,
                  textDirection: TextDirection.ltr,
                  textAlign: TextAlign.start,
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(color: Colors.white),
                ),
                const SizedBox(height: 4),
                Text(
                  '${server.ram} · ${server.storage} · ${server.os}',
                  textDirection: TextDirection.ltr,
                  style: const TextStyle(color: Color(0xFFB8C6D6)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DateTimeButton extends StatelessWidget {
  const _DateTimeButton({
    required this.label,
    required this.value,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final DateTime value;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsetsDirectional.fromSTEB(14, 12, 14, 12),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.brand700),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(color: AppColors.ink500, fontSize: 11),
                ),
                const SizedBox(height: 2),
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
          const Icon(Icons.edit_calendar_rounded, size: 19),
        ],
      ),
    );
  }
}

class _BusySlotsCard extends StatelessWidget {
  const _BusySlotsCard({required this.slots});

  final List<ReservationBusySlotModel> slots;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.event_busy_rounded, color: AppColors.ink500),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    reservationText(
                      context,
                      fa: 'زمان‌های پرشده آینده',
                      en: 'Upcoming busy windows',
                    ),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Text(
                  AppFormat.number(context, slots.length),
                  style: const TextStyle(
                    color: AppColors.ink500,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            if (slots.isNotEmpty) ...[
              const SizedBox(height: 14),
              for (final slot in slots.take(4)) ...[
                Text(
                  '${AppFormat.dateTime(context, slot.startTime)}  —  ${AppFormat.dateTime(context, slot.endTime)}',
                  style: const TextStyle(color: AppColors.ink600, fontSize: 12),
                ),
                if (slot != slots.take(4).last) const Divider(height: 18),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _QuoteCard extends StatelessWidget {
  const _QuoteCard({required this.quote});

  final ReservationQuoteModel quote;

  @override
  Widget build(BuildContext context) {
    final color = quote.isAvailable ? AppColors.success : AppColors.warning;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        border: Border.all(color: color.withValues(alpha: .3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                quote.isAvailable
                    ? Icons.check_circle_rounded
                    : Icons.cancel_rounded,
                color: color,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  context.l10n.tr(
                    quote.isAvailable
                        ? 'reservation.available'
                        : 'reservation.notAvailable',
                  ),
                  style: TextStyle(color: color, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          if (quote.isAvailable) ...[
            const SizedBox(height: 16),
            Text(
              context.l10n.tr('reservation.total'),
              style: const TextStyle(color: AppColors.ink500),
            ),
            const SizedBox(height: 4),
            Text(
              AppFormat.money(
                context,
                quote.totalPrice,
                context.l10n.tr('common.toman'),
              ),
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ],
        ],
      ),
    );
  }
}

class _InlineNotice extends StatelessWidget {
  const _InlineNotice({
    required this.message,
    required this.color,
    required this.icon,
  });

  final String message;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(AppTheme.controlRadius),
        border: Border.all(color: color.withValues(alpha: .22)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 9),
          Expanded(
            child: Text(message, style: TextStyle(color: color)),
          ),
        ],
      ),
    );
  }
}

class _LocalMessage implements Exception {
  const _LocalMessage(this.value);

  final String value;
}

DateTime _nextWholeHour(DateTime now) {
  final hour = DateTime(now.year, now.month, now.day, now.hour);
  return hour.isAfter(now) ? hour : hour.add(const Duration(hours: 1));
}
