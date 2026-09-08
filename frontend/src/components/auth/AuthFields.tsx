import {
  AlertCircle,
  ArrowRight,
  CheckCircle2,
  Eye,
  EyeOff,
  LoaderCircle,
  LockKeyhole,
  RefreshCw,
  type LucideIcon,
} from "lucide-react";
import { useState, type InputHTMLAttributes, type ReactNode } from "react";
import { useTranslation } from "react-i18next";
import type { CaptchaChallenge } from "../../types/api";

interface AuthTextFieldProps extends Omit<InputHTMLAttributes<HTMLInputElement>, "className"> {
  id: string;
  label: string;
  icon: LucideIcon;
  hint?: string;
  error?: string;
  labelAccessory?: ReactNode;
}

interface AuthPasswordFieldProps extends Omit<InputHTMLAttributes<HTMLInputElement>, "className" | "type"> {
  id: string;
  label: string;
  hint?: string;
  error?: string;
  success?: string;
  labelAccessory?: ReactNode;
}

interface AuthCaptchaFieldProps {
  captcha: CaptchaChallenge | null;
  answer: string;
  loading: boolean;
  error?: string;
  onAnswerChange: (value: string) => void;
  onRefresh: () => void;
}

interface AuthFeedbackProps {
  message: string;
  tone: "error" | "success";
}

interface AuthSubmitButtonProps {
  label: string;
  loadingLabel: string;
  loading: boolean;
  disabled?: boolean;
}

function describedBy(id: string, hint?: string, error?: string, success?: string) {
  return [hint && id + "-hint", error && id + "-error", success && id + "-success"]
    .filter(Boolean)
    .join(" ") || undefined;
}

export function AuthTextField({
  id,
  label,
  icon: Icon,
  hint,
  error,
  labelAccessory,
  ...inputProps
}: AuthTextFieldProps) {
  return (
    <div className="field">
      <div className="flex items-center justify-between gap-3">
        <label htmlFor={id}>{label}</label>
        {labelAccessory}
      </div>
      <div className="relative">
        <Icon
          aria-hidden="true"
          className="pointer-events-none absolute start-3.5 top-1/2 -translate-y-1/2 text-ink-400"
          size={17}
        />
        <input
          {...inputProps}
          id={id}
          className={["input ps-11", error && "input-error"].filter(Boolean).join(" ")}
          aria-invalid={error ? true : undefined}
          aria-describedby={describedBy(id, hint, error)}
        />
      </div>
      {hint && !error && (
        <p id={id + "-hint"} className="field-hint">
          {hint}
        </p>
      )}
      {error && (
        <p id={id + "-error"} className="field-error">
          {error}
        </p>
      )}
    </div>
  );
}

export function AuthPasswordField({
  id,
  label,
  hint,
  error,
  success,
  labelAccessory,
  ...inputProps
}: AuthPasswordFieldProps) {
  const { t } = useTranslation();
  const [visible, setVisible] = useState(false);

  return (
    <div className="field">
      <div className="flex items-center justify-between gap-3">
        <label htmlFor={id}>{label}</label>
        {labelAccessory}
      </div>
      <div className="relative">
        <LockKeyhole
          aria-hidden="true"
          className="pointer-events-none absolute start-3.5 top-1/2 -translate-y-1/2 text-ink-400"
          size={17}
        />
        <input
          {...inputProps}
          id={id}
          type={visible ? "text" : "password"}
          className={["input pe-12 ps-11", error && "input-error", success && "input-success"]
            .filter(Boolean)
            .join(" ")}
          aria-invalid={error ? true : undefined}
          aria-describedby={describedBy(id, hint, error, success)}
        />
        <button
          type="button"
          className="control-press absolute end-1.5 top-1/2 inline-flex size-9 -translate-y-1/2 items-center justify-center rounded-lg text-ink-500 transition duration-fast hover:bg-brand-50 hover:text-brand-700 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-400 focus-visible:ring-offset-1"
          aria-label={visible ? t("auth.common.hidePassword") : t("auth.common.showPassword")}
          aria-pressed={visible}
          onClick={() => setVisible((current) => !current)}
        >
          {visible ? (
            <EyeOff aria-hidden="true" className="motion-icon-enter" size={17} />
          ) : (
            <Eye aria-hidden="true" className="motion-icon-enter" size={17} />
          )}
        </button>
      </div>
      {hint && !error && (
        <p id={id + "-hint"} className="field-hint">
          {hint}
        </p>
      )}
      {error && (
        <p id={id + "-error"} className="field-error">
          {error}
        </p>
      )}
      {success && !error && (
        <p id={id + "-success"} className="field-success" role="status">
          <CheckCircle2 aria-hidden="true" size={14} />
          {success}
        </p>
      )}
    </div>
  );
}

export function AuthCaptchaField({
  captcha,
  answer,
  loading,
  error,
  onAnswerChange,
  onRefresh,
}: AuthCaptchaFieldProps) {
  const { t } = useTranslation();

  return (
    <div className="field">
      <div className="flex items-center justify-between gap-3">
        <label htmlFor="captcha-answer">{t("auth.common.captcha.label")}</label>
        <button
          type="button"
          className="inline-flex items-center gap-1.5 rounded-lg px-2 py-1 text-xs font-semibold text-brand-700 transition hover:bg-brand-50 hover:text-brand-900 disabled:cursor-not-allowed disabled:opacity-50"
          onClick={onRefresh}
          disabled={loading}
        >
          <RefreshCw aria-hidden="true" className={loading ? "animate-spin" : ""} size={14} />
          {t("auth.common.captcha.refresh")}
        </button>
      </div>

      {captcha ? (
        <div className="grid grid-cols-[auto_1fr] gap-2 rounded-control border border-border-subtle bg-surface-muted/70 p-2">
          <div dir="ltr" className="flex min-w-28 items-center justify-center rounded-xl border border-brand-200 bg-white px-4 text-sm font-bold text-brand-900 shadow-control">
            {captcha.a} + {captcha.b} =
          </div>
          <input
            id="captcha-answer"
            name="captchaAnswer"
            className={["input bg-white", error && "input-error"].filter(Boolean).join(" ")}
            type="number"
            inputMode="numeric"
            min={0}
            max={18}
            value={answer}
            onChange={(event) => onAnswerChange(event.target.value)}
            placeholder={t("auth.common.captcha.answer")}
            autoComplete="off"
            required
            aria-invalid={error ? true : undefined}
            aria-describedby={error ? "captcha-error" : "captcha-hint"}
          />
        </div>
      ) : (
        <div className="flex min-h-16 items-center gap-3 rounded-control border border-dashed border-border-strong bg-surface-muted/70 px-4">
          {loading ? (
            <>
              <LoaderCircle aria-hidden="true" className="animate-spin text-brand-600" size={18} />
              <p className="text-sm text-ink-600">{t("auth.common.captcha.loading")}</p>
            </>
          ) : (
            <>
              <AlertCircle aria-hidden="true" className="text-status-danger" size={18} />
              <p className="text-sm text-ink-600">{t("auth.common.captcha.unavailable")}</p>
            </>
          )}
        </div>
      )}

      {error ? (
        <p id="captcha-error" className="field-error">
          {error}
        </p>
      ) : (
        <p id="captcha-hint" className="field-hint">
          {t("auth.common.captcha.hint")}
        </p>
      )}
    </div>
  );
}

export function AuthFeedback({ message, tone }: AuthFeedbackProps) {
  const Icon = tone === "error" ? AlertCircle : CheckCircle2;

  return (
    <div
      className={[
        tone === "error" ? "alert-error" : "alert-success",
        "flex items-start gap-2.5",
      ].join(" ")}
      role={tone === "error" ? "alert" : "status"}
      aria-live={tone === "error" ? "assertive" : "polite"}
    >
      <Icon aria-hidden="true" className="mt-0.5" size={17} />
      <p dir="auto" className="support-bidi">{message}</p>
    </div>
  );
}

export function AuthSubmitButton({
  label,
  loadingLabel,
  loading,
  disabled = false,
}: AuthSubmitButtonProps) {
  return (
    <button disabled={disabled || loading} className="btn-primary min-h-12 w-full" type="submit">
      {loading ? (
        <>
          <LoaderCircle aria-hidden="true" className="animate-spin" size={17} />
          {loadingLabel}
        </>
      ) : (
        <>
          {label}
          <ArrowRight aria-hidden="true" className="directional-icon" size={17} />
        </>
      )}
    </button>
  );
}
