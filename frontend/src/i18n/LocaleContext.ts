import { createContext } from "react";
import type { AppDirection, AppLocale } from "./locale";

export interface LocaleContextValue {
  locale: AppLocale;
  direction: AppDirection;
  setLocale: (locale: AppLocale) => Promise<void>;
  formatNumber: (value: number, options?: Intl.NumberFormatOptions) => string;
  formatDate: (value: string | number | Date, options?: Intl.DateTimeFormatOptions) => string;
  formatCurrency: (value: number) => string;
}

export const LocaleContext = createContext<LocaleContextValue | null>(null);
