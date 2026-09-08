import { Mail, UserPlus, UserRound } from "lucide-react";
import { useCallback, useEffect, useState } from "react";
import { useTranslation } from "react-i18next";
import { Link, useLocation, useNavigate } from "react-router-dom";
import { authApi } from "../api/authApi";
import {
  AuthCaptchaField,
  AuthFeedback,
  AuthPasswordField,
  AuthSubmitButton,
  AuthTextField,
} from "../components/auth/AuthFields";
import { AuthShell } from "../components/auth/AuthShell";
import { PasswordStrength } from "../components/auth/PasswordStrength";
import type { CaptchaChallenge } from "../types/api";
import { getApiErrorMessage, isApiCode } from "../utils/errors";

export function RegisterPage() {
  const { t } = useTranslation();
  const navigate = useNavigate();
  const location = useLocation();

  const returnUrl = new URLSearchParams(location.search).get("returnUrl") ?? "/profile";

  const [captcha, setCaptcha] = useState<CaptchaChallenge | null>(null);
  const [captchaLoading, setCaptchaLoading] = useState(true);
  const [captchaError, setCaptchaError] = useState("");
  const [fullName, setFullName] = useState("");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [emailError, setEmailError] = useState("");
  const [captchaAnswer, setCaptchaAnswer] = useState("");
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);

  const loadCaptcha = useCallback(async () => {
    try {
      const challenge = await authApi.getCaptcha();
      setCaptcha(challenge);
      setCaptchaAnswer("");
      setCaptchaError("");
    } catch {
      setCaptcha(null);
      setCaptchaError(t("auth.login.captchaLoadError"));
    } finally {
      setCaptchaLoading(false);
    }
  }, [t]);

  useEffect(() => {
    void loadCaptcha();
  }, [loadCaptcha]);

  const refreshCaptcha = () => {
    setCaptchaLoading(true);
    void loadCaptcha();
  };

  const onSubmit = async (event: React.FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    if (!captcha) {
      setCaptchaError(t("auth.register.captchaRequired"));
      return;
    }

    setLoading(true);
    setError("");
    setEmailError("");

    try {
      const response = await authApi.register({
        fullName,
        email,
        password,
        captchaId: captcha.captchaId,
        captchaAnswer: Number(captchaAnswer),
      });

      if (!response.requiresEmailVerification) {
        setError(t("auth.register.failed"));
        return;
      }

      const params = new URLSearchParams({
        email: response.email,
        returnUrl,
      });

      navigate(`/verify-email?${params.toString()}`, {
        replace: true,
        state: { verificationCodeSent: true },
      });
    } catch (submitError) {
      const message = getApiErrorMessage(submitError, t("auth.register.failed"));
      if (isApiCode(submitError, "EMAIL_ALREADY_EXISTS")) {
        setEmailError(message);
      } else {
        setError(message);
      }
      setCaptchaLoading(true);
      await loadCaptcha();
    } finally {
      setLoading(false);
    }
  };

  return (
    <AuthShell
      icon={UserPlus}
      eyebrow={t("auth.register.eyebrow")}
      title={t("auth.register.title")}
      description={t("auth.register.description")}
      visualTitle={t("auth.register.visualTitle")}
      visualCopy={t("auth.register.visualCopy")}
    >
      <form className="space-y-5" onSubmit={onSubmit}>
        <AuthTextField
          id="register-full-name"
          name="fullName"
          label={t("auth.register.fullName")}
          icon={UserRound}
          value={fullName}
          onChange={(event) => setFullName(event.target.value)}
          autoComplete="name"
          maxLength={200}
          placeholder={t("auth.register.fullNamePlaceholder")}
          autoFocus
          required
        />

        <AuthTextField
          id="register-email"
          name="email"
          label={t("auth.common.emailLabel")}
          icon={Mail}
          type="email"
          value={email}
          onChange={(event) => {
            setEmail(event.target.value);
            setEmailError("");
          }}
          autoComplete="email"
          autoCapitalize="none"
          spellCheck={false}
          maxLength={320}
          placeholder={t("auth.common.emailPlaceholder")}
          error={emailError}
          required
        />

        <AuthPasswordField
          id="register-password"
          name="password"
          label={t("auth.register.password")}
          value={password}
          onChange={(event) => setPassword(event.target.value)}
          autoComplete="new-password"
          minLength={8}
          maxLength={128}
          placeholder={t("auth.register.passwordPlaceholder")}
          required
        />

        <PasswordStrength password={password} id="register-password-strength" />

        <AuthCaptchaField
          captcha={captcha}
          answer={captchaAnswer}
          loading={captchaLoading}
          error={captchaError}
          onAnswerChange={setCaptchaAnswer}
          onRefresh={refreshCaptcha}
        />

        {error && <AuthFeedback message={error} tone="error" />}

        <AuthSubmitButton
          label={t("auth.register.submit")}
          loadingLabel={t("auth.register.submitting")}
          loading={loading}
          disabled={!captcha || captchaLoading}
        />
      </form>

      <p className="mt-6 text-center text-sm text-ink-600">
        {t("auth.register.existingUser")} {" "}
        <Link to="/login" className="font-semibold text-brand-700 transition hover:text-brand-900 hover:underline">
          {t("auth.register.signIn")}
        </Link>
      </p>
    </AuthShell>
  );
}
