import { isAxiosError, type AxiosError } from "axios";
import type { ErrorResponse } from "../types/api";
import i18n from "../i18n/config";

const apiCodeTranslationKeys: Record<string, string> = {
  AUTHENTICATION_REQUIRED: "apiErrors.authenticationRequired",
  FORBIDDEN: "apiErrors.forbidden",
  INVALID_CREDENTIALS: "apiErrors.invalidCredentials",
  INVALID_REFRESH_TOKEN: "apiErrors.invalidRefreshToken",
  CAPTCHA_INVALID_OR_EXPIRED: "apiErrors.captchaExpired",
  CAPTCHA_ANSWER_INCORRECT: "apiErrors.captchaIncorrect",
  EMAIL_ALREADY_EXISTS: "apiErrors.emailExists",
  EMAIL_VERIFICATION_REQUIRED:
    "apiErrors.emailVerificationRequired",
  EMAIL_VERIFICATION_CODE_INVALID:
    "apiErrors.verificationCodeInvalid",
  EMAIL_ALREADY_VERIFIED:
    "apiErrors.emailAlreadyVerified",
  PASSWORD_RESET_CODE_INVALID:
    "apiErrors.passwordResetCodeInvalid",
  PASSWORD_RESET_TOKEN_INVALID:
    "apiErrors.passwordResetTokenInvalid",
  EMAIL_CHANGE_SAME_EMAIL:
    "apiErrors.emailChangeSameEmail",
  EMAIL_CHANGE_EMAIL_IN_USE:
    "apiErrors.emailChangeEmailInUse",
  EMAIL_CHANGE_INVALID:
    "apiErrors.emailChangeInvalid",
  EMAIL_CHANGE_CODE_INVALID:
    "apiErrors.emailChangeCodeInvalid",
  EMAIL_CHANGE_ALREADY_VERIFIED:
    "apiErrors.emailChangeAlreadyVerified",
  EMAIL_CHANGE_RESEND_TOO_SOON:
    "apiErrors.emailChangeResendTooSoon",
  RESERVATION_TIME_CONFLICT:
    "apiErrors.overlap",
  RESERVATION_QUOTE_CHANGED:
    "apiErrors.reservationQuoteChanged",
  TOO_MANY_REQUESTS:
    "apiErrors.tooManyRequests",
};

const apiMessageTranslationKeys: Record<string, string> = {
  "Validation failed.": "apiErrors.validation",
  "Email already exists.": "apiErrors.emailExists",
  "Invalid credentials.": "apiErrors.invalidCredentials",
  "Invalid refresh token.": "apiErrors.invalidRefreshToken",
  "Reset token is invalid or expired.": "apiErrors.resetToken",
  "Captcha is invalid or expired.": "apiErrors.captchaExpired",
  "Captcha answer is incorrect.": "apiErrors.captchaIncorrect",
  "Server not found.": "apiErrors.serverNotFound",
  "Server not found or inactive.": "apiErrors.serverUnavailable",
  "Reservation not found.": "apiErrors.reservationNotFound",
  "StartTime must be in the future.": "apiErrors.startFuture",
  "EndTime must be greater than StartTime.": "apiErrors.endAfterStart",
  "EndTime must be later than StartTime.": "apiErrors.endAfterStart",
  "This server is already reserved in the selected time range.":
    "apiErrors.overlap",
  "You can only access your own reservation.":
    "apiErrors.ownReservation",
  "You can only pay your own reservation.":
    "apiErrors.ownPayment",
  "Reservation is not awaiting payment.":
    "apiErrors.notAwaitingPayment",
  "This reservation is already paid.":
    "apiErrors.alreadyPaid",
  "Credentials can only be assigned to paid reservations.":
    "apiErrors.paidCredentialsOnly",
  "User profile was not found.":
    "apiErrors.profileNotFound",
  "Email must be valid.": "apiErrors.invalidEmail",
  "Profile image file is required.":
    "apiErrors.imageRequired",
  "Profile image must be 2MB or smaller.":
    "apiErrors.imageTooLarge",
  "Only JPG, PNG, and WEBP images are supported.":
    "apiErrors.imageType",
  "Support conversation not found.":
    "apiErrors.supportNotFound",
  "Anonymous support session is invalid or expired.":
    "apiErrors.guestExpired",
  "Support conversation access is not permitted.":
    "apiErrors.supportForbidden",
  "Use authenticated support endpoints after signing in.":
    "apiErrors.supportSignIn",
  "Only conversations waiting for an administrator can be claimed.":
    "apiErrors.claimUnavailable",
  "Closed support conversations cannot change lifecycle state.":
    "apiErrors.closedConversation",
  "Closed support conversations do not accept reply suggestions.":
    "apiErrors.closedSuggestion",
  "An automated reply suggestion is temporarily unavailable.":
    "apiErrors.suggestionUnavailable",
  "Support quick reply not found.":
    "apiErrors.quickReplyNotFound",
  "Administrator access is required.":
    "apiErrors.adminRequired",
  "Content cannot contain only whitespace.":
    "apiErrors.blankContent",
  "Title cannot contain only whitespace.":
    "apiErrors.blankTitle",
  "ConfirmPassword must match NewPassword.":
    "apiErrors.passwordMismatch",
  "Email verification is required.":
    "apiErrors.emailVerificationRequired",
  "Verification code is invalid or expired.":
    "apiErrors.verificationCodeInvalid",
  "Email is already verified.":
    "apiErrors.emailAlreadyVerified",
  "Password reset code is invalid or expired.":
    "apiErrors.passwordResetCodeInvalid",
  "Too many requests. Please try again shortly.":
    "apiErrors.tooManyRequests",
};

function translateApiCode(code: string): string | null {
  const key = apiCodeTranslationKeys[code];

  return key ? i18n.t(key) : null;
}

function translateApiMessage(message: string): string | null {
  const key = apiMessageTranslationKeys[message];

  return key ? i18n.t(key) : null;
}

export function getApiErrorMessage(
  error: unknown,
  fallback = i18n.t("errors.generic"),
): string {
  const axiosError =
    error as AxiosError<ErrorResponse>;

  const response = axiosError.response?.data;

  if (response?.code) {
    const translatedCode =
      translateApiCode(response.code);

    if (translatedCode) {
      return translatedCode;
    }
  }

  const validationMessage = Object.values(
    response?.errors ?? {},
  ).flat()[0];

  if (validationMessage) {
    const translatedValidation =
      translateApiMessage(validationMessage);

    if (translatedValidation) {
      return translatedValidation;
    }
  }

  if (response?.message) {
    const translatedMessage =
      translateApiMessage(response.message);

    if (translatedMessage) {
      return translatedMessage;
    }

    return i18n.resolvedLanguage?.startsWith("fa")
      ? fallback
      : response.message;
  }

  if (
    error instanceof Error &&
    !("isAxiosError" in error)
  ) {
    return error.message || fallback;
  }

  return fallback;
}

export function isApiStatus(
  error: unknown,
  status: number,
): boolean {
  return (
    isAxiosError(error) &&
    error.response?.status === status
  );
}

export function isApiCode(
  error: unknown,
  code: string,
): boolean {
  if (!isAxiosError<ErrorResponse>(error)) {
    return false;
  }

  return error.response?.data?.code === code;
}
