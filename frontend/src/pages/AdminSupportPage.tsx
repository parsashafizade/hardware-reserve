import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import {
  AlertCircle,
  Headphones,
  Inbox,
  MessageCircleMore,
  MessageSquareQuote,
  RefreshCw,
  Search,
  WifiOff,
} from "lucide-react";
import { useNavigate, useParams, useSearchParams } from "react-router-dom";
import { useTranslation } from "react-i18next";
import { adminSupportApi } from "../api/adminSupportApi";
import { AdminNavigation } from "../components/admin/AdminNavigation";
import { AdminSupportConversationList } from "../components/admin/support/AdminSupportConversationList";
import { AdminSupportWorkspace } from "../components/admin/support/AdminSupportWorkspace";
import { QuickReplyManager } from "../components/admin/support/QuickReplyManager";
import { PageHeader } from "../components/ui/PageHeader";
import { useSupportRealtime } from "../support/useSupportRealtime";
import type {
  AdminSupportConversation,
  SupportConversationStatus,
  SupportQuickReply,
} from "../types/support";
import { getApiErrorMessage } from "../utils/errors";
import { SUPPORT_CATEGORIES, getSupportCategoryLabel, getSupportStatusLabel } from "../utils/support";
import { useLocale } from "../i18n/useLocale";

const supportStatuses = new Set<SupportConversationStatus>([
  "WAITING_FOR_ADMIN",
  "ADMIN_ACTIVE",
  "AI_ACTIVE",
  "RESOLVED",
  "CLOSED",
]);

export function AdminSupportPage() {
  const { t } = useTranslation();
  const { formatNumber } = useLocale();
  const { conversationId } = useParams<{ conversationId: string }>();
  const navigate = useNavigate();
  const [searchParams] = useSearchParams();
  const realtime = useSupportRealtime();
  const [conversations, setConversations] = useState<AdminSupportConversation[]>([]);
  const [status, setStatus] = useState<"" | SupportConversationStatus>(() => {
    const requestedStatus = searchParams.get("status") as SupportConversationStatus | null;
    return requestedStatus && supportStatuses.has(requestedStatus) ? requestedStatus : "";
  });
  const [category, setCategory] = useState("");
  const [search, setSearch] = useState("");
  const cursorRef = useRef<string | null>(null);
  const [hasMore, setHasMore] = useState(false);
  const [loading, setLoading] = useState(true);
  const [loadingMore, setLoadingMore] = useState(false);
  const [error, setError] = useState("");
  const [unreadCount, setUnreadCount] = useState(0);
  const [quickReplies, setQuickReplies] = useState<SupportQuickReply[]>([]);
  const [quickRepliesError, setQuickRepliesError] = useState("");
  const [quickReplyManagerOpen, setQuickReplyManagerOpen] = useState(false);
  const realtimeRefreshTimer = useRef<number | undefined>(undefined);
  const listRequestIdRef = useRef(0);
  const statusFilters = useMemo<Array<{ value: "" | SupportConversationStatus; label: string }>>(() => [
    { value: "", label: t("support.adminInbox.all") },
    { value: "WAITING_FOR_ADMIN", label: t("support.adminInbox.waiting") },
    { value: "ADMIN_ACTIVE", label: t("support.adminInbox.adminActive") },
    { value: "AI_ACTIVE", label: t("support.adminInbox.aiHandling") },
    { value: "RESOLVED", label: t("support.adminInbox.resolved") },
    { value: "CLOSED", label: t("support.adminInbox.closed") },
  ], [t]);

  const loadUnread = useCallback(async () => {
    try {
      const result = await adminSupportApi.getUnreadCount();
      setUnreadCount(result.unreadMessages);
    } catch {
      // Inbox records still contain per-conversation unread state.
    }
  }, []);

  const loadQuickReplies = useCallback(async () => {
    try {
      const replies = await adminSupportApi.getQuickReplies(true);
      setQuickReplies(replies);
      setQuickRepliesError("");
    } catch (loadError) {
      setQuickRepliesError(getApiErrorMessage(loadError, t("support.adminInbox.quickRepliesUnavailable")));
    }
  }, [t]);

  const loadConversations = useCallback(
    async (reset = true) => {
      const requestId = ++listRequestIdRef.current;
      if (reset) {
        setLoading(true);
        setLoadingMore(false);
        setError("");
      } else {
        setLoadingMore(true);
      }
      try {
        const page = await adminSupportApi.getConversations({
          status: status || undefined,
          category: category || undefined,
          cursor: reset ? null : cursorRef.current,
          pageSize: 30,
        });
        if (requestId !== listRequestIdRef.current) {
          return;
        }
        setConversations((current) => {
          if (reset) {
            return page.items;
          }
          const byId = new Map(current.map((item) => [item.id, item]));
          for (const item of page.items) {
            byId.set(item.id, item);
          }
          return [...byId.values()];
        });
        cursorRef.current = page.nextCursor ?? null;
        setHasMore(page.hasMore);
      } catch (loadError) {
        if (requestId === listRequestIdRef.current) {
          setError(getApiErrorMessage(loadError, t("support.adminInbox.inboxError")));
        }
      } finally {
        if (requestId === listRequestIdRef.current) {
          setLoading(false);
          setLoadingMore(false);
        }
      }
    },
    [category, status, t],
  );

  useEffect(() => {
    cursorRef.current = null;
    void loadConversations(true);
  }, [loadConversations]);

  useEffect(() => {
    void loadUnread();
    void loadQuickReplies();
    const interval = window.setInterval(() => {
      if (!document.hidden) {
        void loadUnread();
        void loadConversations(true);
      }
    }, 30_000);
    const handleVisibility = () => {
      if (!document.hidden) {
        void loadUnread();
        void loadConversations(true);
      }
    };
    document.addEventListener("visibilitychange", handleVisibility);
    return () => {
      window.clearInterval(interval);
      document.removeEventListener("visibilitychange", handleVisibility);
    };
  }, [loadConversations, loadQuickReplies, loadUnread]);

  useEffect(() => {
    if (!realtime.notification) {
      return;
    }
    if (realtimeRefreshTimer.current) {
      window.clearTimeout(realtimeRefreshTimer.current);
    }
    realtimeRefreshTimer.current = window.setTimeout(() => {
      void loadConversations(true);
      void loadUnread();
    }, 180);
    return () => {
      if (realtimeRefreshTimer.current) {
        window.clearTimeout(realtimeRefreshTimer.current);
      }
    };
  }, [loadConversations, loadUnread, realtime.notification]);

  const visibleConversations = useMemo(() => {
    const query = search.trim().toLocaleLowerCase();
    if (!query) {
      return conversations;
    }
    return conversations.filter((conversation) => {
      const searchable = [
        conversation.title,
        conversation.category,
        conversation.lastMessage?.preview,
        conversation.owner.fullName,
        conversation.owner.email,
      ].filter(Boolean).join(" ").toLocaleLowerCase();
      return searchable.includes(query);
    });
  }, [conversations, search]);

  const handleConversationUpdated = useCallback((updated: AdminSupportConversation) => {
    setConversations((current) => current.map((item) => item.id === updated.id ? updated : item));
    void loadUnread();
  }, [loadUnread]);

  const activeQuickReplies = useMemo(
    () => quickReplies.filter((reply) => reply.isActive).sort((left, right) => left.sortOrder - right.sortOrder),
    [quickReplies],
  );

  return (
    <div className="page-stack">
      <div className={conversationId ? "max-lg:hidden" : ""}>
        <AdminNavigation />
      </div>
      <PageHeader
        eyebrow={t("support.adminInbox.eyebrow")}
        title={t("support.adminInbox.title")}
        description={t("support.adminInbox.description")}
        icon={Headphones}
        className={conversationId ? "max-lg:hidden" : ""}
        actions={
          <div className="flex flex-wrap items-center gap-2">
            {(realtime.state === "reconnecting" || realtime.state === "disconnected") && (
              <span className="badge-warning"><WifiOff aria-hidden="true" size={13} />{realtime.state === "reconnecting" ? t("support.common.realtimeReconnecting") : t("support.common.realtimePaused")}</span>
            )}
            {unreadCount > 0 && <span className="badge-info">{t("support.common.unread", { count: unreadCount, formattedCount: formatNumber(unreadCount) })}</span>}
            <button type="button" className="btn-secondary" onClick={() => setQuickReplyManagerOpen(true)}>
              <MessageSquareQuote aria-hidden="true" size={16} />
              {t("support.adminInbox.manageQuickReplies")}
            </button>
          </div>
        }
      />

      {quickRepliesError && !conversationId && (
        <div className="alert-warning flex items-start gap-2.5" role="status">
          <AlertCircle aria-hidden="true" className="mt-0.5" size={16} />
          <p>{quickRepliesError} {t("support.adminInbox.handlingAvailable")}</p>
        </div>
      )}

      <section className={`overflow-hidden rounded-panel border border-border-subtle bg-white shadow-lift lg:grid lg:h-[min(56rem,calc(100dvh-12rem))] lg:min-h-[44rem] lg:grid-cols-[22rem_minmax(0,1fr)] ${conversationId ? "max-lg:h-[calc(100dvh-7rem)] max-lg:min-h-0" : ""}`} aria-label={t("support.adminInbox.workspaceAria")}>
        <aside className={`${conversationId ? "hidden lg:flex" : "flex"} min-h-[calc(100dvh-7rem)] flex-col border-e border-border-subtle bg-surface-muted/45 lg:min-h-[42rem]`} aria-label={t("support.adminInbox.conversationsAria")}>
          <div className="border-b border-border-subtle bg-white p-3.5">
            <div className="relative">
              <Search aria-hidden="true" className="pointer-events-none absolute start-3 top-1/2 -translate-y-1/2 text-ink-400" size={15} />
              <label className="sr-only" htmlFor="support-inbox-search">{t("support.adminInbox.searchLabel")}</label>
              <input
                id="support-inbox-search"
                dir="auto"
                className="input support-composer-textarea min-h-10 py-2 ps-9 text-xs"
                value={search}
                onChange={(event) => setSearch(event.target.value)}
                placeholder={t("support.adminInbox.searchPlaceholder")}
              />
            </div>

            <div className="mt-3 grid grid-cols-2 gap-2">
              <label className="field gap-1">
                <span className="sr-only">{t("support.adminInbox.statusLabel")}</span>
                <select className="input min-h-10 py-2 text-xs" value={status} onChange={(event) => setStatus(event.target.value as "" | SupportConversationStatus)}>
                  {statusFilters.map((item) => <option key={item.value || "all"} value={item.value}>{item.value ? getSupportStatusLabel(item.value) : item.label}</option>)}
                </select>
              </label>
              <label className="field gap-1">
                <span className="sr-only">{t("support.adminInbox.categoryLabel")}</span>
                <select className="input min-h-10 py-2 text-xs" value={category} onChange={(event) => setCategory(event.target.value)}>
                  <option value="">{t("support.category.all")}</option>
                  {SUPPORT_CATEGORIES.map((item) => <option key={item} value={item}>{getSupportCategoryLabel(item)}</option>)}
                </select>
              </label>
            </div>

            <div className="support-message-scroll mt-3 flex gap-1 overflow-x-auto pb-1" role="group" aria-label={t("support.adminInbox.quickFiltersAria")}>
              {statusFilters.slice(0, 5).map((item) => (
                <button key={item.value || "all"} type="button" aria-pressed={status === item.value} className={`min-h-8 shrink-0 rounded-pill px-2.5 text-[10px] font-semibold transition duration-base ${status === item.value ? "bg-brand-600 text-white" : "bg-surface-muted text-ink-500 hover:bg-brand-50 hover:text-brand-700"}`} onClick={() => setStatus(item.value)}>
                  {item.label}
                </button>
              ))}
            </div>
          </div>

          {error && conversations.length === 0 ? (
            <div className="flex flex-1 flex-col items-center justify-center p-6 text-center" role="alert">
              <span className="icon-tile-neutral"><AlertCircle aria-hidden="true" size={19} /></span>
              <h2 className="mt-4 text-sm font-semibold text-ink-900">{t("support.adminInbox.unavailable")}</h2>
              <p className="mt-2 text-xs leading-5 text-ink-500">{error}</p>
              <button type="button" className="btn-secondary mt-4" onClick={() => void loadConversations(true)}><RefreshCw aria-hidden="true" size={14} />{t("actions.retry")}</button>
            </div>
          ) : (
            <div className="min-h-0 flex-1">
              <AdminSupportConversationList
                conversations={visibleConversations}
                selectedId={conversationId}
                loading={loading}
                loadingMore={loadingMore}
                hasMore={hasMore && !search.trim() && !loading}
                onSelect={(id) => navigate(`/admin/support/${id}`)}
                onLoadMore={() => void loadConversations(false)}
              />
            </div>
          )}
        </aside>

        <div className={`${conversationId ? "block" : "hidden lg:block"} h-full min-h-0 min-w-0`}>
          {conversationId ? (
            <AdminSupportWorkspace
              conversationId={conversationId}
              quickReplies={activeQuickReplies}
              onBack={() => navigate("/admin/support")}
              onConversationUpdated={handleConversationUpdated}
            />
          ) : (
            <div className="flex h-full min-h-[42rem] flex-col items-center justify-center bg-gradient-to-br from-white via-brand-50/35 to-surface-muted/60 p-8 text-center">
              <span className="flex size-16 items-center justify-center rounded-2xl border border-brand-200 bg-white text-brand-700 shadow-card"><Inbox aria-hidden="true" size={27} /></span>
              <h2 className="mt-5 text-lg font-semibold text-ink-950">{t("support.adminInbox.selectTitle")}</h2>
              <p className="mt-2 max-w-sm text-sm leading-6 text-ink-500">{t("support.adminInbox.selectCopy")}</p>
              <span className="mt-4 inline-flex items-center gap-2 text-xs font-semibold text-brand-700"><MessageCircleMore aria-hidden="true" size={14} />{t("support.adminInbox.loadedCount", { count: conversations.length, formattedCount: formatNumber(conversations.length) })}</span>
            </div>
          )}
        </div>
      </section>

      <QuickReplyManager
        open={quickReplyManagerOpen}
        replies={quickReplies}
        onClose={() => setQuickReplyManagerOpen(false)}
        onChanged={loadQuickReplies}
      />
    </div>
  );
}
