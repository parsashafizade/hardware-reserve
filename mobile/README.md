# HardwareReserve Mobile

One Flutter application for the HardwareReserve user experience on Android and
iOS. It consumes the same ASP.NET Core API as the React website; it contains no
duplicated pricing, availability, authorization, or support business logic.

## API environment

Use one absolute API origin for REST, images, and SignalR:

```sh
flutter run --dart-define=API_BASE_URL=https://api.example.com
```

Release builds require an HTTPS `API_BASE_URL`. Debug builds default to
`http://10.0.2.2:5239` on the Android emulator and
`http://127.0.0.1:5239` on the iOS simulator. Local cleartext access is enabled
only in the Android debug/profile manifests; release Android traffic remains
HTTPS-only by configuration. iOS permits local development networking.

## Development checks

```sh
flutter pub get
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
flutter build apk --debug
flutter build ios --simulator
```

## Session and reliability rules

- Access and refresh tokens are stored together in Keychain/Keystore-backed
  secure storage. Only the non-secret locale preference uses shared preferences.
- Refresh is single-flight and rotated credentials are written atomically.
  Definitive refresh rejection clears the session; transport and server errors
  do not.
- Support send retries retain the original `clientMessageId` and content.
- Reservation and payment writes are never blindly retried after an ambiguous
  network result. The app first reconciles persisted reservation/payment state.
- API dates are sent as UTC ISO-8601 values and localized only for display.
- SignalR is advisory. Reconnects restore conversation subscriptions, while
  HTTP/database state remains authoritative.

Authenticated Admin accounts use a role-gated workspace in the same app. It
reuses the shared session, Dio client, localization catalog, design system, and
Support SignalR connection; every Admin API remains protected by the backend
`Admin` role policy.
