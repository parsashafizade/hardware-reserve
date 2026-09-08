import {
  CalendarClock,
  CheckCircle2,
  CircleDollarSign,
  Headphones,
  Megaphone,
  Ban,
  PlayCircle,
  TimerOff,
  type LucideIcon,
} from "lucide-react";
import { useTranslation } from "react-i18next";
import type { UserNotification, UserNotificationType } from "../../types/notifications";
import { isolateBidiText } from "../../utils/format";
import { formatSupportRelativeTime } from "../../utils/support";

const icons: Record<UserNotificationType, LucideIcon> = {
  ReservationCreated: CalendarClock,
  PaymentConfirmed: CircleDollarSign,
  ReservationStartsSoon: CalendarClock,
  ReservationStarted: PlayCircle,
  ReservationEndsSoon: TimerOff,
  ReservationCompleted: CheckCircle2,
  ServiceDetailsAssigned: CheckCircle2,
  SupportReply: Headphones,
  AdminMessage: Megaphone,
  ReservationCancelled: Ban,
};

const tones: Record<UserNotificationType, string> = {
  ReservationCreated: "border-brand-100 bg-brand-50 text-brand-700",
  PaymentConfirmed: "border-emerald-100 bg-emerald-50 text-emerald-700",
  ReservationStartsSoon: "border-amber-100 bg-amber-50 text-amber-700",
  ReservationStarted: "border-emerald-100 bg-emerald-50 text-emerald-700",
  ReservationEndsSoon: "border-amber-100 bg-amber-50 text-amber-700",
  ReservationCompleted: "border-border-subtle bg-surface-muted text-ink-600",
  ServiceDetailsAssigned: "border-emerald-100 bg-emerald-50 text-emerald-700",
  SupportReply: "border-blue-100 bg-blue-50 text-blue-700",
  AdminMessage: "border-cyan-100 bg-cyan-50 text-cyan-700",
  ReservationCancelled: "border-rose-100 bg-rose-50 text-rose-700",
};

interface NotificationItemProps {
  notification: UserNotification;
  onOpen: (notification: UserNotification) => void;
  compact?: boolean;
  currentTime?: number;
}

export function NotificationItem({ notification, onOpen, compact = false, currentTime }: NotificationItemProps) {
  const { t } = useTranslation();
  const Icon = icons[notification.type] ?? CalendarClock;
  const fallback = notification.type === "SupportReply"
    ? t("notifications.items.supportFallback")
    : t("notifications.items.fallbackResource");
  const resource = isolateBidiText(notification.resourceLabel?.trim() || fallback);
  const hasTarget = Boolean(notification.reservationId || notification.supportConversationId);
  const fallbackTitle = notification.title?.trim()
    || t("notifications.items.generic", { name: resource });
  const localizedTitle = notification.type === "AdminMessage" && notification.title
    ? notification.title
    : t(`notifications.items.${notification.type}`, {
        name: resource,
        defaultValue: fallbackTitle,
      });

  return (
    <button
      type="button"
      onClick={() => onOpen(notification)}
      className={`group relative flex w-full min-w-0 items-start gap-3 text-start transition duration-base hover:bg-brand-50/50 focus-visible:bg-brand-50/60 ${compact ? "px-4 py-3" : "rounded-card border border-border-subtle bg-white p-4 shadow-none hover:border-brand-200 hover:shadow-card sm:p-5"}`}
    >
      {!notification.readAt && (
        <span aria-hidden="true" className="absolute start-1.5 top-1/2 size-1.5 -translate-y-1/2 rounded-full bg-brand-600" />
      )}
      <span className={`mt-0.5 inline-flex size-9 shrink-0 items-center justify-center rounded-control border ${tones[notification.type] ?? "border-border-subtle bg-surface-muted text-ink-600"}`}>
        <Icon aria-hidden="true" size={17} />
      </span>
      <span className="min-w-0 flex-1">
        <span dir="auto" className={`support-bidi block text-sm leading-5 text-ink-900 ${notification.readAt ? "font-medium" : "font-semibold"}`}>
          {localizedTitle}
        </span>
        {notification.type === "AdminMessage" && notification.message && (
          <span dir="auto" className="support-bidi mt-1 block line-clamp-2 font-reading text-xs leading-5 text-ink-600">
            {notification.message}
          </span>
        )}
        <span className="mt-1 flex flex-wrap items-center justify-between gap-2 text-xs text-ink-500">
          <time dateTime={notification.createdAt}>{formatSupportRelativeTime(notification.createdAt, currentTime)}</time>
          {hasTarget && <span className="font-semibold text-brand-700 group-hover:text-brand-800">{notification.supportConversationId ? t("notifications.openSupport") : t("notifications.openReservation")}</span>}
        </span>
      </span>
    </button>
  );
}
