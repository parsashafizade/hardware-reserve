import { httpClient } from "./http";
import type {
  NotificationPage,
  NotificationUnreadCount,
  UserNotification,
} from "../types/notifications";

export const notificationsApi = {
  getNotifications(cursor?: string, pageSize = 20) {
    return httpClient
      .get<NotificationPage>("/notifications", { params: { cursor, pageSize } })
      .then((response) => response.data);
  },
  getUnreadCount() {
    return httpClient
      .get<NotificationUnreadCount>("/notifications/unread-count")
      .then((response) => response.data);
  },
  markRead(notificationId: string) {
    return httpClient
      .post<UserNotification>(`/notifications/${notificationId}/read`)
      .then((response) => response.data);
  },
  markAllRead() {
    return httpClient
      .post<NotificationUnreadCount>("/notifications/read-all")
      .then((response) => response.data);
  },
};
