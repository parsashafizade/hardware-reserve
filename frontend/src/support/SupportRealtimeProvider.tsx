import { useCallback, useEffect, useMemo, useRef, useState, type ReactNode } from "react";
import {
  HubConnection,
  HubConnectionBuilder,
  HubConnectionState,
  LogLevel,
} from "@microsoft/signalr";
import { useAuth } from "../auth/useAuth";
import { getAccessToken } from "../auth/tokenStorage";
import { API_BASE_URL } from "../api/config";
import type { SupportRealtimeNotification } from "../types/support";
import type { NotificationReadStateEvent, UserNotification } from "../types/notifications";
import {
  SupportRealtimeContext,
  type SupportRealtimeContextValue,
  type SupportRealtimeState,
} from "./SupportRealtimeContextDefinition";

const HUB_URL = `${API_BASE_URL.replace(/\/+$/, "")}/hubs/support`;

export function SupportRealtimeProvider({ children }: { children: ReactNode }) {
  const { isAuthenticated, session } = useAuth();
  const realtimeIdentity = isAuthenticated
    ? `${session?.user.id ?? "unknown"}:${session?.user.role ?? "unknown"}`
    : "disabled";
  const [state, setState] = useState<SupportRealtimeState>(isAuthenticated ? "connecting" : "disabled");
  const [notificationEnvelope, setNotificationEnvelope] = useState<{
    identity: string;
    value: SupportRealtimeNotification;
  } | null>(null);
  const [userNotificationEnvelope, setUserNotificationEnvelope] = useState<{
    identity: string;
    value: UserNotification;
  } | null>(null);
  const [readStateEnvelope, setReadStateEnvelope] = useState<{
    identity: string;
    value: NotificationReadStateEvent;
  } | null>(null);
  const connectionRef = useRef<HubConnection | null>(null);
  const subscriptionsRef = useRef(new Set<string>());
  const seenNotificationIdsRef = useRef(new Set<string>());
  const identityRef = useRef(realtimeIdentity);

  useEffect(() => {
    if (identityRef.current === realtimeIdentity) {
      return;
    }

    identityRef.current = realtimeIdentity;
    subscriptionsRef.current.clear();
    seenNotificationIdsRef.current.clear();
  }, [realtimeIdentity]);

  useEffect(() => {
    if (!isAuthenticated) {
      return;
    }

    let disposed = false;
    let retryTimer: number | undefined;

    const clearRetryTimer = () => {
      if (retryTimer) {
        window.clearTimeout(retryTimer);
        retryTimer = undefined;
      }
    };

    const connection = new HubConnectionBuilder()
      .withUrl(HUB_URL, {
        accessTokenFactory: () => getAccessToken() ?? "",
      })
      .withAutomaticReconnect([0, 2_000, 5_000, 10_000, 30_000])
      .configureLogging(LogLevel.Warning)
      .build();

    connectionRef.current = connection;

    const rememberEvent = (eventId: string) => {
      if (seenNotificationIdsRef.current.has(eventId)) {
        return false;
      }
      seenNotificationIdsRef.current.add(eventId);
      if (seenNotificationIdsRef.current.size > 200) {
        const oldest = seenNotificationIdsRef.current.values().next().value;
        if (oldest) {
          seenNotificationIdsRef.current.delete(oldest);
        }
      }
      return true;
    };

    connection.on("SupportEvent", (event: SupportRealtimeNotification) => {
      if (disposed || !rememberEvent(`support:${event.notificationId}`)) {
        return;
      }
      setNotificationEnvelope({ identity: realtimeIdentity, value: event });
    });

    connection.on("NotificationEvent", (event: UserNotification) => {
      if (disposed || !rememberEvent(`notification:${event.id}`)) {
        return;
      }
      setUserNotificationEnvelope({ identity: realtimeIdentity, value: event });
    });

    connection.on("NotificationStateEvent", (event: NotificationReadStateEvent) => {
      if (disposed || !rememberEvent(`notification-state:${event.eventId}`)) {
        return;
      }
      setReadStateEnvelope({ identity: realtimeIdentity, value: event });
    });

    connection.onreconnecting(() => {
      if (!disposed) {
        setState("reconnecting");
      }
    });

    const restoreConversationSubscriptions = async () => {
      await Promise.allSettled(
        [...subscriptionsRef.current].map((conversationId) =>
          connection.invoke("SubscribeToConversation", conversationId),
        ),
      );
    };

    connection.onreconnected(async () => {
      if (disposed) {
        return;
      }

      setState("connected");
      await restoreConversationSubscriptions();
    });

    const scheduleRetry = (start: () => Promise<void>) => {
      clearRetryTimer();
      if (!disposed && navigator.onLine) {
        retryTimer = window.setTimeout(() => void start(), 5_000);
      }
    };

    connection.onclose(() => {
      if (!disposed) {
        setState("disconnected");
        scheduleRetry(start);
      }
    });

    async function start() {
      if (disposed || connection.state !== HubConnectionState.Disconnected) {
        return;
      }

      try {
        setState("connecting");
        await connection.start();
        if (!disposed) {
          setState("connected");
          await restoreConversationSubscriptions();
        }
      } catch {
        if (!disposed) {
          setState("disconnected");
          scheduleRetry(start);
        }
      }
    }

    const handleOnline = () => void start();
    window.addEventListener("online", handleOnline);
    void start();

    return () => {
      disposed = true;
      clearRetryTimer();
      window.removeEventListener("online", handleOnline);
      if (connectionRef.current === connection) {
        connectionRef.current = null;
      }
      void connection.stop().catch(() => {
        // Teardown can race with an in-flight hub invocation; HTTP state remains authoritative.
      });
    };
  }, [isAuthenticated, realtimeIdentity]);

  const subscribeToConversation = useCallback(async (conversationId: string) => {
    subscriptionsRef.current.add(conversationId);
    const connection = connectionRef.current;
    if (connection?.state === HubConnectionState.Connected) {
      await connection.invoke("SubscribeToConversation", conversationId);
    }
  }, []);

  const unsubscribeFromConversation = useCallback(async (conversationId: string) => {
    subscriptionsRef.current.delete(conversationId);
    const connection = connectionRef.current;
    if (connection?.state === HubConnectionState.Connected) {
      await connection.invoke("UnsubscribeFromConversation", conversationId);
    }
  }, []);

  const value = useMemo<SupportRealtimeContextValue>(
    () => ({
      state: isAuthenticated ? state : "disabled",
      notification: isAuthenticated && notificationEnvelope?.identity === realtimeIdentity
        ? notificationEnvelope.value
        : null,
      userNotification: isAuthenticated && userNotificationEnvelope?.identity === realtimeIdentity
        ? userNotificationEnvelope.value
        : null,
      notificationReadState: isAuthenticated && readStateEnvelope?.identity === realtimeIdentity
        ? readStateEnvelope.value
        : null,
      subscribeToConversation,
      unsubscribeFromConversation,
    }),
    [isAuthenticated, notificationEnvelope, readStateEnvelope, realtimeIdentity, state, subscribeToConversation, unsubscribeFromConversation, userNotificationEnvelope],
  );

  return <SupportRealtimeContext.Provider value={value}>{children}</SupportRealtimeContext.Provider>;
}
