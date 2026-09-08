import { createContext } from "react";
import type {
  SendSupportMessageResponse,
  SupportConversation,
  SupportMessage,
} from "../types/support";
import type { SupportRealtimeState } from "./SupportRealtimeContextDefinition";

export type SupportWidgetView = "conversation" | "history" | "new";

export interface SupportContextValue {
  isOpen: boolean;
  view: SupportWidgetView;
  unreadCount: number;
  realtimeState: SupportRealtimeState;
  conversations: SupportConversation[];
  conversationsLoading: boolean;
  conversationsLoadingMore: boolean;
  conversationsError: string;
  conversationsHasMore: boolean;
  activeConversation: SupportConversation | null;
  messages: SupportMessage[];
  messagesLoading: boolean;
  messagesLoadingOlder: boolean;
  messagesError: string;
  messagesHasMore: boolean;
  newConversationDraft: string;
  openSupport: (view?: SupportWidgetView) => void;
  openSupportWithDraft: (draft: string) => void;
  closeSupport: () => void;
  showHistory: () => void;
  showNewConversation: () => void;
  loadConversations: (reset?: boolean) => Promise<void>;
  loadMoreConversations: () => Promise<void>;
  openConversation: (conversationId: string) => Promise<void>;
  loadOlderMessages: () => Promise<void>;
  createConversation: (category?: string) => Promise<SupportConversation>;
  sendMessage: (
    content: string,
    clientMessageId: string,
  ) => Promise<SendSupportMessageResponse>;
  requestAdministrator: () => Promise<void>;
  refreshActiveConversation: () => Promise<void>;
}

export const SupportContext = createContext<SupportContextValue | null>(null);
