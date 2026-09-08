import { httpClient } from "./http";
import type {
  AdminSendSupportMessageResponse,
  AdminSupportConversation,
  AdminSupportMessageHistory,
  CursorPage,
  SendSupportMessageRequest,
  SupportConversationEvent,
  SupportQuickReply,
  SupportSuggestedReply,
  SupportUnreadCount,
  UpsertSupportQuickReplyRequest,
} from "../types/support";

const SUPPORT_WRITE_TIMEOUT_MS = 30_000;
const SUPPORT_AI_REQUEST_TIMEOUT_MS = 110_000;

export interface AdminConversationQuery {
  status?: string;
  category?: string;
  cursor?: string | null;
  pageSize?: number;
}

export const adminSupportApi = {
  getConversations: async (query: AdminConversationQuery): Promise<CursorPage<AdminSupportConversation>> => {
    const response = await httpClient.get<CursorPage<AdminSupportConversation>>("/admin/support/conversations", {
      params: {
        ...query,
        cursor: query.cursor || undefined,
        status: query.status || undefined,
        category: query.category || undefined,
      },
    });
    return response.data;
  },

  getMessages: async (
    conversationId: string,
    cursor?: string | null,
    pageSize = 50,
  ): Promise<AdminSupportMessageHistory> => {
    const response = await httpClient.get<AdminSupportMessageHistory>(
      `/admin/support/conversations/${conversationId}/messages`,
      { params: { cursor: cursor || undefined, pageSize } },
    );
    return response.data;
  },

  getEvents: async (
    conversationId: string,
    cursor?: string | null,
    pageSize = 30,
  ): Promise<CursorPage<SupportConversationEvent>> => {
    const response = await httpClient.get<CursorPage<SupportConversationEvent>>(
      `/admin/support/conversations/${conversationId}/events`,
      { params: { cursor: cursor || undefined, pageSize } },
    );
    return response.data;
  },

  claim: async (conversationId: string): Promise<AdminSupportConversation> => {
    const response = await httpClient.post<AdminSupportConversation>(
      `/admin/support/conversations/${conversationId}/claim`,
    );
    return response.data;
  },

  sendMessage: async (
    conversationId: string,
    request: SendSupportMessageRequest,
  ): Promise<AdminSendSupportMessageResponse> => {
    const response = await httpClient.post<AdminSendSupportMessageResponse>(
      `/admin/support/conversations/${conversationId}/messages`,
      request,
      { timeout: SUPPORT_WRITE_TIMEOUT_MS },
    );
    return response.data;
  },

  markRead: async (conversationId: string): Promise<SupportUnreadCount> => {
    const response = await httpClient.post<SupportUnreadCount>(
      `/admin/support/conversations/${conversationId}/read`,
    );
    return response.data;
  },

  resolve: async (conversationId: string): Promise<AdminSupportConversation> => {
    const response = await httpClient.post<AdminSupportConversation>(
      `/admin/support/conversations/${conversationId}/resolve`,
    );
    return response.data;
  },

  close: async (conversationId: string): Promise<AdminSupportConversation> => {
    const response = await httpClient.post<AdminSupportConversation>(
      `/admin/support/conversations/${conversationId}/close`,
    );
    return response.data;
  },

  updateTitle: async (conversationId: string, title: string): Promise<AdminSupportConversation> => {
    const response = await httpClient.put<AdminSupportConversation>(
      `/admin/support/conversations/${conversationId}/title`,
      { title },
    );
    return response.data;
  },

  getUnreadCount: async (): Promise<SupportUnreadCount> => {
    const response = await httpClient.get<SupportUnreadCount>("/admin/support/unread-count");
    return response.data;
  },

  generateSuggestedReply: async (conversationId: string): Promise<SupportSuggestedReply> => {
    const response = await httpClient.post<SupportSuggestedReply>(
      `/admin/support/conversations/${conversationId}/suggest-reply`,
      undefined,
      { timeout: SUPPORT_AI_REQUEST_TIMEOUT_MS },
    );
    return response.data;
  },

  getQuickReplies: async (includeInactive = false): Promise<SupportQuickReply[]> => {
    const response = await httpClient.get<SupportQuickReply[]>("/admin/support/quick-replies", {
      params: { includeInactive },
    });
    return response.data;
  },

  createQuickReply: async (request: UpsertSupportQuickReplyRequest): Promise<SupportQuickReply> => {
    const response = await httpClient.post<SupportQuickReply>("/admin/support/quick-replies", request);
    return response.data;
  },

  updateQuickReply: async (
    quickReplyId: string,
    request: UpsertSupportQuickReplyRequest,
  ): Promise<SupportQuickReply> => {
    const response = await httpClient.put<SupportQuickReply>(
      `/admin/support/quick-replies/${quickReplyId}`,
      request,
    );
    return response.data;
  },

  deactivateQuickReply: async (quickReplyId: string): Promise<void> => {
    await httpClient.delete(`/admin/support/quick-replies/${quickReplyId}`);
  },
};
