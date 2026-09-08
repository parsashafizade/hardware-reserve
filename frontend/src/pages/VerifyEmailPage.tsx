import { MailCheck } from "lucide-react";
import { useState } from "react";
import { useTranslation } from "react-i18next";
import { Link, useLocation, useNavigate } from "react-router-dom";
import { authApi } from "../api/authApi";
import { useAuth } from "../auth/useAuth";
import {
  AuthFeedback,
  AuthSubmitButton,
} from "../components/auth/AuthFields";
import { AuthResendControl } from "../components/auth/AuthFlowControls";
import { AuthShell } from "../components/auth/AuthShell";
import { OtpInput } from "../components/auth/OtpInput";
import { useCountdown } from "../hooks/useCountdown";
import { usePrefersReducedMotion } from "../hooks/usePrefersReducedMotion";
import { getApiErrorMessage } from "../utils/errors";

const RESEND_COOLDOWN_SECONDS = 60;

export function VerifyEmailPage() {
  const { t } = useTranslation();
  const navigate = useNavigate();
  const location = useLocation();
  const { setSession } = useAuth();
  const prefersReducedMotion = usePrefersReducedMotion();

  const searchParams = new URLSearchParams(location.search);
  const email = searchParams.get("email")?.trim() ?? "";
  const returnUrl = searchParams.get("returnUrl") ?? "/profile";
  const codeWasJustSent = Boolean(
    (location.state as { verificationCodeSent?: boolean } | null)?.verificationCodeSent,
  );

  const [code, setCode] = useState("");
  const [loading, setLoading] = useState(false);
  const [resendLoading, setResendLoading] = useState(false);
  const { seconds: resendSeconds, restart: restartResendCountdown } = useCountdown(
    codeWasJustSent ? RESEND_COOLDOWN_SECONDS : 0,
  );
  const [error, setError] = useState("");
  const [resendError, setResendError] = useState("");
  const [resendMessage, setResendMessage] = useState("");
  const [verificationSucceeded, setVerificationSucceeded] = useState(false);

  const onSubmit = async (
    event: React.FormEvent<HTMLFormElement>,
  ) => {
    event.preventDefault();

    if (!email) {
      setError(t("auth.verify.missingEmail"));
      return;
    }

    setLoading(true);
    setError("");
    setResendError("");
    setResendMessage("");

    try {
      const response = await authApi.verifyEmail({
        email,
        code,
      });

      setVerificationSucceeded(true);
      if (!prefersReducedMotion) {
        await new Promise((resolve) => window.setTimeout(resolve, 240));
      }
      setSession(response);
      navigate(returnUrl, { replace: true });
    } catch (submitError) {
      setError(
        getApiErrorMessage(
          submitError,
          t("auth.verify.failed"),
        ),
      );
    } finally {
      setLoading(false);
    }
  };

  const onResend = async () => {
    if (!email || resendSeconds > 0 || resendLoading) {
      return;
    }

    setResendLoading(true);
    setResendError("");
    setResendMessage("");

    try {
      await authApi.resendVerificationCode({ email });

      setCode("");
      setError("");
      setVerificationSucceeded(false);
      setResendMessage(t("auth.verify.resendSuccess"));
      restartResendCountdown(RESEND_COOLDOWN_SECONDS);
    } catch (resendError) {
      setResendError(
        getApiErrorMessage(
          resendError,
          t("auth.verify.resendFailed"),
        ),
      );
    } finally {
      setResendLoading(false);
    }
  };

  return (
    <AuthShell
      icon={MailCheck}
      eyebrow={t("auth.verify.eyebrow")}
      title={t("auth.verify.title")}
      description={t("auth.verify.description")}
      visualTitle={t("auth.verify.visualTitle")}
      visualCopy={t("auth.verify.visualCopy")}
    >
      <form className="space-y-5" onSubmit={onSubmit}>
        {email && (
          <div className="rounded-control border border-border-subtle bg-surface-muted/70 px-4 py-3">
            <p className="text-xs text-ink-500">
              {t("auth.verify.sentTo")}
            </p>
            <p
              dir="ltr"
              className="mt-1 break-all text-sm font-semibold text-ink-800"
            >
              {email}
            </p>
          </div>
        )}

        <OtpInput
          id="email-verification-code"
          label={t("auth.verify.codeLabel")}
          value={code}
          onChange={(value) => {
            setCode(value);
            setError("");
          }}
          autoFocus
          error={error}
          success={verificationSucceeded}
          disabled={loading || resendLoading}
        />

        {resendError && (
          <AuthFeedback message={resendError} tone="error" />
        )}

        {resendMessage && (
          <AuthFeedback message={resendMessage} tone="success" />
        )}

        <AuthSubmitButton
          label={t("auth.verify.submit")}
          loadingLabel={t("auth.verify.submitting")}
          loading={loading}
          disabled={code.length !== 6 || !email || verificationSucceeded}
        />

        <AuthResendControl
          seconds={resendSeconds}
          loading={resendLoading}
          disabled={!email || loading || verificationSucceeded}
          onResend={() => void onResend()}
        />
      </form>

      <p className="mt-6 text-center text-sm text-ink-600">
        <Link
          to="/login"
          className="font-semibold text-brand-700 transition hover:text-brand-900 hover:underline"
        >
          {t("auth.verify.backToLogin")}
        </Link>
      </p>
    </AuthShell>
  );
}
