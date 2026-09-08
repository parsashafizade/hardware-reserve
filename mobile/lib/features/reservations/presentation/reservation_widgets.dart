import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/app_format.dart';
import '../../../core/widgets/app_status_badge.dart';
import '../data/reservation_models.dart';

String reservationText(
  BuildContext context, {
  required String fa,
  required String en,
}) => context.l10n.isPersian ? fa : en;

class ReservationStatusChip extends StatelessWidget {
  const ReservationStatusChip({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final normalized = status.toLowerCase();
    final color = switch (normalized) {
      'paid' || 'completed' || 'active' => AppColors.success,
      'pending' || 'pendingpayment' || 'unpaid' => AppColors.warning,
      'cancelled' || 'failed' || 'refunded' => AppColors.danger,
      _ => AppColors.info,
    };
    final label = _statusLabel(context, status);
    return AppStatusBadge(
      label: label,
      color: color,
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      backgroundAlpha: .1,
      borderAlpha: .25,
      textStyle: TextStyle(
        color: color,
        fontSize: 11,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

String _statusLabel(BuildContext context, String status) {
  if (!context.l10n.isPersian) {
    return switch (status) {
      'PendingPayment' => 'Pending payment',
      _ => status,
    };
  }
  return switch (status) {
    'PendingPayment' => 'در انتظار پرداخت',
    'Paid' => 'پرداخت‌شده',
    'Cancelled' => 'لغوشده',
    'Unpaid' => 'پرداخت‌نشده',
    'Pending' => 'در انتظار',
    'Completed' => 'تکمیل‌شده',
    'Failed' => 'ناموفق',
    'Refunded' => 'بازپرداخت‌شده',
    'Active' => 'فعال',
    _ => status,
  };
}

class ReservationServerCard extends StatelessWidget {
  const ReservationServerCard({super.key, required this.server});

  final ReservationServerSpecsModel server;

  @override
  Widget build(BuildContext context) {
    final headline = server.gpu.trim().toLowerCase() == 'none'
        ? server.cpu
        : server.gpu;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: AppColors.brand100,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.dns_rounded,
                    color: AppColors.brand700,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    headline,
                    textDirection: TextDirection.ltr,
                    textAlign: TextAlign.start,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 15),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _HardwareChip(label: server.cpu, icon: Icons.memory_rounded),
                _HardwareChip(
                  label: server.ram,
                  icon: Icons.sd_storage_rounded,
                ),
                _HardwareChip(
                  label: server.storage,
                  icon: Icons.storage_rounded,
                ),
                _HardwareChip(label: server.os, icon: Icons.computer_rounded),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HardwareChip extends StatelessWidget {
  const _HardwareChip({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.muted,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.ink500),
          const SizedBox(width: 6),
          Text(
            label,
            textDirection: TextDirection.ltr,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class ReservationTimeCard extends StatelessWidget {
  const ReservationTimeCard({
    super.key,
    required this.startTime,
    required this.endTime,
  });

  final DateTime startTime;
  final DateTime endTime;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            ReservationDetailLine(
              icon: Icons.play_circle_outline_rounded,
              label: context.l10n.tr('reservation.start'),
              value: AppFormat.dateTime(context, startTime),
            ),
            const Divider(height: 24),
            ReservationDetailLine(
              icon: Icons.stop_circle_outlined,
              label: context.l10n.tr('reservation.end'),
              value: AppFormat.dateTime(context, endTime),
            ),
          ],
        ),
      ),
    );
  }
}

class ReservationDetailLine extends StatelessWidget {
  const ReservationDetailLine({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.valueDirection,
  });

  final IconData icon;
  final String label;
  final String value;
  final TextDirection? valueDirection;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: AppColors.brand700),
        const SizedBox(width: 10),
        Expanded(
          child: Text(label, style: const TextStyle(color: AppColors.ink500)),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textDirection: valueDirection,
            textAlign: TextAlign.end,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

class CredentialsPanel extends StatefulWidget {
  const CredentialsPanel({
    super.key,
    required this.ip,
    required this.username,
    required this.password,
  });

  final String? ip;
  final String? username;
  final String? password;

  @override
  State<CredentialsPanel> createState() => _CredentialsPanelState();
}

class _CredentialsPanelState extends State<CredentialsPanel> {
  bool _revealed = false;

  bool get _ready =>
      _nonBlank(widget.ip) &&
      _nonBlank(widget.username) &&
      _nonBlank(widget.password);

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
                const Icon(Icons.key_rounded, color: AppColors.brand700),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    context.l10n.tr('services.credentials'),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (_revealed)
                  IconButton(
                    tooltip: reservationText(
                      context,
                      fa: 'پنهان کردن',
                      en: 'Hide',
                    ),
                    onPressed: () => setState(() => _revealed = false),
                    icon: const Icon(Icons.visibility_off_rounded),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _ready
                  ? context.l10n.tr('services.sensitive')
                  : reservationText(
                      context,
                      fa: 'اطلاعات اتصال هنوز آماده نیست.',
                      en: 'Connection details are not ready yet.',
                    ),
              style: const TextStyle(color: AppColors.ink500, fontSize: 12),
            ),
            const SizedBox(height: 16),
            if (!_revealed)
              OutlinedButton.icon(
                onPressed: _ready
                    ? () => setState(() => _revealed = true)
                    : null,
                icon: const Icon(Icons.visibility_rounded),
                label: Text(
                  reservationText(
                    context,
                    fa: 'نمایش اطلاعات اتصال',
                    en: 'Reveal connection details',
                  ),
                ),
              )
            else ...[
              _CredentialRow(label: 'IP', value: widget.ip!),
              const Divider(height: 20),
              _CredentialRow(
                label: reservationText(
                  context,
                  fa: 'نام کاربری',
                  en: 'Username',
                ),
                value: widget.username!,
              ),
              const Divider(height: 20),
              _CredentialRow(
                label: reservationText(context, fa: 'رمز عبور', en: 'Password'),
                value: widget.password!,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CredentialRow extends StatelessWidget {
  const _CredentialRow({required this.label, required this.value});

  final String label;
  final String value;

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(context.l10n.tr('action.copied'))));
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 76,
          child: Text(
            label,
            style: const TextStyle(color: AppColors.ink500, fontSize: 12),
          ),
        ),
        Expanded(
          child: SelectableText(
            value,
            textDirection: TextDirection.ltr,
            textAlign: TextAlign.start,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
          ),
        ),
        IconButton(
          tooltip: context.l10n.tr('action.copy'),
          onPressed: () => _copy(context),
          icon: const Icon(Icons.copy_rounded, size: 19),
        ),
      ],
    );
  }
}

bool _nonBlank(String? value) => value != null && value.trim().isNotEmpty;
