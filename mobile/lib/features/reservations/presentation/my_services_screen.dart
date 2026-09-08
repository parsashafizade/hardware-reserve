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

class MyServicesScreen extends ConsumerStatefulWidget {
  const MyServicesScreen({super.key});

  @override
  ConsumerState<MyServicesScreen> createState() => _MyServicesScreenState();
}

class _MyServicesScreenState extends ConsumerState<MyServicesScreen> {
  late Future<List<MyServiceModel>> _servicesFuture;

  @override
  void initState() {
    super.initState();
    _servicesFuture = _load();
  }

  Future<List<MyServiceModel>> _load() {
    return ref.read(reservationRepositoryProvider).getMyServices();
  }

  Future<void> _reload() async {
    final future = _load();
    setState(() => _servicesFuture = future);
    await future;
  }

  @override
  Widget build(BuildContext context) {
    return RefreshOnResume(
      onResume: _reload,
      child: Scaffold(
      appBar: AppBar(title: Text(context.l10n.tr('services.title'))),
      body: FutureBuilder<List<MyServiceModel>>(
        future: _servicesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const AppLoadingView();
          }
          if (snapshot.hasError) {
            return AppErrorView(error: snapshot.error!, onRetry: _reload);
          }
          final services = snapshot.data ?? const <MyServiceModel>[];
          if (services.isEmpty) {
            return RefreshIndicator(
              onRefresh: _reload,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(
                    height: MediaQuery.sizeOf(context).height * .7,
                    child: EmptyState(
                      icon: Icons.cloud_off_outlined,
                      message: context.l10n.tr('services.empty'),
                      action: OutlinedButton.icon(
                        onPressed: () => context.go('/reservations'),
                        icon: const Icon(Icons.event_note_rounded),
                        label: Text(context.l10n.tr('reservations.title')),
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
              itemCount: services.length,
              separatorBuilder: (_, index) => const SizedBox(height: 14),
              itemBuilder: (context, index) {
                final service = services[index];
                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 760),
                    child: _ServiceCard(service: service),
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

class _ServiceCard extends StatelessWidget {
  const _ServiceCard({required this.service});

  final MyServiceModel service;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now().toUtc();
    final active =
        !now.isBefore(service.startTime) && now.isBefore(service.endTime);
    final upcoming = now.isBefore(service.startTime);
    final stateColor = active
        ? AppColors.success
        : upcoming
        ? AppColors.info
        : AppColors.ink500;
    final stateLabel = active
        ? reservationText(context, fa: 'فعال', en: 'Active')
        : upcoming
        ? reservationText(context, fa: 'آینده', en: 'Upcoming')
        : reservationText(context, fa: 'پایان‌یافته', en: 'Completed');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: stateColor.withValues(alpha: .1),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Icon(Icons.cloud_done_rounded, color: stateColor),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            service.server.gpu.trim().toLowerCase() == 'none'
                                ? service.server.cpu
                                : service.server.gpu,
                            textDirection: TextDirection.ltr,
                            textAlign: TextAlign.start,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 5),
                          Text(
                            '#${AppFormat.number(context, service.reservationId)}',
                            style: const TextStyle(
                              color: AppColors.ink500,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: stateColor.withValues(alpha: .1),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        stateLabel,
                        style: TextStyle(
                          color: stateColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _ServiceSpec(label: service.server.ram),
                    _ServiceSpec(label: service.server.storage),
                    _ServiceSpec(label: service.server.os),
                  ],
                ),
                const Divider(height: 28),
                ReservationDetailLine(
                  icon: Icons.play_circle_outline_rounded,
                  label: context.l10n.tr('reservation.start'),
                  value: AppFormat.dateTime(context, service.startTime),
                ),
                const Divider(height: 22),
                ReservationDetailLine(
                  icon: Icons.stop_circle_outlined,
                  label: context.l10n.tr('reservation.end'),
                  value: AppFormat.dateTime(context, service.endTime),
                ),
                const Divider(height: 22),
                ReservationDetailLine(
                  icon: Icons.payments_outlined,
                  label: context.l10n.tr('reservation.total'),
                  value: AppFormat.money(
                    context,
                    service.totalPrice,
                    context.l10n.tr('common.toman'),
                  ),
                ),
                const SizedBox(height: 14),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: TextButton.icon(
                    onPressed: () =>
                        context.push('/reservations/${service.reservationId}'),
                    icon: const Icon(Icons.open_in_new_rounded, size: 18),
                    label: Text(context.l10n.tr('action.view')),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        CredentialsPanel(
          ip: service.assignedIp,
          username: service.assignedUsername,
          password: service.assignedPassword,
        ),
      ],
    );
  }
}

class _ServiceSpec extends StatelessWidget {
  const _ServiceSpec({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.muted,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Text(
        label,
        textDirection: TextDirection.ltr,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}
