import 'package:flutter/material.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/app_format.dart';
import '../data/server_model.dart';

class ServerCard extends StatelessWidget {
  const ServerCard({super.key, required this.server, required this.onPressed});

  final ServerModel server;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final available =
        server.isActive && server.operationalStatus == 'Available';
    final primaryHardware = _hasDedicatedGpu(server.gpu)
        ? server.gpu
        : server.cpu;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(18, 18, 18, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Hero(
                    tag: 'server-${server.id}',
                    child: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [AppColors.brand600, AppColors.brand400],
                        ),
                      ),
                      child: const Icon(Icons.dns_rounded, color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 13),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          primaryHardware,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textDirection: TextDirection.ltr,
                          textAlign: TextAlign.start,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 5),
                        Text(
                          _hasDedicatedGpu(server.gpu) ? server.cpu : server.os,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textDirection: TextDirection.ltr,
                          textAlign: TextAlign.start,
                          style: const TextStyle(
                            color: AppColors.ink500,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _AvailabilityBadge(available: available),
                ],
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _SpecChip(icon: Icons.memory_rounded, label: server.ram),
                  _SpecChip(icon: Icons.storage_rounded, label: server.storage),
                  _SpecChip(icon: Icons.computer_rounded, label: server.os),
                ],
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.muted.withValues(alpha: .7),
                  borderRadius: BorderRadius.circular(AppTheme.controlRadius),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _PriceColumn(
                        label: context.l10n.tr('servers.hourly'),
                        value: AppFormat.money(
                          context,
                          server.pricePerHour,
                          context.l10n.tr('common.toman'),
                        ),
                      ),
                    ),
                    Container(width: 1, height: 34, color: AppColors.border),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsetsDirectional.only(start: 14),
                        child: _PriceColumn(
                          label: context.l10n.tr('servers.daily'),
                          value: AppFormat.money(
                            context,
                            server.pricePerDay,
                            context.l10n.tr('common.toman'),
                          ),
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.arrow_forward_rounded,
                      size: 20,
                      color: AppColors.brand600,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AvailabilityBadge extends StatelessWidget {
  const _AvailabilityBadge({required this.available});
  final bool available;

  @override
  Widget build(BuildContext context) {
    final color = available ? AppColors.success : AppColors.warning;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: .24)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            context.l10n.tr(
              available ? 'servers.available' : 'servers.unavailable',
            ),
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _SpecChip extends StatelessWidget {
  const _SpecChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.ink500),
          const SizedBox(width: 6),
          Text(
            label,
            textDirection: TextDirection.ltr,
            style: const TextStyle(
              color: AppColors.ink700,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _PriceColumn extends StatelessWidget {
  const _PriceColumn({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: AppColors.ink500, fontSize: 11),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppColors.ink950,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

bool _hasDedicatedGpu(String gpu) {
  final normalized = gpu.trim().toLowerCase();
  return normalized.isNotEmpty &&
      normalized != 'none' &&
      normalized != 'n/a' &&
      normalized != 'integrated';
}
