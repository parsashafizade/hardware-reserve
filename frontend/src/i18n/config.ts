import i18n from "i18next";
import { initReactI18next } from "react-i18next";
import { getStoredLocale, getIntlLocale, normalizeLocale, type AppLocale } from "./locale";
import { resources } from "./resources";

void i18n.use(initReactI18next).init({
  resources,
  lng: getStoredLocale(),
  fallbackLng: "fa",
  supportedLngs: ["fa", "en"],
  defaultNS: "translation",
  interpolation: {
    escapeValue: false,
  },
  react: {
    useSuspense: false,
  },
});

export function getCurrentLocale(): AppLocale {
  return normalizeLocale(i18n.resolvedLanguage ?? i18n.language);
}

export function getCurrentIntlLocale(): string {
  return getIntlLocale(getCurrentLocale());
}

export default i18n;
