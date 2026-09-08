import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hardware_reserve/core/localization/app_localizations.dart';
import 'package:hardware_reserve/core/localization/locale_controller.dart';
import 'package:hardware_reserve/core/network/api_providers.dart';
import 'package:hardware_reserve/core/storage/secure_session_store.dart';
import 'package:hardware_reserve/features/account/data/profile_model.dart';
import 'package:hardware_reserve/features/account/data/profile_repository.dart';
import 'package:hardware_reserve/features/account/presentation/profile_screen.dart';
import 'package:hardware_reserve/features/auth/data/auth_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets(
    'profile safely falls back when name and remote image are unusable',
    (tester) async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final preferences = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            sharedPreferencesProvider.overrideWithValue(preferences),
            secureSessionStoreProvider.overrideWithValue(_EmptySessionStore()),
            profileRepositoryProvider.overrideWithValue(_ProfileRepository()),
          ],
          child: const MaterialApp(
            locale: Locale('en', 'US'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: <LocalizationsDelegate<Object>>[
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: ProfileScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('?'), findsOneWidget);
      expect(find.byTooltip('Change photo'), findsOneWidget);

      final nameField = find.byType(TextField).first;
      await tester.enterText(nameField, 'Parsa');
      await tester.pump();
      expect(
        tester.widget<TextField>(nameField).textDirection,
        TextDirection.ltr,
      );
      await tester.enterText(nameField, 'پارسا HardwareReserve');
      await tester.pump();
      expect(
        tester.widget<TextField>(nameField).textDirection,
        TextDirection.rtl,
      );
      expect(tester.takeException(), isNull);
    },
  );
}

class _EmptySessionStore extends SecureSessionStore {
  @override
  Future<AuthResponse?> read() async => null;

  @override
  Future<void> write(AuthResponse value) async {}

  @override
  Future<void> clear() async {}
}

class _ProfileRepository extends ProfileRepository {
  _ProfileRepository() : super(Dio());

  @override
  Future<ProfileModel> getProfile() async => ProfileModel(
    id: 7,
    fullName: '',
    email: 'user@example.com',
    role: 'User',
    profileImagePath: '/missing.jpg',
    profileImageUrl: 'https://example.invalid/missing.jpg',
    createdAt: DateTime.utc(2026, 8, 22),
  );
}
