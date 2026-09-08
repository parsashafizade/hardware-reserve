import { createContext } from "react";
import type { SupportRealtimeNotification } from "../types/support";
import type { NotificationReadStateEvent, UserNotification } from "../types/notifications";

export type SupportRealtimeState = "disabled" | "connecting" | "connected" | "reconnecting" | "disconnected";

export interface SupportRealtimeContextValue {
  state: SupportRealtimeState;
  notification: SupportRealtimeNotification | null;
  userNotification: UserNotification | null;
  notificationReadState: NotificationReadStateEvent | null;
  subscribeToConversation: (conversationId: string) => Promise<void>;
  unsubscribeFromConversation: (conversationId: string) => Promise<void>;
}

export const SupportRealtimeContext = createContext<SupportRealtimeContextValue | null>(null);
