import { Clock3, LoaderCircle, MessageCircleOff, UserRound } from "lucide-react";
import { useTranslation } from "react-i18next";
import type { AdminSupportConversation } from "../../../types/support";
import { formatSupportDateTime, formatSupportRelativeTime } from "../../../utils/support";
import { BidiText } from "../../support/BidiText";
import { SupportStatusBadge } from "../../support/SupportStatusBadge";
import { useLocale } from "../../../i18n/useLocale";

interface AdminSupportConversationListProps {
  conversations: AdminSupportConversation[];
  selectedId?: string;
  loading: boolean;
  loadingMore: boolean;
  hasMore: boolean;
  onSelect: (conversationId: string) => void;
  onLoadMore: () => void;
}

export function AdminSupportConversationList({
  conversations,
  selectedId,
  loading,
  loadingMore,
  hasMore,
  onSelect,
  onLoadMore,
}: AdminSupportConversationListProps) {
  const { t } = useTranslation();
  const { formatNumber } = useLocale();
  if (loading && conversations.length === 0) {
    return (
      <div className="space-y-2.5 p-3" role="status" aria-label={t("support.adminInbox.loadingList")}>
        {[0, 1, 2, 3].map((item) => <div key={item} className="skeleton h-32 rounded-control" />)}
      </div>
    );
  }

  if (conversations.length === 0) {
    return (
      <div className="flex min-h-72 flex-col items-center justify-center px-6 py-10 text-center">
        <span className="icon-tile-neutral"><MessageCircleOff aria-hidden="true" size={19} /></span>
        <h3 className="mt-4 text-sm font-semibold text-ink-900">{t("support.adminInbox.noResults")}</h3>
        <p className="mt-2 max-w-xs text-xs leading-5 text-ink-500">{t("support.adminInbox.noResultsCopy")}</p>
      </div>
    );
  }

  return (
    <div className="support-message-scroll h-full overflow-y-auto overscroll-contain p-2.5">
      <div className="space-y-2">
        {conversations.map((conversation) => {
          const ownerLabel = conversation.owner.ownerType === "ANONYMOUS"
            ? t("support.common.anonymous")
            : conversation.owner.fullName || conversation.owner.email || t("support.common.userNumber", { id: formatNumber(conversation.owner.userId ?? 0) });
          const lastActivity = conversation.lastMessage?.sentAt ?? conversation.updatedAt;

          return (
            <button
              key={conversation.id}
              type="button"
              onClick={() => onSelect(conversation.id)}
              className={`w-full min-w-0 rounded-control border p-3.5 text-start transition duration-base ${selectedId === conversation.id ? "border-brand-300 bg-brand-50 shadow-control" : "border-transparent bg-white hover:border-border-subtle hover:bg-surface-raised"}`}
              aria-current={selectedId === conversation.id ? "true" : undefined}
            >
              <div className="flex min-w-0 items-start justify-between gap-2">
                <BidiText text={conversation.title} className="block min-w-0 flex-1 truncate text-sm font-semibold text-ink-900" />
                {conversation.unreadCount > 0 && (
                  <span dir="ltr" className="inline-flex min-w-5 items-center justify-center rounded-pill bg-brand-600 px-1.5 py-0.5 text-[10px] font-bold text-white" aria-label={t("support.common.unreadMessages", { count: conversation.unreadCount, formattedCount: formatNumber(conversation.unreadCount) })}>
                    {conversation.unreadCount > 99 ? `${formatNumber(99)}+` : formatNumber(conversation.unreadCount)}
                  </span>
                )}
              </div>

              <div className="mt-2 flex min-w-0 items-center gap-1.5 text-[11px] font-medium text-ink-500">
                <UserRound aria-hidden="true" size={12} />
                <BidiText text={ownerLabel} className="block truncate" />
              </div>

              {conversation.lastMessage && (
                <BidiText text={conversation.lastMessage.preview} className="mt-2 block truncate font-reading text-xs leading-5 text-ink-500" />
              )}

              <div className="mt-3 flex flex-wrap items-center justify-between gap-2 border-t border-border-subtle/80 pt-2.5">
                <SupportStatusBadge status={conversation.status} />
                <span className="inline-flex items-center gap-1 text-[10px] font-medium text-ink-500" title={formatSupportDateTime(lastActivity)}>
                  <Clock3 aria-hidden="true" size={11} />
                  {formatSupportRelativeTime(lastActivity)}
                </span>
              </div>
            </button>
          );
        })}
      </div>

      {hasMore && (
        <button type="button" className="btn-secondary mt-3 w-full" disabled={loadingMore} onClick={onLoadMore}>
          {loadingMore && <LoaderCircle aria-hidden="true" className="animate-spin" size={15} />}
          {loadingMore ? t("support.common.loading") : t("support.adminInbox.loadMore")}
        </button>
      )}
    </div>
  );
}
