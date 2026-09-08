export type SupportConversationStatus =
  | "AI_ACTIVE"
  | "WAITING_FOR_ADMIN"
  | "ADMIN_ACTIVE"
  | "RESOLVED"
  | "CLOSED";

export type SupportParticipantType = "USER" | "AI" | "ADMIN";

export interface CursorPage<T> {
  items: T[];
  nextCursor?: string | null;
  hasMore: boolean;
}

export interface SupportLastMessage {
  sequenceNumber: number;
  senderType: SupportParticipantType;
  preview: string;
  sentAt: string;
}

export interface SupportConversation {
  id: string;
  title: string;
  category?: string | null;
  status: SupportConversationStatus;
  isAnonymous: boolean;
  unreadCount: number;
  createdAt: string;
  updatedAt: string;
  resolvedAt?: string | null;
  closedAt?: string | null;
  lastMessage?: SupportLastMessage | null;
}

export interface SupportMessage {
  id: string;
  conversationId: string;
  sequenceNumber: number;
  senderType: SupportParticipantType;
  senderDisplayName: string;
  content: string;
  contentFormat: "PLAIN_TEXT" | string;
  createdAt: string;
}

export interface SupportMessageHistory {
  conversation: SupportConversation;
  messages: CursorPage<SupportMessage>;
}

export interface CreateSupportConversationRequest {
  title?: string;
  category?: string;
}

export interface SendSupportMessageRequest {
  clientMessageId: string;
  content: string;
}

export interface SupportAutomationResult {
  status: string;
  assistantMessage?: SupportMessage | null;
}

export interface SendSupportMessageResponse {
  message: SupportMessage;
  conversation: SupportConversation;
  isDuplicate: boolean;
  automation: SupportAutomationResult;
}

export interface AnonymousSupportSession {
  sessionToken: string;
  expiresAt: string;
}

export interface SupportUnreadCount {
  unreadMessages: number;
}

export interface SupportRealtimeNotification {
  notificationId: string;
  conversationId: string;
  messageId?: string | null;
  sequenceNumber?: number | null;
  eventType: string;
  occurredAt: string;
}

export interface AdminSupportOwner {
  ownerType: "USER" | "ANONYMOUS";
  userId?: number | null;
  fullName?: string | null;
  email?: string | null;
}

export interface AdminSupportConversation extends SupportConversation {
  owner: AdminSupportOwner;
  isAssignedToCurrentAdmin: boolean;
  isAssigned: boolean;
  aiHandoffSummary?: string | null;
  aiHandoffReason?: string | null;
  aiHandoffGeneratedAt?: string | null;
}

export interface AdminSupportMessageHistory {
  conversation: AdminSupportConversation;
  messages: CursorPage<SupportMessage>;
}

export interface AdminSendSupportMessageResponse {
  message: SupportMessage;
  conversation: AdminSupportConversation;
  isDuplicate: boolean;
}

export interface SupportQuickReply {
  id: string;
  title: string;
  content: string;
  category?: string | null;
  isActive: boolean;
  sortOrder: number;
  createdAt: string;
  updatedAt: string;
}

export interface UpsertSupportQuickReplyRequest {
  title: string;
  content: string;
  category?: string;
  isActive: boolean;
  sortOrder: number;
}

export interface SupportSuggestedReply {
  draft: string;
  generatedAt: string;
}

export interface SupportConversationEvent {
  id: string;
  eventType: string;
  actorType: string;
  previousStatus?: SupportConversationStatus | null;
  newStatus?: SupportConversationStatus | null;
  details?: string | null;
  occurredAt: string;
}
