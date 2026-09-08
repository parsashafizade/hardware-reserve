import { useCallback, useEffect, useLayoutEffect, useMemo, useState, type ReactNode } from "react";
import { useTranslation } from "react-i18next";
import {
  getIntlLocale,
  getLocaleDirection,
  normalizeLocale,
  storeLocale,
  type AppLocale,
} from "./locale";
import { LocaleContext, type LocaleContextValue } from "./LocaleContext";
import { formatTomanCurrency, isolateBidiText } from "../utils/format";
import { formatLocalizedDate } from "./dateTime";

export function LocaleProvider({ children }: { children: ReactNode }) {
  const { i18n } = useTranslation();
  const [locale, setLocaleState] = useState<AppLocale>(() => normalizeLocale(i18n.resolvedLanguage ?? i18n.language));

  useEffect(() => {
    const handleLanguageChanged = (nextLanguage: string) => {
      setLocaleState(normalizeLocale(nextLanguage));
    };

    i18n.on("languageChanged", handleLanguageChanged);
    return () => {
      i18n.off("languageChanged", handleLanguageChanged);
    };
  }, [i18n]);

  const direction = getLocaleDirection(locale);

  useLayoutEffect(() => {
    const root = document.documentElement;
    root.lang = locale;
    root.dir = direction;
    root.dataset.locale = locale;
    document.querySelector<HTMLMetaElement>('meta[name="description"]')
      ?.setAttribute("content", i18n.t("document.metaDescription"));
  }, [direction, i18n, locale]);

  const setLocale = useCallback(
    async (nextLocale: AppLocale) => {
      storeLocale(nextLocale);
      await i18n.changeLanguage(nextLocale);
    },
    [i18n],
  );

  const intlLocale = getIntlLocale(locale);
  const formatNumber = useCallback(
    (value: number, options?: Intl.NumberFormatOptions) => new Intl.NumberFormat(intlLocale, options).format(value),
    [intlLocale],
  );
  const formatDate = useCallback(
    (value: string | number | Date, options?: Intl.DateTimeFormatOptions) =>
      isolateBidiText(formatLocalizedDate(value, locale, options)),
    [locale],
  );
  const formatCurrency = useCallback(
    (value: number) => formatTomanCurrency(value, intlLocale, i18n.t("format.currency.toman")),
    [i18n, intlLocale],
  );

  const value = useMemo<LocaleContextValue>(
    () => ({ locale, direction, setLocale, formatNumber, formatDate, formatCurrency }),
    [direction, formatCurrency, formatDate, formatNumber, locale, setLocale],
  );

  return <LocaleContext.Provider value={value}>{children}</LocaleContext.Provider>;
}
