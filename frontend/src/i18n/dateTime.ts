import { getIntlLocale, type AppLocale } from "./locale";

export const IRAN_TIME_ZONE = "Asia/Tehran";

export function formatLocalizedDate(
  value: string | number | Date,
  locale: AppLocale,
  options?: Intl.DateTimeFormatOptions,
): string {
  const calendar = locale === "fa" ? "persian" : "gregory";
  return new Intl.DateTimeFormat(getIntlLocale(locale), {
    ...options,
    calendar,
  }).format(new Date(value));
}
