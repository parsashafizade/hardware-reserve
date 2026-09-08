import { Check } from "lucide-react";
import {
  useEffect,
  useRef,
  type ClipboardEvent,
  type KeyboardEvent,
} from "react";
import { useTranslation } from "react-i18next";

const PERSIAN_DIGITS = "۰۱۲۳۴۵۶۷۸۹";
const ARABIC_DIGITS = "٠١٢٣٤٥٦٧٨٩";

function normalizeOtpDigits(value: string): string {
  return Array.from(value)
    .map((character) => {
      const persianIndex = PERSIAN_DIGITS.indexOf(character);
      if (persianIndex >= 0) {
        return String(persianIndex);
      }

      const arabicIndex = ARABIC_DIGITS.indexOf(character);
      return arabicIndex >= 0 ? String(arabicIndex) : character;
    })
    .join("")
    .replace(/\D/g, "");
}

interface OtpInputProps {
  id: string;
  label: string;
  value: string;
  onChange: (value: string) => void;
  error?: string;
  success?: boolean;
  disabled?: boolean;
  autoFocus?: boolean;
  length?: number;
}

export function OtpInput({
  id,
  label,
  value,
  onChange,
  error,
  success = false,
  disabled = false,
  autoFocus = false,
  length = 6,
}: OtpInputProps) {
  const { t } = useTranslation();
  const inputRefs = useRef<Array<HTMLInputElement | null>>([]);
  const labelId = `${id}-label`;
  const errorId = `${id}-error`;
  const normalizedValue = normalizeOtpDigits(value).slice(0, length);

  useEffect(() => {
    if (!autoFocus || disabled || success) {
      return;
    }

    inputRefs.current[Math.min(normalizedValue.length, length - 1)]?.focus();
  }, [autoFocus, disabled, length, normalizedValue.length, success]);

  const focusCell = (index: number) => {
    inputRefs.current[Math.max(0, Math.min(length - 1, index))]?.focus();
  };

  const applyDigits = (index: number, rawValue: string) => {
    const incomingDigits = normalizeOtpDigits(rawValue);
    if (!incomingDigits) {
      return;
    }

    const currentDigits = normalizedValue.split("");
    const startIndex = Math.min(index, currentDigits.length);

    incomingDigits
      .slice(0, length - startIndex)
      .split("")
      .forEach((digit, offset) => {
        currentDigits[startIndex + offset] = digit;
      });

    const nextValue = currentDigits.join("").slice(0, length);
    onChange(nextValue);
    focusCell(Math.min(startIndex + incomingDigits.length, length - 1));
  };

  const removeDigit = (index: number) => {
    if (normalizedValue[index]) {
      const nextDigits = normalizedValue.split("");
      nextDigits.splice(index, 1);
      onChange(nextDigits.join(""));
      focusCell(index);
      return;
    }

    if (index > 0) {
      const nextDigits = normalizedValue.split("");
      nextDigits.splice(index - 1, 1);
      onChange(nextDigits.join(""));
      focusCell(index - 1);
    }
  };

  const handleKeyDown = (event: KeyboardEvent<HTMLInputElement>, index: number) => {
    if (event.key === "Backspace") {
      event.preventDefault();
      removeDigit(index);
      return;
    }

    if (event.key === "Delete") {
      event.preventDefault();
      if (normalizedValue[index]) {
        const nextDigits = normalizedValue.split("");
        nextDigits.splice(index, 1);
        onChange(nextDigits.join(""));
      }
      return;
    }

    if (event.key === "ArrowLeft") {
      event.preventDefault();
      focusCell(index - 1);
    } else if (event.key === "ArrowRight") {
      event.preventDefault();
      focusCell(index + 1);
    } else if (event.key === "Home") {
      event.preventDefault();
      focusCell(0);
    } else if (event.key === "End") {
      event.preventDefault();
      focusCell(length - 1);
    }
  };

  const handlePaste = (event: ClipboardEvent<HTMLInputElement>, index: number) => {
    const pastedDigits = normalizeOtpDigits(event.clipboardData.getData("text"));
    if (!pastedDigits) {
      return;
    }

    event.preventDefault();
    applyDigits(index, pastedDigits);
  };

  return (
    <div className="field">
      <div className="flex min-h-6 items-center justify-between gap-3">
        <span id={labelId} className="text-sm font-semibold text-ink-800">
          {label}
        </span>
        {success && (
          <span className="otp-success-label" role="status" aria-live="polite">
            <span className="otp-success-icon">
              <Check aria-hidden="true" size={12} strokeWidth={3} />
            </span>
            {t("auth.common.otp.verified")}
          </span>
        )}
      </div>

      <div
        className={[
          "otp-input-row",
          error && "otp-input-row-invalid",
          success && "otp-input-row-success",
          error && "otp-input-shake",
        ]
          .filter(Boolean)
          .join(" ")}
        role="group"
        aria-labelledby={labelId}
        aria-describedby={error ? errorId : undefined}
        dir="ltr"
      >
        {Array.from({ length }, (_, index) => (
          <input
            key={index}
            ref={(element) => {
              inputRefs.current[index] = element;
            }}
            className="otp-input-cell"
            type="text"
            inputMode="numeric"
            pattern="[0-9]*"
            autoComplete={index === 0 ? "one-time-code" : "off"}
            autoCapitalize="none"
            spellCheck={false}
            maxLength={length}
            value={normalizedValue[index] ?? ""}
            disabled={disabled || success}
            aria-label={t("auth.common.otp.digitLabel", {
              position: index + 1,
              total: length,
            })}
            aria-invalid={error ? true : undefined}
            onChange={(event) => applyDigits(index, event.target.value)}
            onFocus={(event) => event.currentTarget.select()}
            onKeyDown={(event) => handleKeyDown(event, index)}
            onPaste={(event) => handlePaste(event, index)}
          />
        ))}
      </div>

      {error && (
        <p id={errorId} className="field-error" role="alert">
          {error}
        </p>
      )}
    </div>
  );
}
