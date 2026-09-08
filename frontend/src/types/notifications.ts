export type UserNotificationType =
  | "ReservationCreated"
  | "PaymentConfirmed"
  | "ReservationStartsSoon"
  | "ReservationStarted"
  | "ReservationEndsSoon"
  | "ReservationCompleted"
  | "ServiceDetailsAssigned"
  | "SupportReply"
  | "AdminMessage"
  | "ReservationCancelled";

export interface UserNotification {
  id: string;
  type: UserNotificationType;
  source: "System" | "Admin";
  resourceLabel?: string | null;
  title?: string | null;
  message?: string | null;
  reservationId?: number | null;
  supportConversationId?: string | null;
  eventTime?: string | null;
  createdAt: string;
  readAt?: string | null;
}

export interface NotificationPage {
  items: UserNotification[];
  nextCursor?: string | null;
  hasMore: boolean;
}

export interface NotificationUnreadCount {
  unreadCount: number;
}

export interface NotificationReadStateEvent {
  eventId: string;
  notificationId?: string | null;
  unreadCount: number;
  occurredAt: string;
}
