import 'package:flutter/widgets.dart';

import '../localization/app_localizations.dart';
import 'api_failure.dart';

String presentError(BuildContext context, Object error) {
  final failure = ApiFailure.from(error);
  final key = switch (failure.code) {
    'INVALID_CREDENTIALS' => 'auth.error.invalidCredentials',
    'EMAIL_ALREADY_EXISTS' => 'auth.error.emailExists',
    'EMAIL_VERIFICATION_REQUIRED' => 'auth.error.verificationRequired',
    'EMAIL_VERIFICATION_CODE_INVALID' => 'auth.error.invalidCode',
    'CAPTCHA_INVALID_OR_EXPIRED' => 'auth.error.captchaExpired',
    'CAPTCHA_ANSWER_INCORRECT' => 'auth.error.captchaIncorrect',
    'PASSWORD_RESET_CODE_INVALID' => 'auth.error.invalidCode',
    'RESERVATION_TIME_CONFLICT' => 'reservation.conflict',
    _ => switch (failure.kind) {
      ApiFailureKind.offline => 'error.offline',
      ApiFailureKind.timeout => 'error.timeout',
      ApiFailureKind.unauthorized => 'error.unauthorized',
      ApiFailureKind.forbidden => 'error.forbidden',
      ApiFailureKind.server => 'error.server',
      ApiFailureKind.validation => 'error.validation',
      ApiFailureKind.unknown => 'error.generic',
    },
  };
  final localized = context.l10n.tr(key);
  if (localized != key) return localized;
  return context.l10n.isPersian
      ? context.l10n.tr('error.generic')
      : failure.message;
}
