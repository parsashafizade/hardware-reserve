import 'package:flutter/material.dart';

import '../localization/app_localizations.dart';
import '../network/api_failure.dart';
import '../theme/app_theme.dart';

class AppLoadingView extends StatelessWidget {
  const AppLoadingView({super.key, this.compact = false});
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(compact ? 20 : 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox.square(
              dimension: 28,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
            const SizedBox(height: 14),
            Text(
              context.l10n.tr('common.loading'),
              style: const TextStyle(color: AppColors.ink500),
            ),
          ],
        ),
      ),
    );
  }
}

class AppErrorView extends StatelessWidget {
  const AppErrorView({
    super.key,
    required this.error,
    required this.onRetry,
    this.compact = false,
  });

  final Object error;
  final VoidCallback onRetry;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final failure = ApiFailure.from(error);
    final key = switch (failure.kind) {
      ApiFailureKind.offline => 'error.offline',
      ApiFailureKind.timeout => 'error.timeout',
      ApiFailureKind.unauthorized => 'error.unauthorized',
      ApiFailureKind.forbidden => 'error.forbidden',
      ApiFailureKind.server => 'error.server',
      ApiFailureKind.validation => 'error.validation',
      ApiFailureKind.unknown => 'error.generic',
    };
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(compact ? 8 : 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_rounded,
              color: AppColors.ink500,
              size: compact ? 28 : 34,
            ),
            SizedBox(height: compact ? 8 : 12),
            Text(context.l10n.tr(key), textAlign: TextAlign.center),
            SizedBox(height: compact ? 10 : 16),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(context.l10n.tr('action.retry')),
            ),
          ],
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.message,
    this.action,
  });
  final IconData icon;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: const BoxDecoration(
                color: AppColors.muted,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppColors.ink500),
            ),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.ink600),
            ),
            if (action != null) ...[const SizedBox(height: 18), action!],
          ],
        ),
      ),
    );
  }
}
