import { ArrowLeft, Mail, MailCheck } from "lucide-react";
import { useState } from "react";
import { useTranslation } from "react-i18next";
import { Link, useNavigate } from "react-router-dom";
import { authApi } from "../api/authApi";
import {
  AuthFeedback,
  AuthSubmitButton,
  AuthTextField,
} from "../components/auth/AuthFields";
import { AuthStepIndicator } from "../components/auth/AuthFlowControls";
import { AuthShell } from "../components/auth/AuthShell";
import { getApiErrorMessage } from "../utils/errors";

export function ForgotPasswordPage() {
  const { t } = useTranslation();
  const navigate = useNavigate();

  const [email, setEmail] = useState("");
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);

  const onSubmit = async (
    event: React.FormEvent<HTMLFormElement>,
  ) => {
    event.preventDefault();

    const normalizedEmail = email.trim();

    setLoading(true);
    setError("");

    try {
      await authApi.forgotPassword({
        email: normalizedEmail,
      });

      const params = new URLSearchParams({
        email: normalizedEmail,
      });

      navigate(
        `/reset-password?${params.toString()}`,
        { state: { recoveryCodeSent: true } },
      );
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

  return (
    <AuthShell
      icon={MailCheck}
      eyebrow={t("auth.forgot.eyebrow")}
      title={t("auth.forgot.title")}
      description={t("auth.forgot.description")}
      visualTitle={t("auth.forgot.visualTitle")}
      visualCopy={t("auth.forgot.visualCopy")}
    >
      <AuthStepIndicator
        label={t("auth.reset.progressLabel")}
        currentStep={0}
        steps={[
          t("auth.reset.steps.email"),
          t("auth.reset.steps.code"),
          t("auth.reset.steps.password"),
        ]}
      />

      <form className="auth-step-enter space-y-5" onSubmit={onSubmit}>
        <AuthTextField
          id="forgot-email"
          name="email"
          label={t("auth.common.emailLabel")}
          icon={Mail}
          type="email"
          value={email}
          onChange={(event) =>
            setEmail(event.target.value)
          }
          autoComplete="email"
          autoCapitalize="none"
          spellCheck={false}
          maxLength={320}
          placeholder={t(
            "auth.common.emailPlaceholder",
          )}
          autoFocus
          required
        />

        {error && (
          <AuthFeedback
            message={error}
            tone="error"
          />
        )}

        <AuthSubmitButton
          label={t("auth.forgot.submit")}
          loadingLabel={t(
            "auth.forgot.submitting",
          )}
          loading={loading}
        />
      </form>

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
