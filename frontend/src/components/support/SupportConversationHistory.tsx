import { useEffect } from "react";
import { ArrowRight, Clock3, LoaderCircle, MessageSquareText, Plus, RefreshCw } from "lucide-react";
import { useTranslation } from "react-i18next";
import { useAuth } from "../../auth/useAuth";
import { useSupport } from "../../support/useSupport";
import { formatSupportRelativeTime, getSupportCategoryLabel } from "../../utils/support";
import { BidiText } from "./BidiText";
import { SupportStatusBadge } from "./SupportStatusBadge";
import { useLocale } from "../../i18n/useLocale";
import { useCurrentTime } from "../../hooks/useCurrentTime";

interface SupportConversationHistoryProps {
  variant?: "widget" | "profile";
}

export function SupportConversationHistory({ variant = "widget" }: SupportConversationHistoryProps) {
  const { t } = useTranslation();
  const { formatNumber } = useLocale();
  const currentTime = useCurrentTime(60_000);
  const { isAuthenticated } = useAuth();
  const {
    conversations,
    conversationsLoading,
    conversationsLoadingMore,
    conversationsError,
    conversationsHasMore,
    loadConversations,
    loadMoreConversations,
    openConversation,
    showNewConversation,
  } = useSupport();

  useEffect(() => {
    void loadConversations(true);
  }, [loadConversations]);

  if (conversationsLoading && conversations.length === 0) {
    return (
      <div className={`space-y-3 ${variant === "widget" ? "p-4 sm:p-5" : ""}`} role="status" aria-label={t("support.history.loading")}>
        {[0, 1, 2].map((item) => <div key={item} className="skeleton h-24 rounded-control" />)}
      </div>
    );
  }

  if (conversationsError && conversations.length === 0) {
    return (
      <div className={`flex h-full flex-col items-center justify-center px-6 py-10 text-center ${variant === "profile" ? "min-h-64" : ""}`} role="alert">
        <span className="icon-tile-neutral"><MessageSquareText aria-hidden="true" size={19} /></span>
        <h3 className="mt-4 text-base font-semibold text-ink-900">{t("support.history.unavailable")}</h3>
        <p className="mt-2 max-w-sm text-sm leading-6 text-ink-500">{conversationsError}</p>
        <button type="button" className="btn-secondary mt-5" onClick={() => void loadConversations(true)}>
          <RefreshCw aria-hidden="true" size={15} />
          {t("actions.retry")}
        </button>
      </div>
    );
  }

  if (conversations.length === 0) {
    return (
      <div className={`flex flex-col items-center justify-center px-6 py-10 text-center ${variant === "profile" ? "min-h-64" : "h-full"}`}>
        <span className="icon-tile"><MessageSquareText aria-hidden="true" size={20} /></span>
        <h3 className="mt-4 text-base font-semibold text-ink-900">{t("support.history.empty")}</h3>
        <p className="mt-2 max-w-sm text-sm leading-6 text-ink-500">
          {isAuthenticated
            ? t("support.history.emptyAuthenticated")
            : t("support.history.emptyGuest")}
        </p>
        <button type="button" className="btn-primary mt-5" onClick={showNewConversation}>
          <Plus aria-hidden="true" size={16} />
          {t("support.history.start")}
        </button>
      </div>
    );
  }

  return (
    <div className={variant === "widget" ? "h-full overflow-y-auto p-3 sm:p-4" : ""}>
      <div className={`grid gap-2.5 ${variant === "profile" ? "md:grid-cols-2" : ""}`}>
        {conversations.map((conversation) => (
          <button
            key={conversation.id}
            type="button"
            onClick={() => void openConversation(conversation.id)}
            className="group min-w-0 rounded-control border border-border-subtle bg-white p-4 text-start shadow-control transition duration-base hover:-translate-y-0.5 hover:border-brand-200 hover:shadow-card"
          >
            <div className="flex min-w-0 items-start justify-between gap-3">
              <div className="min-w-0">
                <BidiText text={conversation.title} className="block truncate text-sm font-semibold text-ink-900" />
                {conversation.category && (
                  <BidiText text={getSupportCategoryLabel(conversation.category)} className="mt-1 block truncate text-xs font-medium text-ink-500" />
                )}
              </div>
              {conversation.unreadCount > 0 && (
                <span dir="ltr" className="inline-flex min-w-6 items-center justify-center rounded-pill bg-brand-600 px-1.5 py-0.5 text-[10px] font-bold text-white" aria-label={t("support.common.unreadMessages", { count: conversation.unreadCount, formattedCount: formatNumber(conversation.unreadCount) })}>
                  {conversation.unreadCount > 99 ? `${formatNumber(99)}+` : formatNumber(conversation.unreadCount)}
                </span>
              )}
            </div>

            {conversation.lastMessage && (
              <BidiText text={conversation.lastMessage.preview} className="mt-2 block truncate font-reading text-xs leading-5 text-ink-500" />
            )}

            <div className="mt-3 flex flex-wrap items-center justify-between gap-2 border-t border-border-subtle/80 pt-3">
              <SupportStatusBadge status={conversation.status} />
              <span className="inline-flex items-center gap-1 text-[11px] font-medium text-ink-500">
                <Clock3 aria-hidden="true" size={11} />
                {formatSupportRelativeTime(conversation.lastMessage?.sentAt ?? conversation.updatedAt, currentTime)}
                <ArrowRight aria-hidden="true" size={12} className="directional-icon ms-0.5 transition-colors group-hover:text-brand-700" />
              </span>
            </div>
          </button>
        ))}
      </div>

      {conversationsHasMore && (
        <div className="mt-4 flex justify-center">
          <button type="button" className="btn-secondary" disabled={conversationsLoadingMore} onClick={() => void loadMoreConversations()}>
            {conversationsLoadingMore ? <LoaderCircle aria-hidden="true" className="animate-spin" size={15} /> : <Plus aria-hidden="true" size={15} />}
            {conversationsLoadingMore ? t("support.common.loading") : t("support.history.loadMore")}
          </button>
        </div>
      )}
    </div>
  );
}
