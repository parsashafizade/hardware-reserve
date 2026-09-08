import { Bell, CheckCheck, LoaderCircle } from "lucide-react";
import { useEffect, useRef, useState } from "react";
import { useTranslation } from "react-i18next";
import { Link, useNavigate } from "react-router-dom";
import { useLocale } from "../../i18n/useLocale";
import { useNotifications } from "../../notifications/useNotifications";
import { useSupport } from "../../support/useSupport";
import type { UserNotification } from "../../types/notifications";
import { NotificationItem } from "./NotificationItem";
import { useCurrentTime } from "../../hooks/useCurrentTime";

export function NotificationBell() {
  const { t } = useTranslation();
  const { formatNumber } = useLocale();
  const navigate = useNavigate();
  const { openConversation } = useSupport();
  const {
    notifications,
    unreadCount,
    loading,
    error,
    refresh,
    markRead,
    markAllRead,
  } = useNotifications();
  const [open, setOpen] = useState(false);
  const [markingAll, setMarkingAll] = useState(false);
  const [actionError, setActionError] = useState("");
  const containerRef = useRef<HTMLDivElement>(null);
  const currentTime = useCurrentTime(60_000);

  useEffect(() => {
    if (!open) {
      return;
    }
    const close = (event: MouseEvent) => {
      if (!containerRef.current?.contains(event.target as Node)) {
        setOpen(false);
      }
    };
    const closeWithKeyboard = (event: KeyboardEvent) => {
      if (event.key === "Escape") {
        setOpen(false);
      }
    };
    document.addEventListener("mousedown", close);
    window.addEventListener("keydown", closeWithKeyboard);
    return () => {
      document.removeEventListener("mousedown", close);
      window.removeEventListener("keydown", closeWithKeyboard);
    };
  }, [open]);

  const openNotification = async (notification: UserNotification) => {
    setOpen(false);
    try {
      await markRead(notification.id);
    } catch {
      // Navigation remains available; persisted state is reconciled on the next refresh.
    }
    if (notification.supportConversationId) {
      await openConversation(notification.supportConversationId);
      return;
    }
    if (notification.reservationId) {
      navigate(`/my-reservations/${notification.reservationId}`);
    }
  };

  const markEverythingRead = async () => {
    if (markingAll || unreadCount === 0) {
      return;
    }
    setActionError("");
    setMarkingAll(true);
    try {
      await markAllRead();
    } catch {
      setActionError(t("notifications.errors.update"));
    } finally {
      setMarkingAll(false);
    }
  };

  const badge = unreadCount > 99 ? "99+" : formatNumber(unreadCount, { useGrouping: false });

  return (
    <div ref={containerRef} className="relative">
      <button
        type="button"
        className="btn-icon relative"
        aria-label={unreadCount > 0 ? t("notifications.unreadCount", { count: unreadCount }) : t("notifications.openBell")}
        aria-expanded={open}
        aria-haspopup="dialog"
        onClick={() => setOpen((current) => !current)}
      >
        <Bell aria-hidden="true" size={19} />
        {unreadCount > 0 && (
          <span className="notification-badge" aria-hidden="true">{badge}</span>
        )}
      </button>

      {open && (
        <section
          role="dialog"
          aria-label={t("notifications.recent")}
          className="dialog-panel-enter absolute end-0 top-[calc(100%+0.75rem)] z-[90] w-[min(23rem,calc(100vw-1.5rem))] overflow-hidden rounded-card border border-border-subtle bg-white shadow-floating"
        >
          <header className="flex items-center justify-between gap-3 border-b border-border-subtle bg-surface-raised px-4 py-3">
            <div>
              <h2 className="text-sm font-semibold text-ink-950">{t("notifications.recent")}</h2>
              {unreadCount > 0 && <p className="mt-0.5 text-[11px] text-ink-500">{t("notifications.unreadCount", { count: unreadCount })}</p>}
            </div>
            {unreadCount > 0 && (
              <button type="button" className="inline-flex min-h-9 items-center gap-1.5 text-xs font-semibold text-brand-700 hover:text-brand-900" onClick={() => void markEverythingRead()} disabled={markingAll}>
                {markingAll ? <LoaderCircle aria-hidden="true" className="animate-spin" size={14} /> : <CheckCheck aria-hidden="true" size={14} />}
                {markingAll ? t("notifications.markingAll") : t("notifications.markAll")}
              </button>
            )}
          </header>

          {(actionError || (error && notifications.length > 0)) && (
            <p role="alert" className="border-b border-rose-200 bg-rose-50 px-4 py-2 text-xs text-rose-700">
              {actionError || error}
            </p>
          )}

          <div className="max-h-[26rem] overflow-y-auto overscroll-contain">
            {loading && notifications.length === 0 ? (
              <div className="space-y-3 p-4" role="status" aria-label={t("notifications.loading")}>
                {[0, 1, 2].map((item) => <div key={item} className="skeleton h-16" />)}
              </div>
            ) : error && notifications.length === 0 ? (
              <div className="p-5 text-center">
                <p className="text-sm text-ink-600">{error}</p>
                <button type="button" className="btn-secondary mt-3 min-h-9 px-3 py-1.5 text-xs" onClick={() => void refresh()}>{t("notifications.retry")}</button>
              </div>
            ) : notifications.length === 0 ? (
              <div className="p-7 text-center">
                <span className="icon-tile-neutral mx-auto"><CheckCheck aria-hidden="true" size={19} /></span>
                <p className="mt-3 text-sm font-semibold text-ink-900">{t("notifications.empty")}</p>
                <p className="mt-1 text-xs text-ink-500">{t("notifications.emptyCopy")}</p>
              </div>
            ) : (
              <div className="divide-y divide-border-subtle">
                {notifications.slice(0, 6).map((notification) => (
                  <NotificationItem key={notification.id} notification={notification} currentTime={currentTime} onOpen={(item) => void openNotification(item)} compact />
                ))}
              </div>
            )}
          </div>

          <footer className="border-t border-border-subtle bg-surface-raised p-2">
            <Link to="/activity" className="btn-ghost w-full min-h-10 text-sm" onClick={() => setOpen(false)}>
              {t("notifications.viewAll")}
            </Link>
          </footer>
        </section>
      )}
    </div>
  );
}
