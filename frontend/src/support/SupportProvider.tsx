import {
  useCallback,
  useEffect,
  useMemo,
  useRef,
  useState,
  type ReactNode,
} from "react";
import { supportApi } from "../api/supportApi";
import { useAuth } from "../auth/useAuth";
import {
  clearAnonymousSupportSession,
  getAnonymousSupportSession,
  setAnonymousSupportSession,
} from "../auth/supportSessionStorage";
import type {
  AnonymousSupportSession,
  SendSupportMessageResponse,
  SupportConversation,
  SupportMessage,
} from "../types/support";
import { getApiErrorMessage, isApiStatus } from "../utils/errors";
import { mergeSupportMessages } from "../utils/support";
import { SupportContext, type SupportContextValue, type SupportWidgetView } from "./SupportContextDefinition";
import { useSupportRealtime } from "./useSupportRealtime";
import i18n from "../i18n/config";

const ACTIVE_CONVERSATION_PREFIX = "hardware_reserve_support_active";

function mergeConversations(
  current: SupportConversation[],
  incoming: SupportConversation[],
): SupportConversation[] {
  const byId = new Map<string, SupportConversation>();
  for (const conversation of [...current, ...incoming]) {
    byId.set(conversation.id, conversation);
  }

  return [...byId.values()].sort(
    (left, right) => new Date(right.updatedAt).getTime() - new Date(left.updatedAt).getTime(),
  );
}

export function SupportProvider({ children }: { children: ReactNode }) {
  const { isAuthenticated, isAdmin, session } = useAuth();
  const {
    state: realtimeState,
    notification: realtimeNotification,
    subscribeToConversation,
    unsubscribeFromConversation,
  } = useSupportRealtime();
  const identityKey = isAuthenticated ? `user-${session?.user.id ?? "unknown"}` : "anonymous";
  const activeStorageKey = `${ACTIVE_CONVERSATION_PREFIX}:${identityKey}`;

  const [isOpen, setIsOpen] = useState(false);
  const [view, setView] = useState<SupportWidgetView>("new");
  const [unreadCount, setUnreadCount] = useState(0);
  const [conversations, setConversations] = useState<SupportConversation[]>([]);
  const [conversationsLoading, setConversationsLoading] = useState(false);
  const [conversationsLoadingMore, setConversationsLoadingMore] = useState(false);
  const [conversationsError, setConversationsError] = useState("");
  const [conversationsHasMore, setConversationsHasMore] = useState(false);
  const [activeConversation, setActiveConversation] = useState<SupportConversation | null>(null);
  const [messages, setMessages] = useState<SupportMessage[]>([]);
  const [messagesLoading, setMessagesLoading] = useState(false);
  const [messagesLoadingOlder, setMessagesLoadingOlder] = useState(false);
  const [messagesError, setMessagesError] = useState("");
  const [messagesHasMore, setMessagesHasMore] = useState(false);
  const [newConversationDraft, setNewConversationDraft] = useState("");

  const identityRef = useRef(identityKey);
  const isOpenRef = useRef(isOpen);
  const viewRef = useRef(view);
  const activeConversationIdRef = useRef<string | null>(null);
  const conversationCursorRef = useRef<string | null>(null);
  const messageCursorRef = useRef<string | null>(null);
  const messagesRef = useRef<SupportMessage[]>([]);
  const anonymousSessionPromiseRef = useRef<Promise<AnonymousSupportSession> | null>(null);

  useEffect(() => {
    isOpenRef.current = isOpen;
  }, [isOpen]);

  useEffect(() => {
    viewRef.current = view;
  }, [view]);

  useEffect(() => {
    messagesRef.current = messages;
  }, [messages]);

  const getSessionToken = useCallback(
    async (createIfMissing: boolean): Promise<string | undefined> => {
      if (isAuthenticated) {
        return undefined;
      }

      const stored = getAnonymousSupportSession();
      if (stored) {
        return stored.sessionToken;
      }

      if (!createIfMissing) {
        return undefined;
      }

      if (!anonymousSessionPromiseRef.current) {
        anonymousSessionPromiseRef.current = supportApi.createAnonymousSession();
      }

      try {
        const created = await anonymousSessionPromiseRef.current;
        setAnonymousSupportSession(created);
        return created.sessionToken;
      } finally {
        anonymousSessionPromiseRef.current = null;
      }
    },
    [isAuthenticated],
  );

  const refreshUnreadCount = useCallback(async () => {
    const requestIdentity = identityKey;
    if (isAdmin) {
      setUnreadCount(0);
      return;
    }
    try {
      const sessionToken = await getSessionToken(false);
      if (!isAuthenticated && !sessionToken) {
        if (identityRef.current === requestIdentity) {
          setUnreadCount(0);
        }
        return;
      }

      const result = await supportApi.getUnreadCount(sessionToken);
      if (identityRef.current === requestIdentity) {
        setUnreadCount(result.unreadMessages);
      }
    } catch (error) {
      if (!isAuthenticated && isApiStatus(error, 401)) {
        clearAnonymousSupportSession();
      }
    }
  }, [getSessionToken, identityKey, isAdmin, isAuthenticated]);

  const markActiveRead = useCallback(
    async (conversationId: string) => {
      try {
        const sessionToken = await getSessionToken(false);
        if (!isAuthenticated && !sessionToken) {
          return;
        }
        const result = await supportApi.markRead(conversationId, sessionToken);
        setUnreadCount(result.unreadMessages);
        setConversations((current) =>
          current.map((conversation) =>
            conversation.id === conversationId ? { ...conversation, unreadCount: 0 } : conversation,
          ),
        );
        setActiveConversation((current) =>
          current?.id === conversationId ? { ...current, unreadCount: 0 } : current,
        );
      } catch {
        // Read state is retried on the next persisted refresh.
      }
    },
    [getSessionToken, isAuthenticated],
  );

  const loadConversations = useCallback(
    async (reset = true) => {
      const requestIdentity = identityKey;
      if (reset) {
        setConversationsLoading(true);
        setConversationsError("");
      } else {
        setConversationsLoadingMore(true);
      }

      try {
        const sessionToken = await getSessionToken(false);
        if (!isAuthenticated && !sessionToken) {
          if (identityRef.current === requestIdentity) {
            setConversations([]);
            setConversationsHasMore(false);
            conversationCursorRef.current = null;
          }
          return;
        }

        const cursor = reset ? null : conversationCursorRef.current;
        const page = await supportApi.getConversations(cursor, 20, sessionToken);
        if (identityRef.current !== requestIdentity) {
          return;
        }

        setConversations((current) =>
          reset ? page.items : mergeConversations(current, page.items),
        );
        conversationCursorRef.current = page.nextCursor ?? null;
        setConversationsHasMore(page.hasMore);
      } catch (error) {
        if (!isAuthenticated && isApiStatus(error, 401)) {
          clearAnonymousSupportSession();
        }
        if (identityRef.current === requestIdentity) {
          setConversationsError(getApiErrorMessage(error, i18n.t("support.provider.conversationsError")));
        }
      } finally {
        if (identityRef.current === requestIdentity) {
          setConversationsLoading(false);
          setConversationsLoadingMore(false);
        }
      }
    },
    [getSessionToken, identityKey, isAuthenticated],
  );

  const loadMoreConversations = useCallback(async () => {
    if (!conversationsHasMore || conversationsLoadingMore) {
      return;
    }
    await loadConversations(false);
  }, [conversationsHasMore, conversationsLoadingMore, loadConversations]);

  const loadConversation = useCallback(
    async (conversationId: string) => {
      const requestIdentity = identityKey;
      activeConversationIdRef.current = conversationId;
      localStorage.setItem(activeStorageKey, conversationId);
      setMessagesLoading(true);
      setMessagesError("");
      setView("conversation");

      try {
        const sessionToken = await getSessionToken(false);
        if (!isAuthenticated && !sessionToken) {
          throw new Error(i18n.t("support.provider.guestExpired"));
        }

        const history = await supportApi.getMessages(conversationId, null, 50, sessionToken);
        if (
          identityRef.current !== requestIdentity ||
          activeConversationIdRef.current !== conversationId
        ) {
          return;
        }

        setActiveConversation(history.conversation);
        setMessages(mergeSupportMessages([], history.messages.items));
        messageCursorRef.current = history.messages.nextCursor ?? null;
        setMessagesHasMore(history.messages.hasMore);
        setConversations((current) => mergeConversations(current, [history.conversation]));
        if (
          history.conversation.unreadCount > 0 &&
          isOpenRef.current &&
          viewRef.current === "conversation"
        ) {
          void markActiveRead(conversationId);
        }
      } catch (error) {
        setMessagesError(getApiErrorMessage(error, i18n.t("support.provider.conversationError")));
      } finally {
        if (activeConversationIdRef.current === conversationId) {
          setMessagesLoading(false);
        }
      }
    },
    [activeStorageKey, getSessionToken, identityKey, isAuthenticated, markActiveRead],
  );

  const openConversation = useCallback(
    async (conversationId: string) => {
      setIsOpen(true);
      await loadConversation(conversationId);
    },
    [loadConversation],
  );

  const refreshActiveConversation = useCallback(async () => {
    const conversationId = activeConversationIdRef.current;
    if (!conversationId) {
      return;
    }

    try {
      const sessionToken = await getSessionToken(false);
      if (!isAuthenticated && !sessionToken) {
        return;
      }
      const history = await supportApi.getMessages(conversationId, null, 50, sessionToken);
      if (activeConversationIdRef.current !== conversationId) {
        return;
      }
      setActiveConversation(history.conversation);
      const currentMessages = messagesRef.current;
      const currentTail = currentMessages.at(-1)?.sequenceNumber;
      const incomingHead = history.messages.items.at(0)?.sequenceNumber;
      const missedRange = currentTail !== undefined
        && incomingHead !== undefined
        && incomingHead > currentTail + 1;
      if (currentMessages.length === 0 || missedRange) {
        messageCursorRef.current = history.messages.nextCursor ?? null;
        setMessagesHasMore(history.messages.hasMore);
      }
      setMessages((current) => {
        return mergeSupportMessages(current, history.messages.items);
      });
      setConversations((current) => mergeConversations(current, [history.conversation]));
      if (
        history.conversation.unreadCount > 0 &&
        isOpenRef.current &&
        viewRef.current === "conversation"
      ) {
        void markActiveRead(conversationId);
      }
    } catch {
      // Existing persisted content remains usable while a refresh is unavailable.
    }
  }, [getSessionToken, isAuthenticated, markActiveRead]);

  const loadOlderMessages = useCallback(async () => {
    const conversationId = activeConversationIdRef.current;
    if (!conversationId || !messagesHasMore || messagesLoadingOlder) {
      return;
    }

    setMessagesLoadingOlder(true);
    try {
      const sessionToken = await getSessionToken(false);
      if (!isAuthenticated && !sessionToken) {
        return;
      }
      const history = await supportApi.getMessages(
        conversationId,
        messageCursorRef.current,
        50,
        sessionToken,
      );
      if (activeConversationIdRef.current !== conversationId) {
        return;
      }
      setMessages((current) => mergeSupportMessages(current, history.messages.items));
      messageCursorRef.current = history.messages.nextCursor ?? null;
      setMessagesHasMore(history.messages.hasMore);
    } catch (error) {
      setMessagesError(getApiErrorMessage(error, i18n.t("support.provider.olderMessagesError")));
    } finally {
      setMessagesLoadingOlder(false);
    }
  }, [getSessionToken, isAuthenticated, messagesHasMore, messagesLoadingOlder]);

  const createConversation = useCallback(
    async (category?: string) => {
      const sessionToken = await getSessionToken(true);
      const created = await supportApi.createConversation(
        { category: category || undefined },
        sessionToken,
      );
      activeConversationIdRef.current = created.id;
      localStorage.setItem(activeStorageKey, created.id);
      setActiveConversation(created);
      setMessages([]);
      messageCursorRef.current = null;
      setMessagesHasMore(false);
      setMessagesError("");
      setConversations((current) => mergeConversations(current, [created]));
      setView("conversation");
      setNewConversationDraft("");
      return created;
    },
    [activeStorageKey, getSessionToken],
  );

  const sendMessage = useCallback(
    async (content: string, clientMessageId: string): Promise<SendSupportMessageResponse> => {
      const conversationId = activeConversationIdRef.current;
      if (!conversationId) {
        throw new Error(i18n.t("support.provider.openBeforeSend"));
      }

      const sessionToken = await getSessionToken(false);
      if (!isAuthenticated && !sessionToken) {
        throw new Error(i18n.t("support.provider.guestExpired"));
      }

      const response = await supportApi.sendMessage(
        conversationId,
        { clientMessageId, content },
        sessionToken,
      );
      const returnedMessages = [response.message];
      if (response.automation.assistantMessage) {
        returnedMessages.push(response.automation.assistantMessage);
      }
      setMessages((current) => mergeSupportMessages(current, returnedMessages));
      setActiveConversation(response.conversation);
      setConversations((current) => mergeConversations(current, [response.conversation]));
      if (response.conversation.unreadCount > 0) {
        await markActiveRead(conversationId);
      }
      void loadConversations(true);
      return response;
    },
    [getSessionToken, isAuthenticated, loadConversations, markActiveRead],
  );

  const requestAdministrator = useCallback(async () => {
    const conversationId = activeConversationIdRef.current;
    if (!conversationId) {
      return;
    }
    const sessionToken = await getSessionToken(false);
    if (!isAuthenticated && !sessionToken) {
      throw new Error(i18n.t("support.provider.guestExpired"));
    }
    const updated = await supportApi.requestAdmin(conversationId, sessionToken);
    setActiveConversation(updated);
    setConversations((current) => mergeConversations(current, [updated]));
  }, [getSessionToken, isAuthenticated]);

  const openSupport = useCallback(
    (requestedView?: SupportWidgetView) => {
      setIsOpen(true);
      const nextView = requestedView ?? (activeConversationIdRef.current ? "conversation" : "new");
      setView(nextView);
      void loadConversations(true);
      if (nextView === "conversation" && activeConversationIdRef.current) {
        void loadConversation(activeConversationIdRef.current);
      }
    },
    [loadConversation, loadConversations],
  );

  const closeSupport = useCallback(() => setIsOpen(false), []);

  const openSupportWithDraft = useCallback((draft: string) => {
    setNewConversationDraft(draft.trim());
    setIsOpen(true);
    setView("new");
  }, []);

  const showHistory = useCallback(() => {
    setIsOpen(true);
    setView("history");
    void loadConversations(true);
  }, [loadConversations]);

  const showNewConversation = useCallback(() => {
    setNewConversationDraft("");
    setIsOpen(true);
    setView("new");
  }, []);

  useEffect(() => {
    identityRef.current = identityKey;
    anonymousSessionPromiseRef.current = null;
    conversationCursorRef.current = null;
    messageCursorRef.current = null;
    activeConversationIdRef.current = null;
    setConversations([]);
    setConversationsHasMore(false);
    setConversationsError("");
    setActiveConversation(null);
    setMessages([]);
    messagesRef.current = [];
    setMessagesHasMore(false);
    setMessagesError("");
    setUnreadCount(0);
    setView("new");
    setNewConversationDraft("");

    const savedConversationId = localStorage.getItem(activeStorageKey);
    if (savedConversationId) {
      activeConversationIdRef.current = savedConversationId;
    }

    void refreshUnreadCount();
  }, [activeStorageKey, identityKey, refreshUnreadCount]);

  useEffect(() => {
    const conversationId = activeConversation?.id;
    if (!conversationId || !isAuthenticated) {
      return;
    }
    void subscribeToConversation(conversationId).catch(() => {
      // Persisted HTTP polling continues when a realtime subscription is interrupted.
    });
    return () => {
      void unsubscribeFromConversation(conversationId).catch(() => {
        // Connection teardown may cancel this invocation after navigation or logout.
      });
    };
  }, [activeConversation?.id, isAuthenticated, subscribeToConversation, unsubscribeFromConversation]);

  useEffect(() => {
    const event = realtimeNotification;
    if (!event) {
      return;
    }
    void refreshUnreadCount();
    void loadConversations(true);
    if (event.conversationId === activeConversationIdRef.current) {
      void refreshActiveConversation();
    }
  }, [loadConversations, realtimeNotification, refreshActiveConversation, refreshUnreadCount]);

  useEffect(() => {
    if (isAdmin) {
      return;
    }
    const realtimeUnavailable = isAuthenticated && realtimeState !== "connected";
    const delay = realtimeUnavailable ? 8_000 : isAuthenticated ? 30_000 : 12_000;
    const interval = window.setInterval(() => {
      void refreshUnreadCount();
      if (isOpenRef.current && activeConversationIdRef.current && !document.hidden) {
        void refreshActiveConversation();
      }
    }, delay);
    return () => window.clearInterval(interval);
  }, [isAdmin, isAuthenticated, realtimeState, refreshActiveConversation, refreshUnreadCount]);

  const value = useMemo<SupportContextValue>(
    () => ({
      isOpen,
      view,
      unreadCount,
      realtimeState,
      conversations,
      conversationsLoading,
      conversationsLoadingMore,
      conversationsError,
      conversationsHasMore,
      activeConversation,
      messages,
      messagesLoading,
      messagesLoadingOlder,
      messagesError,
      messagesHasMore,
      newConversationDraft,
      openSupport,
      openSupportWithDraft,
      closeSupport,
      showHistory,
      showNewConversation,
      loadConversations,
      loadMoreConversations,
      openConversation,
      loadOlderMessages,
      createConversation,
      sendMessage,
      requestAdministrator,
      refreshActiveConversation,
    }),
    [
      activeConversation,
      closeSupport,
      conversations,
      conversationsError,
      conversationsHasMore,
      conversationsLoading,
      conversationsLoadingMore,
      createConversation,
      isOpen,
      loadConversations,
      loadMoreConversations,
      loadOlderMessages,
      messages,
      messagesError,
      messagesHasMore,
      messagesLoading,
      messagesLoadingOlder,
      newConversationDraft,
      openConversation,
      openSupport,
      openSupportWithDraft,
      realtimeState,
      refreshActiveConversation,
      requestAdministrator,
      sendMessage,
      showHistory,
      showNewConversation,
      unreadCount,
      view,
    ],
  );

  return <SupportContext.Provider value={value}>{children}</SupportContext.Provider>;
}
