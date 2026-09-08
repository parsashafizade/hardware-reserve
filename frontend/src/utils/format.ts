import i18n, { getCurrentIntlLocale, getCurrentLocale } from "../i18n/config";
import { formatLocalizedDate } from "../i18n/dateTime";

export function isolateBidiText(value: string): string {
  return `\u2068${value}\u2069`;
}

export function formatTomanCurrency(value: number, intlLocale: string, currencyLabel: string): string {
  const amount = new Intl.NumberFormat(intlLocale, {
    maximumFractionDigits: 0,
  }).format(Math.round(value));

  // Isolate mixed-script prices so surrounding RTL/LTR text cannot reorder the amount or unit.
  return isolateBidiText(`${amount}\u00a0${currencyLabel}`);
}

export function formatCurrency(value: number): string {
  return formatTomanCurrency(value, getCurrentIntlLocale(), i18n.t("format.currency.toman"));
}

export function formatDateTime(value: string | Date): string {
  return isolateBidiText(formatLocalizedDate(value, getCurrentLocale(), {
    dateStyle: "medium",
    timeStyle: "short",
  }));
}

export function formatDuration(startValue: string | Date, endValue: string | Date): string {
  const start = typeof startValue === "string" ? new Date(startValue) : startValue;
  const end = typeof endValue === "string" ? new Date(endValue) : endValue;
  const durationHours = Math.max(0, (end.getTime() - start.getTime()) / 3_600_000);

  if (durationHours < 24) {
    const roundedHours = Math.round(durationHours * 100) / 100;
    return i18n.t("format.duration.hours", {
      count: roundedHours,
      formattedCount: new Intl.NumberFormat(getCurrentIntlLocale(), { maximumFractionDigits: 2 }).format(roundedHours),
    });
  }

  const days = Math.floor(durationHours / 24);
  const remainingHours = Math.round((durationHours - days * 24) * 100) / 100;

  const formattedDays = i18n.t("format.duration.days", {
    count: days,
    formattedCount: new Intl.NumberFormat(getCurrentIntlLocale()).format(days),
  });

  if (remainingHours === 0) {
    return formattedDays;
  }

  const formattedHours = i18n.t("format.duration.hours", {
    count: remainingHours,
    formattedCount: new Intl.NumberFormat(getCurrentIntlLocale(), { maximumFractionDigits: 2 }).format(remainingHours),
  });
  return i18n.t("format.duration.combined", { days: formattedDays, hours: formattedHours });
}

export function toUtcIsoString(localDateTime: string): string {
  return new Date(localDateTime).toISOString();
}
