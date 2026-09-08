import { useCallback, useEffect, useMemo, useRef, useState, type ReactNode } from "react";
import { notificationsApi } from "../api/notificationsApi";
import { useAuth } from "../auth/useAuth";
import i18n from "../i18n/config";
import { useSupportRealtime } from "../support/useSupportRealtime";
import type { UserNotification } from "../types/notifications";
import { getApiErrorMessage } from "../utils/errors";
import { NotificationContext, type NotificationContextValue } from "./NotificationContextDefinition";

function mergeNotifications(
  current: UserNotification[],
  incoming: UserNotification[],
): UserNotification[] {
  const byId = new Map<string, UserNotification>();
  for (const notification of [...current, ...incoming]) {
    byId.set(notification.id, notification);
  }
  return [...byId.values()].sort(
    (left, right) => new Date(right.createdAt).getTime() - new Date(left.createdAt).getTime(),
  );
}

export function NotificationProvider({ children }: { children: ReactNode }) {
  const { isAuthenticated, session } = useAuth();
  const { state: realtimeState, userNotification, notificationReadState } = useSupportRealtime();
  const [notifications, setNotifications] = useState<UserNotification[]>([]);
  const [unreadCount, setUnreadCount] = useState(0);
  const [loading, setLoading] = useState(false);
  const [loadingMore, setLoadingMore] = useState(false);
  const [error, setError] = useState("");
  const [hasMore, setHasMore] = useState(false);
  const cursorRef = useRef<string | null>(null);
  const identityRef = useRef(session?.user.id);
  const knownNotificationIdsRef = useRef(new Set<string>());
  const requestIdRef = useRef(0);

  const refresh = useCallback(async () => {
    if (!isAuthenticated) {
      return;
    }
    const requestId = ++requestIdRef.current;
    const userId = session?.user.id;
    setLoading(true);
    setLoadingMore(false);
    setError("");
    try {
      const [page, unread] = await Promise.all([
        notificationsApi.getNotifications(undefined, 20),
        notificationsApi.getUnreadCount(),
      ]);
      if (identityRef.current !== userId || requestId !== requestIdRef.current) {
        return;
      }
      for (const notification of page.items) {
        knownNotificationIdsRef.current.add(notification.id);
      }
      setNotifications((current) => mergeNotifications(current, page.items));
      setUnreadCount(unread.unreadCount);
      setHasMore(page.hasMore);
      cursorRef.current = page.nextCursor ?? null;
    } catch (requestError) {
      if (identityRef.current === userId && requestId === requestIdRef.current) {
        setError(getApiErrorMessage(requestError, i18n.t("notifications.errors.load")));
      }
    } finally {
      if (identityRef.current === userId && requestId === requestIdRef.current) {
        setLoading(false);
      }
    }
  }, [isAuthenticated, session?.user.id]);

  const loadMore = useCallback(async () => {
    if (!isAuthenticated || loading || loadingMore || !cursorRef.current) {
      return;
    }
    const requestId = ++requestIdRef.current;
    const userId = session?.user.id;
    setLoadingMore(true);
    setError("");
    try {
      const page = await notificationsApi.getNotifications(cursorRef.current, 20);
      if (identityRef.current !== userId || requestId !== requestIdRef.current) {
        return;
      }
      for (const notification of page.items) {
        knownNotificationIdsRef.current.add(notification.id);
      }
      setNotifications((current) => mergeNotifications(current, page.items));
      setHasMore(page.hasMore);
      cursorRef.current = page.nextCursor ?? null;
    } catch (requestError) {
      if (identityRef.current === userId && requestId === requestIdRef.current) {
        setError(getApiErrorMessage(requestError, i18n.t("notifications.errors.load")));
      }
    } finally {
      if (identityRef.current === userId && requestId === requestIdRef.current) {
        setLoadingMore(false);
      }
    }
  }, [isAuthenticated, loading, loadingMore, session?.user.id]);

  const markRead = useCallback(async (notificationId: string) => {
    const current = notifications.find((notification) => notification.id === notificationId);
    if (!current || current.readAt) {
      return;
    }
    const updated = await notificationsApi.markRead(notificationId);
    setNotifications((items) => items.map((item) => item.id === updated.id ? updated : item));
    setUnreadCount((count) => Math.max(0, count - 1));
  }, [notifications]);

  const markAllRead = useCallback(async () => {
    await notificationsApi.markAllRead();
    const readAt = new Date().toISOString();
    setNotifications((items) => items.map((item) => item.readAt ? item : { ...item, readAt }));
    setUnreadCount(0);
  }, []);

  useEffect(() => {
    requestIdRef.current += 1;
    identityRef.current = session?.user.id;
    cursorRef.current = null;
    knownNotificationIdsRef.current.clear();
    setNotifications([]);
    setUnreadCount(0);
    setHasMore(false);
    setLoading(false);
    setLoadingMore(false);
    setError("");
    if (isAuthenticated) {
      void refresh();
    }
  }, [isAuthenticated, refresh, session?.user.id]);

  useEffect(() => {
    if (!isAuthenticated || !userNotification) {
      return;
    }
    const userId = session?.user.id;
    const alreadyKnown = knownNotificationIdsRef.current.has(userNotification.id);
    knownNotificationIdsRef.current.add(userNotification.id);
    setNotifications((current) => mergeNotifications(current, [userNotification]));
    if (!alreadyKnown && !userNotification.readAt) {
      setUnreadCount((count) => count + 1);
    }
    void notificationsApi.getUnreadCount()
      .then((result) => {
        if (identityRef.current === userId) {
          setUnreadCount(result.unreadCount);
        }
      })
      .catch(() => {
        // The realtime item remains visible; the next HTTP reconciliation corrects the badge.
      });
  }, [isAuthenticated, session?.user.id, userNotification]);

  useEffect(() => {
    if (!isAuthenticated || !notificationReadState) {
      return;
    }
    setUnreadCount(notificationReadState.unreadCount);
    setNotifications((current) => current.map((item) => {
      if (notificationReadState.notificationId) {
        return item.id === notificationReadState.notificationId
          ? { ...item, readAt: item.readAt ?? notificationReadState.occurredAt }
          : item;
      }
      return notificationReadState.unreadCount === 0 && !item.readAt
        ? { ...item, readAt: notificationReadState.occurredAt }
        : item;
    }));
  }, [isAuthenticated, notificationReadState]);

  useEffect(() => {
    if (!isAuthenticated) {
      return;
    }
    const delay = realtimeState === "connected" ? 60_000 : 15_000;
    const interval = window.setInterval(() => {
      if (!document.hidden) {
        void refresh();
      }
    }, delay);
    const onVisibility = () => {
      if (!document.hidden) {
        void refresh();
      }
    };
    document.addEventListener("visibilitychange", onVisibility);
    return () => {
      window.clearInterval(interval);
      document.removeEventListener("visibilitychange", onVisibility);
    };
  }, [isAuthenticated, realtimeState, refresh]);

  const value = useMemo<NotificationContextValue>(() => ({
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
  }), [
    error,
    hasMore,
    loadMore,
    loading,
    loadingMore,
    markAllRead,
    markRead,
    notifications,
    refresh,
    unreadCount,
  ]);

  return <NotificationContext.Provider value={value}>{children}</NotificationContext.Provider>;
}
