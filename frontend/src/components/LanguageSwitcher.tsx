import { Check, ChevronDown, Globe2 } from "lucide-react";
import { useEffect, useRef, useState } from "react";
import { useTranslation } from "react-i18next";
import { SUPPORTED_LOCALES, type AppLocale } from "../i18n/locale";
import { useLocale } from "../i18n/useLocale";

const languageNames: Record<AppLocale, { short: string; translationKey: "language.persian" | "language.english" }> = {
  fa: { short: "فا", translationKey: "language.persian" },
  en: { short: "EN", translationKey: "language.english" },
};

export function LanguageSwitcher() {
  const { t } = useTranslation();
  const { locale, setLocale } = useLocale();
  const [open, setOpen] = useState(false);
  const containerRef = useRef<HTMLDivElement>(null);
  const triggerRef = useRef<HTMLButtonElement>(null);
  const optionRefs = useRef<Partial<Record<AppLocale, HTMLButtonElement | null>>>({});

  useEffect(() => {
    if (!open) {
      return;
    }

    optionRefs.current[locale]?.focus();

    const handlePointerDown = (event: PointerEvent) => {
      if (!containerRef.current?.contains(event.target as Node)) {
        setOpen(false);
      }
    };
    const handleEscape = (event: KeyboardEvent) => {
      if (event.key === "Escape") {
        setOpen(false);
        triggerRef.current?.focus();
      }
    };

    document.addEventListener("pointerdown", handlePointerDown);
    document.addEventListener("keydown", handleEscape);
    return () => {
      document.removeEventListener("pointerdown", handlePointerDown);
      document.removeEventListener("keydown", handleEscape);
    };
  }, [locale, open]);

  const selectLocale = async (nextLocale: AppLocale) => {
    await setLocale(nextLocale);
    setOpen(false);
    triggerRef.current?.focus();
  };

  const moveFocus = (event: React.KeyboardEvent<HTMLDivElement>) => {
    if (event.key === "Tab") {
      setOpen(false);
      return;
    }
    if (event.key === "Home" || event.key === "End") {
      event.preventDefault();
      const target = event.key === "Home" ? SUPPORTED_LOCALES[0] : SUPPORTED_LOCALES.at(-1);
      if (target) {
        optionRefs.current[target]?.focus();
      }
      return;
    }
    if (event.key !== "ArrowDown" && event.key !== "ArrowUp") {
      return;
    }

    event.preventDefault();
    const currentIndex = SUPPORTED_LOCALES.findIndex(
      (candidate) => optionRefs.current[candidate] === document.activeElement,
    );
    const delta = event.key === "ArrowDown" ? 1 : -1;
    const nextIndex = (Math.max(currentIndex, 0) + delta + SUPPORTED_LOCALES.length) % SUPPORTED_LOCALES.length;
    optionRefs.current[SUPPORTED_LOCALES[nextIndex]]?.focus();
  };

  const currentLanguageName = t(languageNames[locale].translationKey);

  return (
    <div ref={containerRef} className="relative">
      <button
        ref={triggerRef}
        type="button"
        className="control-press inline-flex min-h-11 items-center gap-2 rounded-control border border-border-subtle bg-white px-3 text-sm font-semibold text-ink-700 transition duration-base hover:border-brand-200 hover:bg-brand-50 hover:text-brand-800"
        aria-label={t("language.current", { language: currentLanguageName })}
        aria-haspopup="menu"
        aria-expanded={open}
        onClick={() => setOpen((current) => !current)}
      >
        <Globe2 aria-hidden="true" size={17} />
        <span lang={locale} dir={locale === "fa" ? "rtl" : "ltr"} className={locale === "en" ? "font-latin" : "font-display"}>
          {languageNames[locale].short}
        </span>
        <ChevronDown
          aria-hidden="true"
          size={14}
          className={`text-ink-400 transition-transform duration-fast ${open ? "rotate-180" : ""}`}
        />
      </button>

      {open && (
        <div
          role="menu"
          aria-label={t("language.change")}
          className="menu-panel-enter absolute end-0 top-full z-[90] mt-2 w-48 rounded-card border border-border-subtle bg-white p-1.5 shadow-floating"
          onKeyDown={moveFocus}
        >
          {SUPPORTED_LOCALES.map((option) => {
            const selected = locale === option;
            return (
              <button
                key={option}
                ref={(element) => {
                  optionRefs.current[option] = element;
                }}
                type="button"
                role="menuitemradio"
                aria-checked={selected}
                lang={option}
                dir={option === "fa" ? "rtl" : "ltr"}
                className={`control-press flex min-h-11 w-full items-center justify-between gap-3 rounded-control px-3 text-sm transition duration-fast ${
                  selected
                    ? "bg-brand-50 font-semibold text-brand-800"
                    : "text-ink-700 hover:bg-surface-muted hover:text-ink-950"
                }`}
                onClick={() => void selectLocale(option)}
              >
                <span className={option === "en" ? "font-latin" : "font-display"}>
                  {t(languageNames[option].translationKey)}
                </span>
                {selected && <Check aria-hidden="true" size={16} className="text-brand-600" />}
              </button>
            );
          })}
        </div>
      )}
    </div>
  );
}
