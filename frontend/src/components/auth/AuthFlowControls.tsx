import { Check, Clock3, LoaderCircle, RefreshCw } from "lucide-react";
import { useTranslation } from "react-i18next";
import { useLocale } from "../../i18n/useLocale";

interface AuthResendControlProps {
  seconds: number;
  loading: boolean;
  onResend: () => void;
  disabled?: boolean;
}

interface AuthStepIndicatorProps {
  steps: string[];
  currentStep: number;
  label: string;
}

export function AuthResendControl({
  seconds,
  loading,
  onResend,
  disabled = false,
}: AuthResendControlProps) {
  const { t } = useTranslation();
  const { formatNumber } = useLocale();

  return (
    <div className="flex min-h-10 items-center justify-center">
      {seconds > 0 ? (
        <p className="inline-flex items-center gap-2 text-xs font-medium text-ink-500">
          <Clock3 aria-hidden="true" size={15} />
          {t("auth.common.resend.availableIn", {
            seconds: formatNumber(seconds),
          })}
        </p>
      ) : (
        <button
          type="button"
          className="btn-ghost min-h-10 px-3"
          disabled={disabled || loading}
          onClick={onResend}
        >
          {loading ? (
            <LoaderCircle aria-hidden="true" className="animate-spin" size={15} />
          ) : (
            <RefreshCw aria-hidden="true" size={15} />
          )}
          {loading ? t("auth.common.resend.sending") : t("auth.common.resend.action")}
        </button>
      )}
    </div>
  );
}

export function AuthStepIndicator({ steps, currentStep, label }: AuthStepIndicatorProps) {
  return (
    <nav className="auth-step-indicator" aria-label={label}>
      <ol
        className="grid"
        style={{ gridTemplateColumns: "repeat(" + steps.length + ", minmax(0, 1fr))" }}
      >
        {steps.map((step, index) => {
          const complete = index < currentStep;
          const active = index === currentStep;

          return (
            <li
              key={step}
              className={[
                "auth-step-item",
                complete && "auth-step-item-complete",
                active && "auth-step-item-active",
              ]
                .filter(Boolean)
                .join(" ")}
              aria-current={active ? "step" : undefined}
            >
              <span className="auth-step-marker" aria-hidden="true">
                {complete ? <Check size={12} strokeWidth={3} /> : index + 1}
              </span>
              <span className="truncate">{step}</span>
            </li>
          );
        })}
      </ol>
    </nav>
  );
}
