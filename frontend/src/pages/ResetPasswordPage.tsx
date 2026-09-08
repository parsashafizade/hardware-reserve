import {
  ArrowLeft,
  RefreshCcw,
  ShieldCheck,
} from "lucide-react";
import { useMemo, useState } from "react";
import { useTranslation } from "react-i18next";
import { useAuth } from "../auth/useAuth";
import {
  Link,
  useLocation,
  useNavigate,
} from "react-router-dom";
import { authApi } from "../api/authApi";
import {
  AuthFeedback,
  AuthPasswordField,
  AuthSubmitButton,
} from "../components/auth/AuthFields";
import {
  AuthResendControl,
  AuthStepIndicator,
} from "../components/auth/AuthFlowControls";
import { AuthShell } from "../components/auth/AuthShell";
import { OtpInput } from "../components/auth/OtpInput";
import { PasswordStrength } from "../components/auth/PasswordStrength";
import { useCountdown } from "../hooks/useCountdown";
import { usePrefersReducedMotion } from "../hooks/usePrefersReducedMotion";
import { getApiErrorMessage } from "../utils/errors";

const RESEND_COOLDOWN_SECONDS = 60;
const SUCCESS_FEEDBACK_MS = 240;

export function ResetPasswordPage() {
  const { t } = useTranslation();
  const location = useLocation();
  const navigate = useNavigate();
  const { setSession } = useAuth();
  const prefersReducedMotion = usePrefersReducedMotion();

  const email = useMemo(
    () =>
      new URLSearchParams(location.search)
        .get("email")
        ?.trim() ?? "",
    [location.search],
  );
  const codeWasJustSent = Boolean(
    (location.state as { recoveryCodeSent?: boolean } | null)?.recoveryCodeSent,
  );
  const { seconds: resendSeconds, restart: restartResendCountdown } = useCountdown(
    codeWasJustSent ? RESEND_COOLDOWN_SECONDS : 0,
  );

  const [step, setStep] = useState<"code" | "password">("code");
  const [code, setCode] = useState("");
  const [resetToken, setResetToken] = useState("");
  const [newPassword, setNewPassword] = useState("");
  const [confirmPassword, setConfirmPassword] = useState("");
  const [confirmTouched, setConfirmTouched] = useState(false);
  const [message, setMessage] = useState("");
  const [error, setError] = useState("");
  const [resendMessage, setResendMessage] = useState("");
  const [resendError, setResendError] = useState("");
  const [loading, setLoading] = useState(false);
  const [resendLoading, setResendLoading] = useState(false);
  const [verificationSucceeded, setVerificationSucceeded] = useState(false);

  const passwordsMatch =
    newPassword.length > 0 &&
    confirmPassword.length > 0 &&
    newPassword === confirmPassword;
  const passwordsDoNotMatch =
    confirmPassword.length > 0 &&
    !passwordsMatch &&
    (confirmTouched || confirmPassword.length >= newPassword.length);
  const passwordLengthIsValid =
    newPassword.length >= 8 &&
    newPassword.length <= 128;

  const waitForSuccessFeedback = async () => {
    if (!prefersReducedMotion) {
      await new Promise((resolve) => window.setTimeout(resolve, SUCCESS_FEEDBACK_MS));
    }
  };

  const verifyCode = async (
    event: React.FormEvent<HTMLFormElement>,
  ) => {
    event.preventDefault();

    if (!email || code.length !== 6 || loading) {
      return;
    }

    setLoading(true);
    setError("");
    setMessage("");
    setResendError("");
    setResendMessage("");

    try {
      const response =
        await authApi.verifyPasswordResetCode({
          email,
          code,
        });

      setVerificationSucceeded(true);
      await waitForSuccessFeedback();
      setResetToken(response.resetToken);
      setStep("password");
      setMessage(t("auth.reset.codeVerified"));
    } catch (submitError) {
      setError(
        getApiErrorMessage(
          submitError,
          t("auth.reset.invalidCode"),
        ),
      );
    } finally {
      setLoading(false);
    }
  };

  const resendCode = async () => {
    if (!email || resendLoading || resendSeconds > 0) {
      return;
    }

    setResendLoading(true);
    setResendError("");
    setResendMessage("");

    try {
      await authApi.forgotPassword({ email });
      setCode("");
      setError("");
      setVerificationSucceeded(false);
      setResendMessage(t("auth.reset.resendSuccess"));
      restartResendCountdown(RESEND_COOLDOWN_SECONDS);
    } catch (resendFailure) {
      setResendError(
        getApiErrorMessage(
          resendFailure,
          t("auth.reset.resendFailed"),
        ),
      );
    } finally {
      setResendLoading(false);
    }
  };

  const resetPassword = async (
    event: React.FormEvent<HTMLFormElement>,
  ) => {
    event.preventDefault();

    if (
      !resetToken ||
      !passwordsMatch ||
      !passwordLengthIsValid ||
      loading
    ) {
      return;
    }

    setLoading(true);
    setError("");
    setMessage("");

    try {
      const response = await authApi.resetPassword({
        token: resetToken,
        newPassword,
        confirmPassword,
      });

      setMessage(t("auth.reset.success"));
      await waitForSuccessFeedback();
      setSession(response);
      navigate("/profile", {
        replace: true,
      });
    } catch (submitError) {
      setError(
        getApiErrorMessage(
          submitError,
          t("errors.generic"),
        ),
      );
    } finally {
      setLoading(false);
    }
  };

  if (!email) {
    return (
      <AuthShell
        icon={RefreshCcw}
        eyebrow={t("auth.reset.eyebrow")}
        title={t("auth.reset.title")}
        description={t("auth.reset.description")}
        visualTitle={t("auth.reset.visualTitle")}
        visualCopy={t("auth.reset.visualCopy")}
      >
        <AuthFeedback
          message={t("auth.reset.missingEmail")}
          tone="error"
        />

        <Link
          to="/forgot-password"
          className="mt-6 inline-flex items-center gap-2 text-sm font-semibold text-brand-700 transition hover:text-brand-900"
        >
          <ArrowLeft
            aria-hidden="true"
            className="directional-icon"
            size={16}
          />
          {t("auth.reset.backToForgot")}
        </Link>
      </AuthShell>
    );
  }

  return (
    <AuthShell
      icon={step === "code" ? ShieldCheck : RefreshCcw}
      eyebrow={t("auth.reset.eyebrow")}
      title={
        step === "code"
          ? t("auth.reset.codeTitle")
          : t("auth.reset.passwordTitle")
      }
      description={
        step === "code"
          ? t("auth.reset.codeDescription", { email })
          : t("auth.reset.passwordDescription")
      }
      visualTitle={t("auth.reset.visualTitle")}
      visualCopy={t("auth.reset.visualCopy")}
    >
      <AuthStepIndicator
        label={t("auth.reset.progressLabel")}
        currentStep={step === "code" ? 1 : 2}
        steps={[
          t("auth.reset.steps.email"),
          t("auth.reset.steps.code"),
          t("auth.reset.steps.password"),
        ]}
      />

      <div key={step} className="auth-step-enter">
        {step === "code" ? (
          <form
            className="space-y-5"
            onSubmit={verifyCode}
          >
            <OtpInput
              id="password-reset-code"
              label={t("auth.reset.codeLabel")}
              value={code}
              onChange={(value) => {
                setCode(value);
                setError("");
              }}
              error={error}
              success={verificationSucceeded}
              disabled={loading || resendLoading}
              autoFocus
            />

            {resendError && (
              <AuthFeedback
                message={resendError}
                tone="error"
              />
            )}

            {resendMessage && (
              <AuthFeedback
                message={resendMessage}
                tone="success"
              />
            )}

            <AuthSubmitButton
              label={t("auth.reset.verifyCode")}
              loadingLabel={t("auth.reset.verifyingCode")}
              loading={loading}
              disabled={code.length !== 6 || verificationSucceeded}
            />

            <AuthResendControl
              seconds={resendSeconds}
              loading={resendLoading}
              disabled={loading || verificationSucceeded}
              onResend={() => void resendCode()}
            />
          </form>
        ) : (
          <form
            className="space-y-5"
            onSubmit={resetPassword}
          >
            <AuthPasswordField
              id="reset-new-password"
              name="newPassword"
              label={t("auth.reset.newPassword")}
              value={newPassword}
              onChange={(event) => {
                setNewPassword(event.target.value);
                setError("");
              }}
              autoComplete="new-password"
              minLength={8}
              maxLength={128}
              placeholder={t("auth.reset.newPasswordPlaceholder")}
              autoFocus
              required
            />

            <PasswordStrength
              password={newPassword}
              id="reset-password-strength"
            />

            <AuthPasswordField
              id="reset-confirm-password"
              name="confirmPassword"
              label={t("auth.reset.confirmPassword")}
              value={confirmPassword}
              onChange={(event) => {
                setConfirmPassword(event.target.value);
                setError("");
              }}
              onBlur={() => setConfirmTouched(true)}
              autoComplete="new-password"
              minLength={8}
              maxLength={128}
              placeholder={t("auth.reset.confirmPasswordPlaceholder")}
              error={
                passwordsDoNotMatch
                  ? t("auth.reset.mismatch")
                  : undefined
              }
              success={
                passwordsMatch
                  ? t("auth.reset.passwordsMatch")
                  : undefined
              }
              required
            />

            {message && (
              <AuthFeedback
                message={message}
                tone="success"
              />
            )}

            {error && (
              <AuthFeedback
                message={error}
                tone="error"
              />
            )}

            <AuthSubmitButton
              label={t("auth.reset.submit")}
              loadingLabel={t("auth.reset.submitting")}
              loading={loading}
              disabled={
                !passwordsMatch ||
                !passwordLengthIsValid
              }
            />
          </form>
        )}
      </div>

      <Link
        to="/login"
        className="mt-6 inline-flex items-center gap-2 text-sm font-semibold text-brand-700 transition hover:text-brand-900"
      >
        <ArrowLeft
          aria-hidden="true"
          className="directional-icon"
          size={16}
        />
        {t("auth.common.backToSignIn")}
      </Link>
    </AuthShell>
  );
}
