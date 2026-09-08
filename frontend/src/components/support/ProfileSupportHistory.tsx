import { MessageCircleMore, MessageSquarePlus } from "lucide-react";
import { useTranslation } from "react-i18next";
import { useSupport } from "../../support/useSupport";
import { useAuth } from "../../auth/useAuth";
import { SupportConversationHistory } from "./SupportConversationHistory";
import { useLocale } from "../../i18n/useLocale";

export function ProfileSupportHistory() {
  const { t } = useTranslation();
  const { formatNumber } = useLocale();
  const { isAdmin } = useAuth();
  const { unreadCount, showNewConversation } = useSupport();

  if (isAdmin) {
    return null;
  }

  return (
    <section id="support-conversations" className="card scroll-mt-28" aria-labelledby="support-conversations-title">
      <div className="flex flex-col gap-4 border-b border-border-subtle pb-5 sm:flex-row sm:items-center sm:justify-between">
        <div className="flex items-start gap-3">
          <span className="icon-tile"><MessageCircleMore aria-hidden="true" size={19} /></span>
          <div>
            <p className="section-kicker">{t("support.profile.eyebrow")}</p>
            <div className="mt-1 flex flex-wrap items-center gap-2">
              <h2 id="support-conversations-title" className="card-title">{t("support.profile.title")}</h2>
              {unreadCount > 0 && (
                <span className="badge-info">{t("support.common.unread", { count: unreadCount, formattedCount: formatNumber(unreadCount) })}</span>
              )}
            </div>
            <p className="mt-1 text-sm leading-6 text-ink-500">
              {t("support.profile.description")}
            </p>
          </div>
        </div>
        <button type="button" className="btn-secondary shrink-0" onClick={showNewConversation}>
          <MessageSquarePlus aria-hidden="true" size={16} />
          {t("support.profile.new")}
        </button>
      </div>
      <div className="mt-5">
        <SupportConversationHistory variant="profile" />
      </div>
    </section>
  );
}
