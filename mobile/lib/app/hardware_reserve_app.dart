import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/localization/app_localizations.dart';
import '../core/localization/locale_controller.dart';
import '../core/network/api_providers.dart';
import '../core/theme/app_theme.dart';
import 'router.dart';

class HardwareReserveApp extends ConsumerStatefulWidget {
  const HardwareReserveApp({super.key});

  @override
  ConsumerState<HardwareReserveApp> createState() => _HardwareReserveAppState();
}

class _HardwareReserveAppState extends ConsumerState<HardwareReserveApp> {
  late final AppLifecycleListener _lifecycleListener;

  @override
  void initState() {
    super.initState();
    _lifecycleListener = AppLifecycleListener(
      onResume: () => unawaited(_revalidateRestoredSession()),
    );
  }

  Future<void> _revalidateRestoredSession() async {
    final authState = ref.read(authControllerProvider);
    if (!authState.isAuthenticated) return;
    try {
      await ref.read(authControllerProvider.notifier).validAccessToken();
    } on Object {
      // Definitive failures clear the session in AuthController. Transient
      // failures retain it and remain visible to the next authoritative read.
    }
  }

  @override
  void dispose() {
    _lifecycleListener.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(authControllerProvider);
    final locale = ref.watch(localeControllerProvider);
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'HardwareReserve',
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: AppTheme.light(locale),
      routerConfig: router,
    );
  }
}
