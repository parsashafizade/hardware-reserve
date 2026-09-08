import type { SupportConversationStatus, SupportMessage, SupportParticipantType } from "../types/support";
import i18n, { getCurrentIntlLocale, getCurrentLocale } from "../i18n/config";
import { formatLocalizedDate } from "../i18n/dateTime";
import { isolateBidiText } from "./format";

export const SUPPORT_CATEGORIES = [
  "General support",
  "Hardware selection",
  "Reservations",
  "Payments",
  "Provisioning",
  "Account",
] as const;

const categoryTranslationKeys: Record<(typeof SUPPORT_CATEGORIES)[number], string> = {
  "General support": "support.category.general",
  "Hardware selection": "support.category.hardware",
  Reservations: "support.category.reservations",
  Payments: "support.category.payments",
  Provisioning: "support.category.provisioning",
  Account: "support.category.account",
};

export function getSupportCategoryLabel(category: string): string {
  const translationKey = categoryTranslationKeys[category as (typeof SUPPORT_CATEGORIES)[number]];
  return translationKey ? i18n.t(translationKey) : category;
}

export function formatSupportDateTime(value: string): string {
  return isolateBidiText(formatLocalizedDate(value, getCurrentLocale(), {
    dateStyle: "medium",
    timeStyle: "short",
  }));
}

export function formatSupportTime(value: string): string {
  return isolateBidiText(formatLocalizedDate(value, getCurrentLocale(), {
    hour: "numeric",
    minute: "2-digit",
  }));
}

export function formatSupportRelativeTime(value: string, nowMilliseconds = Date.now()): string {
  const differenceSeconds = Math.round((new Date(value).getTime() - nowMilliseconds) / 1_000);
  const absoluteSeconds = Math.abs(differenceSeconds);
  const formatter = new Intl.RelativeTimeFormat(getCurrentIntlLocale(), { numeric: "auto" });

  if (absoluteSeconds < 60) {
    return formatter.format(differenceSeconds, "second");
  }
  if (absoluteSeconds < 3_600) {
    return formatter.format(Math.round(differenceSeconds / 60), "minute");
  }
  if (absoluteSeconds < 86_400) {
    return formatter.format(Math.round(differenceSeconds / 3_600), "hour");
  }
  if (absoluteSeconds < 604_800) {
    return formatter.format(Math.round(differenceSeconds / 86_400), "day");
  }

  return formatSupportDateTime(value);
}

export function getSupportStatusLabel(status: SupportConversationStatus): string {
  const labels: Record<SupportConversationStatus, string> = {
    AI_ACTIVE: i18n.t("support.status.aiActive"),
    WAITING_FOR_ADMIN: i18n.t("support.status.waitingForAdmin"),
    ADMIN_ACTIVE: i18n.t("support.status.adminActive"),
    RESOLVED: i18n.t("support.status.resolved"),
    CLOSED: i18n.t("support.status.closed"),
  };
  return labels[status];
}

export function getSupportSenderLabel(senderType: SupportParticipantType): string {
  if (senderType === "AI") {
    return i18n.t("support.sender.ai");
  }
  if (senderType === "ADMIN") {
    return i18n.t("support.sender.admin");
  }
  return i18n.t("support.sender.user");
}

export function mergeSupportMessages(current: SupportMessage[], incoming: SupportMessage[]): SupportMessage[] {
  const byId = new Map<string, SupportMessage>();
  for (const message of [...current, ...incoming]) {
    byId.set(message.id, message);
  }

  return [...byId.values()].sort((left, right) => {
    if (left.sequenceNumber !== right.sequenceNumber) {
      return left.sequenceNumber - right.sequenceNumber;
    }
    return new Date(left.createdAt).getTime() - new Date(right.createdAt).getTime();
  });
}
