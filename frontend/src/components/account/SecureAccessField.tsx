import { Check, Copy, Eye, EyeOff, type LucideIcon } from "lucide-react";
import { useTranslation } from "react-i18next";

interface SecureAccessFieldProps {
  icon: LucideIcon;
  label: string;
  value: string;
  concealed?: boolean;
  revealed?: boolean;
  copied?: boolean;
  onToggleVisibility?: () => void;
  onCopy: () => void;
}

export function SecureAccessField({
  icon: Icon,
  label,
  value,
  concealed = false,
  revealed = false,
  copied = false,
  onToggleVisibility,
  onCopy,
}: SecureAccessFieldProps) {
  const { t } = useTranslation();
  const displayValue = concealed && !revealed ? "••••••••••••" : value;

  return (
    <div className="rounded-control border border-white/10 bg-white/[0.055] p-3.5">
      <div className="flex items-center justify-between gap-3">
        <span className="inline-flex items-center gap-2 text-xs font-medium text-ink-400">
          <Icon aria-hidden="true" size={14} />
          {label}
        </span>
        <div className="flex items-center gap-1">
          {concealed && onToggleVisibility && (
            <button
              type="button"
              className="inline-flex size-8 items-center justify-center rounded-lg text-ink-400 transition duration-base hover:bg-white/10 hover:text-white focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-300"
              aria-label={revealed ? t("services.hideField", { label }) : t("services.showField", { label })}
              aria-pressed={revealed}
              onClick={onToggleVisibility}
            >
              {revealed ? <EyeOff aria-hidden="true" size={15} /> : <Eye aria-hidden="true" size={15} />}
            </button>
          )}
          <button
            type="button"
            className="inline-flex size-8 items-center justify-center rounded-lg text-ink-400 transition duration-base hover:bg-white/10 hover:text-white focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-brand-300"
            aria-label={copied ? t("services.copiedField", { label }) : t("services.copyField", { label })}
            onClick={onCopy}
          >
            {copied ? <Check aria-hidden="true" className="feedback-icon-enter text-emerald-300" size={15} /> : <Copy aria-hidden="true" size={15} />}
            <span className="sr-only" aria-live="polite">{copied ? t("services.copiedField", { label }) : ""}</span>
          </button>
        </div>
      </div>
      <p dir="ltr" className="mt-2 truncate text-left font-mono text-sm font-semibold text-white" title={concealed && !revealed ? undefined : value}>
        {displayValue}
      </p>
    </div>
  );
}
