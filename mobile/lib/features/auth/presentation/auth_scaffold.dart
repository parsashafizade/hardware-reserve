import 'package:flutter/material.dart';

import '../../../core/localization/app_localizations.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_brand.dart';

class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final keyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;
    return Scaffold(
      appBar: AppBar(
        title: const AppBrand(),
        actions: [
          TextButton(
            onPressed: () => Navigator.maybePop(context),
            child: Text(context.l10n.tr('action.close')),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 760;
            final form = SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 470),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: AppColors.ink600,
                        ),
                      ),
                      const SizedBox(height: 28),
                      child,
                    ],
                  ),
                ),
              ),
            );
            if (!wide) {
              if (keyboardVisible) return form;
              return Column(
                children: [
                  SizedBox(
                    height: 132,
                    width: double.infinity,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.asset(
                          'assets/images/auth-datacenter.webp',
                          fit: BoxFit.cover,
                        ),
                        const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Color(0xCC081526), Color(0x661767DC)],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(child: form),
                ],
              );
            }
            return Row(
              children: [
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.asset(
                        'assets/images/auth-datacenter.webp',
                        fit: BoxFit.cover,
                      ),
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0x66081526), AppColors.inverse],
                          ),
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.all(40),
                        child: Align(
                          alignment: Alignment.bottomLeft,
                          child: AppBrand(inverse: true),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(child: form),
              ],
            );
          },
        ),
      ),
    );
  }
}

class AuthFeedback extends StatelessWidget {
  const AuthFeedback({super.key, required this.message, this.success = false});

  final String message;
  final bool success;

  @override
  Widget build(BuildContext context) {
    final background = success
        ? AppColors.success.withValues(alpha: .10)
        : Theme.of(context).colorScheme.errorContainer;
    final foreground = success
        ? AppColors.success
        : Theme.of(context).colorScheme.onErrorContainer;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(message, style: TextStyle(color: foreground)),
    );
  }
}
