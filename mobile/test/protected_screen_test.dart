import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hardware_reserve/app/protected_screen.dart';
import 'package:hardware_reserve/core/localization/app_localizations.dart';
import 'package:hardware_reserve/core/network/api_providers.dart';
import 'package:hardware_reserve/core/storage/secure_session_store.dart';
import 'package:hardware_reserve/features/auth/application/auth_controller.dart';
import 'package:hardware_reserve/features/auth/data/auth_models.dart';
import 'package:hardware_reserve/features/auth/data/auth_repository.dart';

void main() {
  testWidgets('Admin-only guard hides its child from an ordinary user', (
    tester,
  ) async {
    final controller = await _authenticatedController(role: 'User');

    await tester.pumpWidget(
      _testApp(
        controller,
        const ProtectedScreen(
          returnPath: '/admin',
          adminOnly: true,
          child: Text('admin content'),
        ),
      ),
    );

    expect(find.text('فضای مدیریت'), findsOneWidget);
    expect(find.text('admin content'), findsNothing);
  });

  testWidgets('Admin-only guard renders its child for an Admin session', (
    tester,
  ) async {
    final controller = await _authenticatedController(role: 'Admin');

    await tester.pumpWidget(
      _testApp(
        controller,
        const ProtectedScreen(
          returnPath: '/admin',
          adminOnly: true,
          child: Text('admin content'),
        ),
      ),
    );

    expect(find.text('admin content'), findsOneWidget);
    expect(find.text('فضای مدیریت'), findsNothing);
  });
}

Widget _testApp(AuthController controller, Widget home) {
  return ProviderScope(
    overrides: [authControllerProvider.overrideWith((ref) => controller)],
    child: MaterialApp(
      locale: const Locale('fa', 'IR'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: home,
    ),
  );
}

Future<AuthController> _authenticatedController({required String role}) async {
  final controller = AuthController(
    _NoopAuthRepository(),
    _MemorySessionStore(),
  );
  final now = DateTime.now().toUtc();
  await controller.acceptSession(
    AuthResponse(
      accessToken: 'access-$role',
      accessTokenExpiresAt: now.add(const Duration(minutes: 20)),
      refreshToken: 'refresh-$role',
      refreshTokenExpiresAt: now.add(const Duration(days: 14)),
      user: AuthenticatedUser(
        id: 7,
        fullName: 'Test $role',
        email: 'test@example.com',
        role: role,
      ),
    ),
  );
  return controller;
}

class _NoopAuthRepository extends AuthRepository {
  _NoopAuthRepository() : super(Dio());
}

class _MemorySessionStore extends SecureSessionStore {
  AuthResponse? session;

  @override
  Future<AuthResponse?> read() async => session;

  @override
  Future<void> write(AuthResponse value) async => session = value;

  @override
  Future<void> clear() async => session = null;
}
