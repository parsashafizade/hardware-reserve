import 'package:flutter_test/flutter_test.dart';
import 'package:hardware_reserve/features/auth/data/auth_models.dart';

void main() {
  test(
    'AuthResponse preserves the shared camelCase contract and UTC instants',
    () {
      final response = AuthResponse.fromJson({
        'accessToken': 'access-secret',
        'accessTokenExpiresAt': '2026-08-20T10:15:00+03:30',
        'refreshToken': 'refresh-secret',
        'refreshTokenExpiresAt': '2026-09-20T06:45:00',
        'user': {
          'id': 42,
          'fullName': 'کاربر تست',
          'email': 'user@example.com',
          'role': 'Admin',
        },
      });

      expect(response.accessTokenExpiresAt, DateTime.utc(2026, 8, 20, 6, 45));
      expect(response.refreshTokenExpiresAt.isUtc, isTrue);
      expect(response.user.isAdmin, isTrue);

      final roundTrip = response.toJson();
      expect(
        roundTrip.keys,
        containsAll(<String>[
          'accessToken',
          'accessTokenExpiresAt',
          'refreshToken',
          'refreshTokenExpiresAt',
          'user',
        ]),
      );
      expect(roundTrip['accessTokenExpiresAt'], endsWith('Z'));
      expect(roundTrip['refreshTokenExpiresAt'], endsWith('Z'));
    },
  );

  test('malformed auth responses fail closed', () {
    expect(
      () => AuthResponse.fromJson({
        'accessToken': '',
        'accessTokenExpiresAt': 'not-a-date',
        'refreshToken': 'token',
        'refreshTokenExpiresAt': '2026-09-20T00:00:00Z',
        'user': const <String, Object?>{},
      }),
      throwsFormatException,
    );
  });
}
