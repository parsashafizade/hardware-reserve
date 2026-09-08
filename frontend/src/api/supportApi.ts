import axios from "axios";
import { API_BASE_URL } from "./config";
import { httpClient } from "./http";
import type {
  AnonymousSupportSession,
  CreateSupportConversationRequest,
  CursorPage,
  SendSupportMessageRequest,
  SendSupportMessageResponse,
  SupportConversation,
  SupportMessageHistory,
  SupportUnreadCount,
} from "../types/support";

const SUPPORT_REQUEST_TIMEOUT_MS = 20_000;
const SUPPORT_AI_REQUEST_TIMEOUT_MS = 110_000;
const anonymousHttpClient = axios.create({
  baseURL: API_BASE_URL,
  timeout: SUPPORT_REQUEST_TIMEOUT_MS,
});

function anonymousHeaders(sessionToken: string) {
  return { "X-Support-Session": sessionToken };
}

export const supportApi = {
  createAnonymousSession: async (): Promise<AnonymousSupportSession> => {
    const response = await anonymousHttpClient.post<AnonymousSupportSession>("/support/anonymous/sessions");
    return response.data;
  },

  createConversation: async (
    request: CreateSupportConversationRequest,
    sessionToken?: string,
  ): Promise<SupportConversation> => {
    const response = sessionToken
      ? await anonymousHttpClient.post<SupportConversation>("/support/anonymous/conversations", request, {
          headers: anonymousHeaders(sessionToken),
        })
      : await httpClient.post<SupportConversation>("/support/conversations", request);
    return response.data;
  },

  getConversations: async (
    cursor?: string | null,
    pageSize = 20,
    sessionToken?: string,
  ): Promise<CursorPage<SupportConversation>> => {
    const config = { params: { cursor: cursor || undefined, pageSize } };
    const response = sessionToken
      ? await anonymousHttpClient.get<CursorPage<SupportConversation>>("/support/anonymous/conversations", {
          ...config,
          headers: anonymousHeaders(sessionToken),
        })
      : await httpClient.get<CursorPage<SupportConversation>>("/support/conversations", config);
    return response.data;
  },

  getMessages: async (
    conversationId: string,
    cursor?: string | null,
    pageSize = 50,
    sessionToken?: string,
  ): Promise<SupportMessageHistory> => {
    const path = `/support/${sessionToken ? "anonymous/" : ""}conversations/${conversationId}/messages`;
    const config = {
      params: { cursor: cursor || undefined, pageSize },
      ...(sessionToken ? { headers: anonymousHeaders(sessionToken) } : {}),
    };
    const response = sessionToken
      ? await anonymousHttpClient.get<SupportMessageHistory>(path, config)
      : await httpClient.get<SupportMessageHistory>(path, config);
    return response.data;
  },

  sendMessage: async (
    conversationId: string,
    request: SendSupportMessageRequest,
    sessionToken?: string,
  ): Promise<SendSupportMessageResponse> => {
    const path = `/support/${sessionToken ? "anonymous/" : ""}conversations/${conversationId}/messages`;
    const response = sessionToken
      ? await anonymousHttpClient.post<SendSupportMessageResponse>(path, request, {
          headers: anonymousHeaders(sessionToken),
          timeout: SUPPORT_AI_REQUEST_TIMEOUT_MS,
        })
      : await httpClient.post<SendSupportMessageResponse>(path, request, {
          timeout: SUPPORT_AI_REQUEST_TIMEOUT_MS,
        });
    return response.data;
  },

  requestAdmin: async (conversationId: string, sessionToken?: string): Promise<SupportConversation> => {
    const path = `/support/${sessionToken ? "anonymous/" : ""}conversations/${conversationId}/request-admin`;
    const response = sessionToken
      ? await anonymousHttpClient.post<SupportConversation>(path, undefined, {
          headers: anonymousHeaders(sessionToken),
        })
      : await httpClient.post<SupportConversation>(path);
    return response.data;
  },

  markRead: async (conversationId: string, sessionToken?: string): Promise<SupportUnreadCount> => {
    const path = `/support/${sessionToken ? "anonymous/" : ""}conversations/${conversationId}/read`;
    const response = sessionToken
      ? await anonymousHttpClient.post<SupportUnreadCount>(path, undefined, {
          headers: anonymousHeaders(sessionToken),
        })
      : await httpClient.post<SupportUnreadCount>(path);
    return response.data;
  },

  getUnreadCount: async (sessionToken?: string): Promise<SupportUnreadCount> => {
    const path = `/support/${sessionToken ? "anonymous/" : ""}unread-count`;
    const response = sessionToken
      ? await anonymousHttpClient.get<SupportUnreadCount>(path, {
          headers: anonymousHeaders(sessionToken),
        })
      : await httpClient.get<SupportUnreadCount>(path);
    return response.data;
  },
};
