import { createContext } from "react";
import type { UserNotification } from "../types/notifications";

export interface NotificationContextValue {
  notifications: UserNotification[];
  unreadCount: number;
  loading: boolean;
  loadingMore: boolean;
  error: string;
  hasMore: boolean;
  refresh: () => Promise<void>;
  loadMore: () => Promise<void>;
  markRead: (notificationId: string) => Promise<void>;
  markAllRead: () => Promise<void>;
}

export const NotificationContext = createContext<NotificationContextValue | null>(null);
