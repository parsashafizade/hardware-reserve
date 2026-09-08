import { useCallback, useEffect, useRef, useState } from "react";
import { useTranslation } from "react-i18next";
import {
  AlertCircle,
  ArrowLeft,
  Bot,
  Check,
  CheckCircle2,
  ChevronDown,
  CircleX,
  Clock3,
  Headphones,
  Lightbulb,
  LoaderCircle,
  LockKeyhole,
  MessageSquareQuote,
  Pencil,
  RefreshCw,
  Save,
  Send,
  Sparkles,
  UserRound,
  WifiOff,
  X,
} from "lucide-react";
import { adminSupportApi } from "../../../api/adminSupportApi";
import { useSupportRealtime } from "../../../support/useSupportRealtime";
import type {
  AdminSupportConversation,
  SupportMessage,
  SupportQuickReply,
} from "../../../types/support";
import { getApiErrorMessage } from "../../../utils/errors";
import {
  formatSupportDateTime,
  formatSupportTime,
  getSupportCategoryLabel,
  mergeSupportMessages,
} from "../../../utils/support";
import { BidiText } from "../../support/BidiText";
import { SupportMessageList, type PendingSupportMessage } from "../../support/SupportMessageList";
import { SupportStatusBadge } from "../../support/SupportStatusBadge";
import { useLocale } from "../../../i18n/useLocale";

interface AdminSupportWorkspaceProps {
  conversationId: string;
  quickReplies: SupportQuickReply[];
  onBack: () => void;
  onConversationUpdated: (conversation: AdminSupportConversation) => void;
}

export function AdminSupportWorkspace({
  conversationId,
  quickReplies,
  onBack,
  onConversationUpdated,
}: AdminSupportWorkspaceProps) {
  const { t } = useTranslation();
  const { formatNumber } = useLocale();
  const {
    state: realtimeState,
    notification: realtimeNotification,
    subscribeToConversation,
    unsubscribeFromConversation,
  } = useSupportRealtime();
  const [conversation, setConversation] = useState<AdminSupportConversation | null>(null);
  const [messages, setMessages] = useState<SupportMessage[]>([]);
  const [messageCursor, setMessageCursor] = useState<string | null>(null);
  const [hasMore, setHasMore] = useState(false);
  const [loading, setLoading] = useState(true);
  const [loadingOlder, setLoadingOlder] = useState(false);
  const [error, setError] = useState("");
  const [actionError, setActionError] = useState("");
  const [actionMessage, setActionMessage] = useState("");
  const [composer, setComposer] = useState("");
  const [pending, setPending] = useState<PendingSupportMessage | null>(null);
  const [claiming, setClaiming] = useState(false);
  const [resolving, setResolving] = useState(false);
  const [closing, setClosing] = useState(false);
  const [confirmClose, setConfirmClose] = useState(false);
  const [editingTitle, setEditingTitle] = useState(false);
  const [titleDraft, setTitleDraft] = useState("");
  const [savingTitle, setSavingTitle] = useState(false);
  const [showQuickReplies, setShowQuickReplies] = useState(false);
  const [suggesting, setSuggesting] = useState(false);
  const [suggestedDraft, setSuggestedDraft] = useState<string | null>(null);
  const [suggestedAt, setSuggestedAt] = useState<string | null>(null);
  const currentConversationRef = useRef(conversationId);
  const messagesRef = useRef<SupportMessage[]>([]);
  const closeDialogRef = useRef<HTMLDivElement>(null);
  const closeCancelButtonRef = useRef<HTMLButtonElement>(null);
  const closeTriggerRef = useRef<HTMLButtonElement>(null);
  const workspaceRef = useRef<HTMLDivElement>(null);
  const closingRef = useRef(closing);

  useEffect(() => {
    messagesRef.current = messages;
  }, [messages]);

  useEffect(() => {
    closingRef.current = closing;
  }, [closing]);

  const applyConversation = useCallback(
    (updated: AdminSupportConversation) => {
      setConversation(updated);
      setTitleDraft(updated.title);
      onConversationUpdated(updated);
    },
    [onConversationUpdated],
  );

  const markRead = useCallback(async (currentConversation: AdminSupportConversation) => {
    try {
      await adminSupportApi.markRead(conversationId);
      const readConversation = { ...currentConversation, unreadCount: 0 };
      setConversation(readConversation);
      onConversationUpdated(readConversation);
    } catch {
      // Read state is retried whenever the persisted conversation is opened again.
    }
  }, [conversationId, onConversationUpdated]);

  const loadLatest = useCallback(
    async (initial = false) => {
      if (initial) {
        setLoading(true);
        setError("");
      }
      try {
        const history = await adminSupportApi.getMessages(conversationId, null, 50);
        if (currentConversationRef.current !== conversationId) {
          return;
        }
        applyConversation(history.conversation);
        const currentMessages = messagesRef.current;
        const currentTail = currentMessages.at(-1)?.sequenceNumber;
        const incomingHead = history.messages.items.at(0)?.sequenceNumber;
        const missedRange = currentTail !== undefined
          && incomingHead !== undefined
          && incomingHead > currentTail + 1;
        if (initial || currentMessages.length === 0 || missedRange) {
          setMessageCursor(history.messages.nextCursor ?? null);
          setHasMore(history.messages.hasMore);
        }
        setMessages((current) => initial
          ? mergeSupportMessages([], history.messages.items)
          : mergeSupportMessages(current, history.messages.items));
        if (history.conversation.unreadCount > 0) {
          void markRead(history.conversation);
        }
      } catch (loadError) {
        if (initial) {
          setError(getApiErrorMessage(loadError, t("support.adminWorkspace.loadError")));
        }
      } finally {
        if (initial && currentConversationRef.current === conversationId) {
          setLoading(false);
        }
      }
    },
    [applyConversation, conversationId, markRead, t],
  );

  useEffect(() => {
    currentConversationRef.current = conversationId;
    setConversation(null);
    setMessages([]);
    messagesRef.current = [];
    setMessageCursor(null);
    setHasMore(false);
    setError("");
    setActionError("");
    setActionMessage("");
    setComposer("");
    setPending(null);
    setSuggestedDraft(null);
    setSuggestedAt(null);
    setEditingTitle(false);
    void loadLatest(true);
  }, [conversationId, loadLatest]);

  useEffect(() => {
    void subscribeToConversation(conversationId).catch(() => {
      // Persisted HTTP polling continues when a realtime subscription is interrupted.
    });
    return () => {
      void unsubscribeFromConversation(conversationId).catch(() => {
        // Connection teardown may cancel this invocation after navigation or logout.
      });
    };
  }, [conversationId, subscribeToConversation, unsubscribeFromConversation]);

  useEffect(() => {
    if (realtimeNotification?.conversationId === conversationId) {
      void loadLatest(false);
    }
  }, [conversationId, loadLatest, realtimeNotification]);

  useEffect(() => {
    const delay = realtimeState === "connected" ? 30_000 : 8_000;
    const interval = window.setInterval(() => {
      if (!document.hidden) {
        void loadLatest(false);
      }
    }, delay);
    return () => window.clearInterval(interval);
  }, [loadLatest, realtimeState]);

  useEffect(() => {
    if (!confirmClose) {
      return;
    }

    const returnFocus = closeTriggerRef.current;
    const fallbackFocus = workspaceRef.current;
    requestAnimationFrame(() => closeCancelButtonRef.current?.focus());
    const handleKeyDown = (event: KeyboardEvent) => {
      if (event.key === "Escape" && !closingRef.current) {
        setConfirmClose(false);
        return;
      }

      if (event.key !== "Tab" || !closeDialogRef.current) {
        return;
      }

      const focusable = [...closeDialogRef.current.querySelectorAll<HTMLElement>(
        'button:not([disabled]), textarea:not([disabled]), input:not([disabled]), [tabindex]:not([tabindex="-1"])',
      )];
      const first = focusable[0];
      const last = focusable.at(-1);
      if (first && last && event.shiftKey && document.activeElement === first) {
        event.preventDefault();
        last.focus();
      } else if (first && last && !event.shiftKey && document.activeElement === last) {
        event.preventDefault();
        first.focus();
      }
    };

    window.addEventListener("keydown", handleKeyDown);
    return () => {
      window.removeEventListener("keydown", handleKeyDown);
      requestAnimationFrame(() => {
        if (returnFocus?.isConnected) {
          returnFocus.focus({ preventScroll: true });
        } else {
          fallbackFocus?.focus({ preventScroll: true });
        }
      });
    };
  }, [confirmClose]);

  const loadOlder = async () => {
    if (!hasMore || loadingOlder) {
      return;
    }
    setLoadingOlder(true);
    setActionError("");
    try {
      const history = await adminSupportApi.getMessages(conversationId, messageCursor, 50);
      setMessages((current) => mergeSupportMessages(current, history.messages.items));
      setMessageCursor(history.messages.nextCursor ?? null);
      setHasMore(history.messages.hasMore);
      applyConversation(history.conversation);
    } catch (loadError) {
      setActionError(getApiErrorMessage(loadError, t("support.adminWorkspace.olderError")));
    } finally {
      setLoadingOlder(false);
    }
  };

  const claim = async () => {
    setClaiming(true);
    setActionError("");
    setActionMessage("");
    try {
      const updated = await adminSupportApi.claim(conversationId);
      applyConversation(updated);
      setActionMessage(t("support.adminWorkspace.claimSuccess"));
    } catch (claimError) {
      setActionError(getApiErrorMessage(claimError, t("support.adminWorkspace.claimError")));
    } finally {
      setClaiming(false);
    }
  };

  const send = async (content: string, existingClientId?: string) => {
    if (pending?.state === "sending") {
      return;
    }
    const trimmed = content.trim();
    if (!trimmed) {
      return;
    }
    const clientMessageId = existingClientId ?? crypto.randomUUID();
    setPending({ content: trimmed, clientMessageId, state: "sending" });
    setActionError("");
    setActionMessage("");
    if (!existingClientId) {
      setComposer("");
    }
    try {
      const response = await adminSupportApi.sendMessage(conversationId, { clientMessageId, content: trimmed });
      setMessages((current) => mergeSupportMessages(current, [response.message]));
      applyConversation(response.conversation);
      setPending(null);
    } catch (sendError) {
      setPending({
        content: trimmed,
        clientMessageId,
        state: "failed",
        error: getApiErrorMessage(sendError, t("support.adminWorkspace.sendError")),
      });
    }
  };

  const resolveConversation = async () => {
    setResolving(true);
    setActionError("");
    try {
      const updated = await adminSupportApi.resolve(conversationId);
      applyConversation(updated);
      setActionMessage(t("support.adminWorkspace.resolveSuccess"));
    } catch (resolveError) {
      setActionError(getApiErrorMessage(resolveError, t("support.adminWorkspace.resolveError")));
    } finally {
      setResolving(false);
    }
  };

  const closeConversation = async () => {
    setClosing(true);
    setActionError("");
    try {
      const updated = await adminSupportApi.close(conversationId);
      applyConversation(updated);
      setConfirmClose(false);
      setActionMessage(t("support.adminWorkspace.closeSuccess"));
    } catch (closeError) {
      setActionError(getApiErrorMessage(closeError, t("support.adminWorkspace.closeError")));
    } finally {
      setClosing(false);
    }
  };

  const saveTitle = async () => {
    const title = titleDraft.trim();
    if (!title || !conversation || title === conversation.title) {
      setEditingTitle(false);
      return;
    }
    setSavingTitle(true);
    setActionError("");
    try {
      const updated = await adminSupportApi.updateTitle(conversationId, title);
      applyConversation(updated);
      setEditingTitle(false);
    } catch (titleError) {
      setActionError(getApiErrorMessage(titleError, t("support.adminWorkspace.titleError")));
    } finally {
      setSavingTitle(false);
    }
  };

  const generateSuggestion = async () => {
    setSuggesting(true);
    setActionError("");
    try {
      const suggestion = await adminSupportApi.generateSuggestedReply(conversationId);
      setSuggestedDraft(suggestion.draft);
      setSuggestedAt(suggestion.generatedAt);
    } catch (suggestionError) {
      setActionError(getApiErrorMessage(suggestionError, t("support.adminWorkspace.suggestionError")));
    } finally {
      setSuggesting(false);
    }
  };

  const insertText = (text: string) => {
    setComposer((current) => current.trim() ? `${current.trimEnd()}\n\n${text}` : text);
    setShowQuickReplies(false);
    requestAnimationFrame(() => document.getElementById("admin-support-composer")?.focus());
  };

  if (loading) {
    return (
      <div className="flex h-full min-h-0 flex-col" role="status" aria-label={t("support.adminWorkspace.loading")}>
        <div className="border-b border-border-subtle p-5"><div className="skeleton h-8 w-2/3" /><div className="mt-3 skeleton h-5 w-1/3" /></div>
        <div className="flex-1 space-y-4 p-5"><div className="skeleton h-24 w-4/5 rounded-2xl" /><div className="ms-auto skeleton h-20 w-3/4 rounded-2xl" /><div className="skeleton h-28 w-4/5 rounded-2xl" /></div>
      </div>
    );
  }

  if (!conversation || error) {
    return (
      <div className="flex h-full min-h-0 flex-col items-center justify-center p-8 text-center" role="alert">
        <span className="icon-tile-neutral"><AlertCircle aria-hidden="true" size={20} /></span>
        <h2 className="mt-4 text-base font-semibold text-ink-900">{t("support.adminWorkspace.unavailable")}</h2>
        <p className="mt-2 max-w-sm text-sm leading-6 text-ink-500">{error || t("support.adminWorkspace.unavailableCopy")}</p>
        <button type="button" className="btn-primary mt-5" onClick={() => void loadLatest(true)}><RefreshCw aria-hidden="true" size={15} />{t("actions.retry")}</button>
      </div>
    );
  }

  const canSend = conversation.status === "ADMIN_ACTIVE" && conversation.isAssignedToCurrentAdmin;
  const canClaim = conversation.status === "WAITING_FOR_ADMIN" && !conversation.isAssigned;
  const canResolve = conversation.status === "ADMIN_ACTIVE" && conversation.isAssignedToCurrentAdmin;
  const canClose = conversation.isAssignedToCurrentAdmin
    && (conversation.status === "ADMIN_ACTIVE" || conversation.status === "RESOLVED");
  const ownerLabel = conversation.owner.ownerType === "ANONYMOUS"
    ? t("support.common.anonymous")
    : conversation.owner.fullName || conversation.owner.email || t("support.common.userNumber", { id: formatNumber(conversation.owner.userId ?? 0) });

  return (
    <div ref={workspaceRef} tabIndex={-1} className="relative flex h-full min-h-0 flex-col bg-surface-muted/30 focus:outline-none">
      <header className="border-b border-border-subtle bg-white px-4 py-4 sm:px-5">
        <div className="flex flex-col gap-3 sm:flex-row sm:items-start sm:justify-between">
          <div className="flex min-w-0 items-start gap-2.5">
            <button type="button" className="btn-icon size-9 min-h-9 lg:hidden" onClick={onBack} aria-label={t("support.adminWorkspace.backAria")}><ArrowLeft aria-hidden="true" className="directional-icon" size={16} /></button>
            <div className="min-w-0">
              {editingTitle ? (
                <div className="flex min-w-0 items-center gap-2">
                  <input
                    dir="auto"
                    className="input support-composer-textarea min-h-9 py-1.5 text-sm font-semibold"
                    value={titleDraft}
                    onChange={(event) => setTitleDraft(event.target.value)}
                    onKeyDown={(event) => {
                      if (event.key === "Enter") void saveTitle();
                      if (event.key === "Escape") { setEditingTitle(false); setTitleDraft(conversation.title); }
                    }}
                    maxLength={160}
                    autoFocus
                    disabled={savingTitle}
                  />
                  <button type="button" className="btn-icon size-9 min-h-9" onClick={() => void saveTitle()} disabled={savingTitle} aria-label={t("support.adminWorkspace.saveTitleAria")}>
                    {savingTitle ? <LoaderCircle aria-hidden="true" className="animate-spin" size={14} /> : <Save aria-hidden="true" size={14} />}
                  </button>
                </div>
              ) : (
                <div className="flex min-w-0 items-center gap-2">
                  <BidiText text={conversation.title} className="block truncate text-base font-semibold text-ink-950" />
                  <button type="button" className="inline-flex size-7 shrink-0 items-center justify-center rounded-lg text-ink-400 hover:bg-brand-50 hover:text-brand-700" onClick={() => setEditingTitle(true)} aria-label={t("support.adminWorkspace.editTitleAria")}><Pencil aria-hidden="true" size={13} /></button>
                </div>
              )}
              <div className="mt-1 flex min-w-0 flex-wrap items-center gap-x-3 gap-y-1 text-[11px] text-ink-500">
                <span className="inline-flex min-w-0 items-center gap-1"><UserRound aria-hidden="true" size={12} /><BidiText text={ownerLabel} className="max-w-48 truncate" /></span>
                {conversation.owner.email && <BidiText text={conversation.owner.email} className="max-w-52 truncate" />}
                {conversation.category && <BidiText text={getSupportCategoryLabel(conversation.category)} className="badge-brand max-w-40 truncate px-2 py-0.5 text-[10px]" />}
              </div>
            </div>
          </div>

          <div className="flex shrink-0 flex-wrap items-center justify-end gap-2">
            <SupportStatusBadge status={conversation.status} />
            {canClaim && (
              <button type="button" className="btn-primary min-h-9 px-3 py-1.5 text-xs" onClick={() => void claim()} disabled={claiming}>
                {claiming ? <LoaderCircle aria-hidden="true" className="animate-spin" size={14} /> : <Headphones aria-hidden="true" size={14} />}
                {claiming ? t("support.adminWorkspace.claiming") : t("support.adminWorkspace.claim")}
              </button>
            )}
          </div>
        </div>

        <div className="mt-3 flex flex-wrap items-center justify-between gap-2 border-t border-border-subtle pt-3">
          <div className="flex items-center gap-2 text-[11px] text-ink-500">
            <Clock3 aria-hidden="true" size={12} />
            {t("support.adminWorkspace.lastActivity", { date: formatSupportDateTime(conversation.updatedAt) })}
            {conversation.isAssigned && !conversation.isAssignedToCurrentAdmin && <span className="badge-warning px-2 py-0.5 text-[10px]">{t("support.adminWorkspace.assignedElsewhere")}</span>}
          </div>
          {(canResolve || canClose) && (
            <div className="flex items-center gap-1.5">
              {canResolve && (
                <button type="button" className="btn-ghost min-h-8 px-2.5 py-1 text-[11px] text-status-success hover:bg-emerald-50 hover:text-emerald-800" onClick={() => void resolveConversation()} disabled={resolving || closing}>
                  {resolving ? <LoaderCircle aria-hidden="true" className="animate-spin" size={12} /> : <CheckCircle2 aria-hidden="true" size={12} />}
                  {t("support.adminWorkspace.resolve")}
                </button>
              )}
              {canClose && (
                <button ref={closeTriggerRef} type="button" className="btn-ghost min-h-8 px-2.5 py-1 text-[11px] text-status-danger hover:bg-red-50 hover:text-status-danger" onClick={() => setConfirmClose(true)} disabled={resolving || closing}>
                  <LockKeyhole aria-hidden="true" size={12} />
                  {t("support.adminWorkspace.close")}
                </button>
              )}
            </div>
          )}
        </div>
      </header>

      {(realtimeState === "reconnecting" || realtimeState === "disconnected") && (
        <div className="flex items-center justify-center gap-2 border-b border-amber-200 bg-amber-50 px-4 py-2 text-[11px] font-medium text-amber-900" role="status">
          <WifiOff aria-hidden="true" size={13} />
          {realtimeState === "reconnecting"
            ? t("support.adminWorkspace.reconnecting")
            : t("support.adminWorkspace.paused")}
        </div>
      )}

      {conversation.aiHandoffSummary && (
        <section className="mx-4 mt-3 rounded-control border border-violet-200 bg-violet-50/80 p-3 sm:mx-5" aria-labelledby="handoff-summary-title">
          <div className="flex items-start gap-2.5">
            <span className="mt-0.5 inline-flex size-7 shrink-0 items-center justify-center rounded-lg bg-violet-100 text-violet-700"><Sparkles aria-hidden="true" size={14} /></span>
            <div className="min-w-0">
              <h3 id="handoff-summary-title" className="text-xs font-semibold text-violet-950">{t("support.adminWorkspace.handoffTitle")}</h3>
              <BidiText text={conversation.aiHandoffSummary} className="mt-1 block whitespace-pre-wrap font-reading text-xs leading-5 text-violet-900" />
              {conversation.aiHandoffReason && <BidiText text={t("support.adminWorkspace.handoffReason", { reason: conversation.aiHandoffReason })} className="mt-1 block font-reading text-[10px] text-violet-700" />}
            </div>
          </div>
        </section>
      )}

      {(actionError || actionMessage) && (
        <div className={`mx-4 mt-3 flex items-start gap-2 rounded-control border px-3 py-2 text-xs leading-5 sm:mx-5 ${actionError ? "border-status-danger/20 bg-red-50 text-status-danger" : "border-status-success/20 bg-emerald-50 text-emerald-800"}`} role={actionError ? "alert" : "status"}>
          {actionError ? <AlertCircle aria-hidden="true" className="mt-0.5" size={13} /> : <Check aria-hidden="true" className="mt-0.5" size={13} />}
          <span>{actionError || actionMessage}</span>
        </div>
      )}

      <SupportMessageList
        key={conversationId}
        messages={messages}
        loading={false}
        hasMore={hasMore}
        loadingOlder={loadingOlder}
        onLoadOlder={loadOlder}
        perspective="admin"
        pending={pending}
        onRetryPending={pending?.state === "failed" ? () => void send(pending.content, pending.clientMessageId) : undefined}
        className="min-h-0"
      />

      {suggestedDraft !== null && (
        <section className="mx-3 mb-2 rounded-control border border-brand-200 bg-brand-50 p-3 sm:mx-4" aria-labelledby="suggested-reply-title">
          <div className="flex items-center justify-between gap-3">
            <h3 id="suggested-reply-title" className="inline-flex items-center gap-1.5 text-xs font-semibold text-brand-900"><Lightbulb aria-hidden="true" size={13} />{t("support.adminWorkspace.suggestionTitle")}</h3>
            {suggestedAt && <time dateTime={suggestedAt} className="text-[10px] text-brand-700">{t("support.adminWorkspace.generatedAt", { time: formatSupportTime(suggestedAt) })}</time>}
          </div>
          <textarea aria-label={t("support.adminWorkspace.suggestionAria")} dir="auto" className="input support-composer-textarea mt-2 min-h-20 bg-white font-reading text-xs leading-5" value={suggestedDraft} onChange={(event) => setSuggestedDraft(event.target.value)} maxLength={4_000} />
          <div className="mt-2 flex justify-end gap-2">
            <button type="button" className="btn-ghost min-h-8 px-3 py-1 text-xs" onClick={() => { setSuggestedDraft(null); setSuggestedAt(null); }}><X aria-hidden="true" size={12} />{t("support.adminWorkspace.ignore")}</button>
            <button type="button" className="btn-primary min-h-8 px-3 py-1 text-xs" onClick={() => { insertText(suggestedDraft); setSuggestedDraft(null); setSuggestedAt(null); }} disabled={!suggestedDraft.trim()}><Check aria-hidden="true" size={12} />{t("support.adminWorkspace.useInComposer")}</button>
          </div>
        </section>
      )}

      <div className="relative border-t border-border-subtle bg-white px-3 py-3 sm:px-4">
        {canSend ? (
          <>
            <div className="mb-2 flex flex-wrap items-center justify-between gap-2">
              <div className="flex items-center gap-1.5">
                <button type="button" className="inline-flex min-h-8 items-center gap-1.5 rounded-pill border border-border-subtle px-2.5 text-[11px] font-semibold text-ink-600 hover:border-brand-200 hover:bg-brand-50 hover:text-brand-700" onClick={() => setShowQuickReplies((current) => !current)} aria-expanded={showQuickReplies}>
                  <MessageSquareQuote aria-hidden="true" size={12} />{t("support.adminWorkspace.quickReplies")}<ChevronDown aria-hidden="true" size={11} />
                </button>
                <button type="button" className="inline-flex min-h-8 items-center gap-1.5 rounded-pill px-2.5 text-[11px] font-semibold text-violet-700 hover:bg-violet-50 disabled:opacity-50" onClick={() => void generateSuggestion()} disabled={suggesting}>
                  {suggesting ? <LoaderCircle aria-hidden="true" className="animate-spin" size={12} /> : <Sparkles aria-hidden="true" size={12} />}
                  {suggesting ? t("support.adminWorkspace.generating") : t("support.adminWorkspace.suggest")}
                </button>
              </div>
              <span className="text-[10px] text-ink-500">{t("support.adminWorkspace.autoSendNote")}</span>
            </div>

            {showQuickReplies && (
              <div className="support-message-scroll absolute bottom-full start-3 end-3 z-20 mb-2 max-h-52 overflow-y-auto rounded-control border border-border-subtle bg-white p-2 shadow-floating sm:start-4 sm:end-auto sm:w-80">
                {quickReplies.length === 0 ? (
                  <p className="p-3 text-center text-xs leading-5 text-ink-500">{t("support.adminWorkspace.noQuickReplies")}</p>
                ) : quickReplies.map((reply) => (
                  <button key={reply.id} type="button" className="w-full rounded-xl p-2.5 text-start hover:bg-brand-50" onClick={() => insertText(reply.content)}>
                    <BidiText text={reply.title} className="block truncate text-xs font-semibold text-ink-900" />
                    <BidiText text={reply.content} className="mt-1 block truncate font-reading text-[11px] text-ink-500" />
                  </button>
                ))}
              </div>
            )}

            <form className="flex items-end gap-2" onSubmit={(event) => { event.preventDefault(); void send(composer); }}>
              <label className="sr-only" htmlFor="admin-support-composer">{t("support.adminWorkspace.replyLabel")}</label>
              <textarea
                id="admin-support-composer"
                dir="auto"
                rows={1}
                className="input support-composer-textarea support-composer-compact max-h-36 min-h-11 flex-1 resize-none font-reading"
                value={composer}
                onChange={(event) => setComposer(event.target.value)}
                onKeyDown={(event) => {
                  if (event.key === "Enter" && !event.shiftKey && !event.nativeEvent.isComposing) {
                    event.preventDefault();
                    void send(composer);
                  }
                }}
                placeholder={t("support.adminWorkspace.replyPlaceholder")}
                maxLength={4_000}
                disabled={pending?.state === "sending"}
              />
              <button type="submit" className="btn-primary size-11 min-h-11 px-0" aria-label={t("support.adminWorkspace.sendReplyAria")} disabled={pending?.state === "sending" || !composer.trim()}>
                {pending?.state === "sending" ? <LoaderCircle aria-hidden="true" className="animate-spin" size={16} /> : <Send aria-hidden="true" size={16} />}
              </button>
            </form>
          </>
        ) : (
          <div className="flex items-start gap-2.5 rounded-control border border-border-subtle bg-surface-muted/70 p-3 text-xs leading-5 text-ink-600">
            {conversation.status === "WAITING_FOR_ADMIN" ? <Headphones aria-hidden="true" className="mt-0.5" size={14} /> : conversation.status === "AI_ACTIVE" ? <Bot aria-hidden="true" className="mt-0.5" size={14} /> : <LockKeyhole aria-hidden="true" className="mt-0.5" size={14} />}
            <p>
              {conversation.status === "WAITING_FOR_ADMIN"
                ? conversation.isAssigned ? t("support.adminWorkspace.assignedNotice") : t("support.adminWorkspace.claimNotice")
                : conversation.status === "AI_ACTIVE"
                  ? t("support.adminWorkspace.aiNotice")
                  : conversation.status === "RESOLVED"
                    ? t("support.adminWorkspace.resolvedNotice")
                    : t("support.adminWorkspace.closedNotice")}
            </p>
          </div>
        )}
      </div>

      {confirmClose && (
        <div className="absolute inset-0 z-30 flex items-center justify-center bg-ink-950/35 p-5 backdrop-blur-sm">
          <div ref={closeDialogRef} role="alertdialog" aria-modal="true" aria-labelledby="confirm-close-title" aria-describedby="confirm-close-description" className="w-full max-w-sm rounded-card border border-white/80 bg-white p-5 shadow-floating">
            <span className="icon-tile-neutral"><CircleX aria-hidden="true" size={19} /></span>
            <h2 id="confirm-close-title" className="mt-4 text-base font-semibold text-ink-950">{t("support.adminWorkspace.closeTitle")}</h2>
            <p id="confirm-close-description" className="mt-2 text-sm leading-6 text-ink-500">{t("support.adminWorkspace.closeCopy")}</p>
            <div className="mt-5 flex justify-end gap-2">
              <button ref={closeCancelButtonRef} type="button" className="btn-secondary" onClick={() => setConfirmClose(false)} disabled={closing}>{t("actions.cancel")}</button>
              <button type="button" className="btn-danger" onClick={() => void closeConversation()} disabled={closing}>
                {closing ? <LoaderCircle aria-hidden="true" className="animate-spin" size={15} /> : <LockKeyhole aria-hidden="true" size={15} />}
                {closing ? t("support.adminWorkspace.closing") : t("support.adminWorkspace.closeConversation")}
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
