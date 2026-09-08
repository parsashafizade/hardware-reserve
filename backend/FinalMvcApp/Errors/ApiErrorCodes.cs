namespace FinalMvcApp.Errors;

public static class ApiErrorCodes
{
    public const string AuthenticationRequired =
        "AUTHENTICATION_REQUIRED";

    public const string Forbidden =
        "FORBIDDEN";

    public const string InvalidCredentials =
        "INVALID_CREDENTIALS";

    public const string InvalidRefreshToken =
        "INVALID_REFRESH_TOKEN";

    public const string CaptchaInvalidOrExpired =
        "CAPTCHA_INVALID_OR_EXPIRED";

    public const string CaptchaAnswerIncorrect =
        "CAPTCHA_ANSWER_INCORRECT";

    public const string EmailAlreadyExists =
        "EMAIL_ALREADY_EXISTS";

    public const string EmailVerificationRequired =
        "EMAIL_VERIFICATION_REQUIRED";

    public const string EmailVerificationCodeInvalid =
        "EMAIL_VERIFICATION_CODE_INVALID";

    public const string EmailAlreadyVerified =
        "EMAIL_ALREADY_VERIFIED";

    public const string PasswordResetCodeInvalid =
        "PASSWORD_RESET_CODE_INVALID";

    public const string PasswordResetTokenInvalid =
        "PASSWORD_RESET_TOKEN_INVALID";

    public const string EmailChangeSameEmail =
        "EMAIL_CHANGE_SAME_EMAIL";

    public const string EmailChangeEmailInUse =
        "EMAIL_CHANGE_EMAIL_IN_USE";

    public const string EmailChangeInvalid =
        "EMAIL_CHANGE_INVALID";

    public const string EmailChangeCodeInvalid =
        "EMAIL_CHANGE_CODE_INVALID";

    public const string EmailChangeAlreadyVerified =
        "EMAIL_CHANGE_ALREADY_VERIFIED";

    public const string EmailChangeResendTooSoon =
        "EMAIL_CHANGE_RESEND_TOO_SOON";

    public const string ReservationTimeConflict =
        "RESERVATION_TIME_CONFLICT";

    public const string ReservationQuoteChanged =
        "RESERVATION_QUOTE_CHANGED";

    public const string TooManyRequests =
        "TOO_MANY_REQUESTS";
}
