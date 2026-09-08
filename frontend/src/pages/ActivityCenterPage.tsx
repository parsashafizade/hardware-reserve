import { AlertCircle, Bell, CheckCheck, LoaderCircle, RotateCcw } from "lucide-react";
import { useMemo, useState } from "react";
import { useTranslation } from "react-i18next";
import { useNavigate } from "react-router-dom";
import { AccountNavigation } from "../components/account/AccountNavigation";
import { NotificationItem } from "../components/notifications/NotificationItem";
import { PageHeader } from "../components/ui/PageHeader";
import { useNotifications } from "../notifications/useNotifications";
import { useSupport } from "../support/useSupport";
import type { UserNotification } from "../types/notifications";
import { useCurrentTime } from "../hooks/useCurrentTime";
import { getActivityDateGroup, type ActivityDateGroup } from "../utils/activityDate";

export function ActivityCenterPage() {
  const { t } = useTranslation();
  const navigate = useNavigate();
  const { openConversation } = useSupport();
  const {
    notifications,
    unreadCount,
    loading,
    loadingMore,
    error,
    hasMore,
    refresh,
    loadMore,
    markRead,
    markAllRead,
  } = useNotifications();
  const [markingAll, setMarkingAll] = useState(false);
  const [actionError, setActionError] = useState("");
  const currentTime = useCurrentTime(60_000);

  const grouped = useMemo(() => {
    const result: Record<ActivityDateGroup, UserNotification[]> = {
      today: [],
      yesterday: [],
      earlier: [],
    };
    for (const notification of notifications) {
      result[getActivityDateGroup(notification.createdAt, currentTime)].push(notification);
    }
    return result;
  }, [currentTime, notifications]);

  const openNotification = async (notification: UserNotification) => {
    try {
      await markRead(notification.id);
    } catch {
      // The destination remains usable; HTTP reconciliation retries read state later.
    }
    if (notification.supportConversationId) {
      await openConversation(notification.supportConversationId);
    } else if (notification.reservationId) {
      navigate(`/my-reservations/${notification.reservationId}`);
    }
  };

  const markEverythingRead = async () => {
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

  return (
    <div className="page-stack">
      <AccountNavigation />
      <PageHeader
        eyebrow={t("notifications.eyebrow")}
        title={t("notifications.title")}
        description={t("notifications.description")}
        icon={Bell}
        actions={unreadCount > 0 ? (
          <button type="button" className="btn-secondary" onClick={() => void markEverythingRead()} disabled={markingAll}>
            {markingAll ? <LoaderCircle aria-hidden="true" className="animate-spin" size={17} /> : <CheckCheck aria-hidden="true" size={17} />}
            {markingAll ? t("notifications.markingAll") : t("notifications.markAll")}
          </button>
        ) : undefined}
      />

      {actionError && (
        <p role="alert" className="rounded-control border border-rose-200 bg-rose-50 px-4 py-3 text-sm text-rose-700">
          {actionError}
        </p>
      )}

      {error && notifications.length > 0 && (
        <div role="alert" className="flex flex-col gap-3 rounded-control border border-amber-200 bg-amber-50 px-4 py-3 text-sm text-amber-800 sm:flex-row sm:items-center sm:justify-between">
          <span>{error}</span>
          <button type="button" className="btn-ghost min-h-9 px-3 py-1.5 text-xs" onClick={() => void refresh()}>{t("notifications.retry")}</button>
        </div>
      )}

      {loading && notifications.length === 0 ? (
        <div className="space-y-4" role="status" aria-label={t("notifications.loading")}>
          {[0, 1, 2, 3].map((item) => <div key={item} className="skeleton h-24 rounded-card" />)}
        </div>
      ) : error && notifications.length === 0 ? (
        <div className="state-panel" role="alert">
          <span className="icon-tile-neutral"><AlertCircle aria-hidden="true" size={21} /></span>
          <h1 className="mt-4 card-title">{t("notifications.errors.load")}</h1>
          <button type="button" className="btn-primary mt-5" onClick={() => void refresh()}>
            <RotateCcw aria-hidden="true" size={16} />
            {t("notifications.retry")}
          </button>
        </div>
      ) : notifications.length === 0 ? (
        <div className="state-panel">
          <span className="icon-tile-neutral"><CheckCheck aria-hidden="true" size={21} /></span>
          <h1 className="mt-4 card-title">{t("notifications.empty")}</h1>
          <p className="mt-2 body-copy">{t("notifications.emptyCopy")}</p>
        </div>
      ) : (
        <div className="space-y-8">
          {(["today", "yesterday", "earlier"] as const).map((group) => grouped[group].length > 0 && (
            <section key={group} aria-labelledby={`activity-${group}`}>
              <h2 id={`activity-${group}`} className="mb-3 text-sm font-semibold text-ink-700">{t(`notifications.${group}`)}</h2>
              <div className="grid gap-3">
                {grouped[group].map((notification) => (
                  <NotificationItem key={notification.id} notification={notification} currentTime={currentTime} onOpen={(item) => void openNotification(item)} />
                ))}
              </div>
            </section>
          ))}

          {hasMore && (
            <div className="flex justify-center">
              <button type="button" className="btn-secondary" onClick={() => void loadMore()} disabled={loadingMore}>
                {loadingMore && <LoaderCircle aria-hidden="true" className="animate-spin" size={17} />}
                {loadingMore ? t("notifications.loadingMore") : t("notifications.loadMore")}
              </button>
            </div>
          )}
        </div>
      )}
    </div>
  );
}
