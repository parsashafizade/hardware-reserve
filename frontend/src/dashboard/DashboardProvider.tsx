import { useCallback, useEffect, useMemo, useRef, useState, type ReactNode } from "react";
import { dashboardApi } from "../api/dashboardApi";
import { useAuth } from "../auth/useAuth";
import i18n from "../i18n/config";
import { useSupportRealtime } from "../support/useSupportRealtime";
import type { DashboardSummary } from "../types/dashboard";
import { getApiErrorMessage } from "../utils/errors";
import { DashboardContext, type DashboardContextValue } from "./DashboardContextDefinition";

const reservationNotificationTypes = new Set([
  "ReservationCreated",
  "PaymentConfirmed",
  "ReservationStartsSoon",
  "ReservationStarted",
  "ReservationEndsSoon",
  "ReservationCompleted",
  "ServiceDetailsAssigned",
]);

export function DashboardProvider({ children }: { children: ReactNode }) {
  const { isAuthenticated, isAdmin, session } = useAuth();
  const { userNotification } = useSupportRealtime();
  const [summary, setSummary] = useState<DashboardSummary | null>(null);
  const [loading, setLoading] = useState(false);
  const [refreshing, setRefreshing] = useState(false);
  const [error, setError] = useState("");
  const [clockOffsetMilliseconds, setClockOffsetMilliseconds] = useState(0);
  const requestIdRef = useRef(0);
  const summaryRef = useRef<DashboardSummary | null>(null);

  const refresh = useCallback(async () => {
    if (!isAuthenticated || isAdmin) {
      return;
    }
    const requestId = ++requestIdRef.current;
    setError("");
    if (summaryRef.current) {
      setRefreshing(true);
    } else {
      setLoading(true);
    }
    try {
      const response = await dashboardApi.getSummary();
      if (requestId === requestIdRef.current) {
        summaryRef.current = response;
        setClockOffsetMilliseconds(new Date(response.serverTimeUtc).getTime() - Date.now());
        setSummary(response);
      }
    } catch (requestError) {
      if (requestId === requestIdRef.current) {
        setError(getApiErrorMessage(requestError, i18n.t("personalizedHome.loadError")));
      }
    } finally {
      if (requestId === requestIdRef.current) {
        setLoading(false);
        setRefreshing(false);
      }
    }
  }, [isAdmin, isAuthenticated]);

  useEffect(() => {
    requestIdRef.current += 1;
    summaryRef.current = null;
    setSummary(null);
    setError("");
    setLoading(false);
    setRefreshing(false);
    setClockOffsetMilliseconds(0);
    if (isAuthenticated && !isAdmin) {
      void refresh();
    }
  }, [isAdmin, isAuthenticated, refresh, session?.user.id]);

  useEffect(() => {
    if (!isAuthenticated || isAdmin) {
      return;
    }
    const interval = window.setInterval(() => {
      if (!document.hidden) {
        void refresh();
      }
    }, 60_000);
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
  }, [isAdmin, isAuthenticated, refresh]);

  useEffect(() => {
    if (!isAuthenticated
        || isAdmin
        || !userNotification
        || !reservationNotificationTypes.has(userNotification.type)) {
      return;
    }
    void refresh();
  }, [isAdmin, isAuthenticated, refresh, userNotification]);

  const value = useMemo<DashboardContextValue>(() => ({
    summary,
    loading,
    refreshing,
    error,
    clockOffsetMilliseconds,
    refresh,
  }), [clockOffsetMilliseconds, error, loading, refresh, refreshing, summary]);

  return <DashboardContext.Provider value={value}>{children}</DashboardContext.Provider>;
}
