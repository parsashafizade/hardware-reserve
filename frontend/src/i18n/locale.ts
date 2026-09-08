export const SUPPORTED_LOCALES = ["fa", "en"] as const;

export type AppLocale = (typeof SUPPORTED_LOCALES)[number];
export type AppDirection = "rtl" | "ltr";

export const DEFAULT_LOCALE: AppLocale = "fa";
export const LOCALE_STORAGE_KEY = "hardwarereserve.locale";

const localeMetadata: Record<AppLocale, { direction: AppDirection; intlLocale: string }> = {
  fa: { direction: "rtl", intlLocale: "fa-IR" },
  en: { direction: "ltr", intlLocale: "en-US" },
};

export function normalizeLocale(value: string | null | undefined): AppLocale {
  const language = value?.toLowerCase().split("-")[0];
  return language === "en" ? "en" : DEFAULT_LOCALE;
}

export function getStoredLocale(): AppLocale {
  if (typeof window === "undefined") {
    return DEFAULT_LOCALE;
  }

  try {
    return normalizeLocale(window.localStorage.getItem(LOCALE_STORAGE_KEY));
  } catch {
    return DEFAULT_LOCALE;
  }
}

export function storeLocale(locale: AppLocale): void {
  try {
    window.localStorage.setItem(LOCALE_STORAGE_KEY, locale);
  } catch {
    // The selected locale still applies for this session when storage is unavailable.
  }
}

export function getLocaleDirection(locale: AppLocale): AppDirection {
  return localeMetadata[locale].direction;
}

export function getIntlLocale(locale: AppLocale): string {
  return localeMetadata[locale].intlLocale;
}
