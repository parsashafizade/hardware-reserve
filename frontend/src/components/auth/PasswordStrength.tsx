import { Check, Circle } from "lucide-react";
import { useTranslation } from "react-i18next";

type PasswordStrengthLevel = "weak" | "medium" | "strong";

function getPasswordStrength(password: string): PasswordStrengthLevel {
  const score = [
    password.length >= 8,
    password.length >= 12,
    /[a-z]/.test(password),
    /[A-Z]/.test(password),
    /\d/.test(password),
    /[^A-Za-z0-9]/.test(password),
  ].filter(Boolean).length;

  if (score >= 5) {
    return "strong";
  }

  return score >= 3 ? "medium" : "weak";
}

interface PasswordStrengthProps {
  password: string;
  id: string;
}

export function PasswordStrength({ password, id }: PasswordStrengthProps) {
  const { t } = useTranslation();
  const level = getPasswordStrength(password);
  const activeSegments = level === "strong" ? 3 : level === "medium" ? 2 : password ? 1 : 0;
  const meetsLengthRequirement = password.length >= 8 && password.length <= 128;

  return (
    <div id={id} className="password-strength" aria-live="polite">
      <div className="flex items-center justify-between gap-3 text-xs">
        <span className="font-medium text-ink-500">{t("auth.common.passwordStrength.label")}</span>
        {password && (
          <span className={`password-strength-label password-strength-label-${level}`}>
            {t(`auth.common.passwordStrength.${level}`)}
          </span>
        )}
      </div>

      <div className="mt-2 grid grid-cols-3 gap-1.5" aria-hidden="true">
        {[0, 1, 2].map((segment) => (
          <span
            key={segment}
            className={[
              "password-strength-segment",
              segment < activeSegments && `password-strength-segment-${level}`,
            ]
              .filter(Boolean)
              .join(" ")}
          />
        ))}
      </div>

      <div
        className={`password-requirement ${meetsLengthRequirement ? "password-requirement-met" : ""}`}
      >
        {meetsLengthRequirement ? (
          <Check aria-hidden="true" className="feedback-icon-enter" size={14} strokeWidth={2.6} />
        ) : (
          <Circle aria-hidden="true" size={12} />
        )}
        <span>{t("auth.common.passwordStrength.lengthRequirement")}</span>
      </div>
    </div>
  );
}
