import { LogIn, UserRound } from "lucide-react";
import { useCallback, useEffect, useState } from "react";
import { useTranslation } from "react-i18next";
import { Link, useLocation, useNavigate } from "react-router-dom";
import { authApi } from "../api/authApi";
import { getAuthenticatedDestination } from "../auth/destinations";
import { useAuth } from "../auth/useAuth";
import {
  AuthCaptchaField,
  AuthFeedback,
  AuthPasswordField,
  AuthSubmitButton,
  AuthTextField,
} from "../components/auth/AuthFields";
import { AuthShell } from "../components/auth/AuthShell";
import type { CaptchaChallenge } from "../types/api";
import {
  getApiErrorMessage,
  isApiCode,
} from "../utils/errors";

export function LoginPage() {
  const { t } = useTranslation();
  const navigate = useNavigate();
  const location = useLocation();
  const { setSession } = useAuth();

  const returnUrl = new URLSearchParams(location.search).get("returnUrl");

  const [captcha, setCaptcha] = useState<CaptchaChallenge | null>(null);
  const [captchaLoading, setCaptchaLoading] = useState(true);
  const [captchaError, setCaptchaError] = useState("");
  const [identifier, setIdentifier] = useState("");
  const [password, setPassword] = useState("");
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
      setCaptchaError(t("auth.login.captchaRequired"));
      return;
    }

    setLoading(true);
    setError("");

    try {
      const response = await authApi.login({
        identifier,
        password,
        captchaId: captcha.captchaId,
        captchaAnswer: Number(captchaAnswer),
      });

      setSession(response);
      navigate(getAuthenticatedDestination(response.user, returnUrl), { replace: true });
    } catch (submitError) {
        if (
        isApiCode(
          submitError,
          "EMAIL_VERIFICATION_REQUIRED",
        )
      ) {
          const params = new URLSearchParams({
            email: identifier.trim(),
            returnUrl: returnUrl ?? "/profile",
          });

          navigate(`/verify-email?${params.toString()}`);
          return;
        }

        setError(
          getApiErrorMessage(
            submitError,
            t("auth.login.failed"),
          ),
        );

        setCaptchaLoading(true);
        await loadCaptcha();
      } finally {
      setLoading(false);
    }
  };

  return (
    <AuthShell
      icon={LogIn}
      eyebrow={t("auth.login.eyebrow")}
      title={t("auth.login.title")}
      description={t("auth.login.description")}
      visualTitle={t("auth.login.visualTitle")}
      visualCopy={t("auth.login.visualCopy")}
    >
      <form className="space-y-5" onSubmit={onSubmit}>
        <AuthTextField
          id="login-identifier"
          name="identifier"
          label={t("auth.login.identifierLabel")}
          icon={UserRound}
          value={identifier}
          onChange={(event) => setIdentifier(event.target.value)}
          autoComplete="username"
          autoCapitalize="none"
          spellCheck={false}
          maxLength={320}
          placeholder={t("auth.login.identifierPlaceholder")}
          autoFocus
          required
        />

        <AuthPasswordField
          id="login-password"
          name="password"
          label={t("auth.login.passwordLabel")}
          value={password}
          onChange={(event) => setPassword(event.target.value)}
          autoComplete="current-password"
          maxLength={128}
          placeholder={t("auth.login.passwordPlaceholder")}
          labelAccessory={
            <Link
              to="/forgot-password"
              className="text-xs font-semibold text-brand-700 transition hover:text-brand-900 hover:underline"
            >
              {t("auth.login.forgotPassword")}
            </Link>
          }
          required
        />

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
          label={t("auth.login.submit")}
          loadingLabel={t("auth.login.submitting")}
          loading={loading}
          disabled={!captcha || captchaLoading}
        />
      </form>

      <p className="mt-6 text-center text-sm text-ink-600">
        {t("auth.login.newUser")} {" "}
        <Link to="/register" className="font-semibold text-brand-700 transition hover:text-brand-900 hover:underline">
          {t("auth.login.createAccount")}
        </Link>
      </p>
    </AuthShell>
  );
}
