import { useCallback, useEffect, useRef, useState } from "react";
import { AlertCircle, CheckCircle2, Inbox, LoaderCircle, Megaphone, Search, Send, X } from "lucide-react";
import { useTranslation } from "react-i18next";
import { adminApi } from "../api/adminApi";
import { AdminNavigation } from "../components/admin/AdminNavigation";
import { PageHeader } from "../components/ui/PageHeader";
import { useLocale } from "../i18n/useLocale";
import type {
  AdminNotificationCampaign,
  AdminNotificationHistoryItem,
  AdminNotificationRecipient,
  AdminSendNotificationRequest,
} from "../types/api";
import { getApiErrorMessage } from "../utils/errors";
import { formatDateTime } from "../utils/format";
import {
  buildAdminNotificationRecipients,
  mergeSelectedRecipients,
  removeSelectedRecipient,
} from "../utils/adminNotificationRecipients";

const initialRequest: AdminSendNotificationRequest = {
  recipientScope: "SelectedUsers",
  title: "",
  message: "",
  category: "General",
  confirmBroadcast: false,
};

export function AdminNotificationsPage() {
  const { t } = useTranslation();
  const { formatNumber } = useLocale();
  const [recipientQuery, setRecipientQuery] = useState("");
  const [recipientResults, setRecipientResults] = useState<AdminNotificationRecipient[]>([]);
  const [selectedRecipients, setSelectedRecipients] = useState<Map<number, AdminNotificationRecipient>>(() => new Map());
  const [recipientLoading, setRecipientLoading] = useState(false);
  const [recipientLoadingMore, setRecipientLoadingMore] = useState(false);
  const [recipientError, setRecipientError] = useState("");
  const [recipientPage, setRecipientPage] = useState(1);
  const [recipientTotal, setRecipientTotal] = useState(0);
  const recipientSearchGeneration = useRef(0);
  const [history, setHistory] = useState<AdminNotificationCampaign[]>([]);
  const [deliveries, setDeliveries] = useState<AdminNotificationHistoryItem[]>([]);
  const [request, setRequest] = useState(initialRequest);
  const [loading, setLoading] = useState(true);
  const [sending, setSending] = useState(false);
  const [error, setError] = useState("");
  const [message, setMessage] = useState("");
  const [deliveryLoading, setDeliveryLoading] = useState(true);
  const [deliveryError, setDeliveryError] = useState("");
  const [deliveryPage, setDeliveryPage] = useState(1);
  const [deliveryTotal, setDeliveryTotal] = useState(0);
  const [sourceFilter, setSourceFilter] = useState("");
  const [readFilter, setReadFilter] = useState<"" | "read" | "unread">("");

  const load = useCallback(async () => {
    setLoading(true);
    setError("");
    try {
      const campaigns = await adminApi.getNotificationHistory();
      setHistory(campaigns.items);
    } catch (loadError) {
      setError(getApiErrorMessage(loadError, t("admin.notifications.loadError")));
    } finally {
      setLoading(false);
    }
  }, [t]);

  useEffect(() => {
    void load();
  }, [load]);

  useEffect(() => {
    const generation = ++recipientSearchGeneration.current;
    const normalizedQuery = recipientQuery.trim();
    if (request.recipientScope !== "SelectedUsers" || normalizedQuery.length < 2) {
      setRecipientResults([]);
      setRecipientLoading(false);
      setRecipientLoadingMore(false);
      setRecipientTotal(0);
      setRecipientError("");
      return;
    }

    const controller = new AbortController();
    const timeout = window.setTimeout(async () => {
      if (recipientPage === 1) {
        setRecipientResults([]);
        setRecipientLoading(true);
      } else {
        setRecipientLoadingMore(true);
      }
      setRecipientError("");
      try {
        const response = await adminApi.searchNotificationRecipients(
          { query: normalizedQuery, page: recipientPage, pageSize: 20 },
          controller.signal,
        );
        if (generation === recipientSearchGeneration.current) {
          setRecipientResults((current) => recipientPage === 1
            ? response.items
            : [...new Map([...current, ...response.items].map((item) => [item.id, item])).values()]);
          setRecipientTotal(response.totalCount);
        }
      } catch (searchError) {
        if (!controller.signal.aborted && generation === recipientSearchGeneration.current) {
          setRecipientResults([]);
          setRecipientError(getApiErrorMessage(searchError, t("admin.notifications.searchError")));
        }
      } finally {
        if (generation === recipientSearchGeneration.current) {
          setRecipientLoading(false);
          setRecipientLoadingMore(false);
        }
      }
    }, recipientPage === 1 ? 300 : 0);

    return () => {
      window.clearTimeout(timeout);
      controller.abort();
    };
  }, [recipientPage, recipientQuery, request.recipientScope, t]);

  const loadDeliveries = useCallback(async () => {
    setDeliveryLoading(true);
    setDeliveryError("");
    try {
      const response = await adminApi.getNotificationDeliveries({
        source: sourceFilter || undefined,
        isRead: readFilter ? readFilter === "read" : undefined,
        page: deliveryPage,
        pageSize: 20,
      });
      setDeliveries(response.items);
      setDeliveryTotal(response.totalCount);
    } catch (loadError) {
      setDeliveries([]);
      setDeliveryError(getApiErrorMessage(loadError, t("admin.notifications.deliveryLoadError")));
    } finally {
      setDeliveryLoading(false);
    }
  }, [deliveryPage, readFilter, sourceFilter, t]);

  useEffect(() => {
    void loadDeliveries();
  }, [loadDeliveries]);

  const send = async (event: React.FormEvent) => {
    event.preventDefault();
    const isBroadcast = request.recipientScope === "AllUsers";
    if (isBroadcast && !window.confirm(t("admin.notifications.broadcastConfirm"))) return;

    setSending(true);
    setError("");
    setMessage("");
    try {
      const campaign = await adminApi.sendNotification({
        ...request,
        ...buildAdminNotificationRecipients(request.recipientScope, selectedRecipients),
      });
      setHistory((items) => [campaign, ...items]);
      setRequest((current) => ({
        ...initialRequest,
        recipientScope: current.recipientScope,
      }));
      setSelectedRecipients(new Map());
      setRecipientQuery("");
      setRecipientResults([]);
      setRecipientPage(1);
      setRecipientTotal(0);
      setMessage(
        t("admin.notifications.sent", {
          count: campaign.targetCount,
          formattedCount: formatNumber(campaign.targetCount),
        }),
      );
    } catch (sendError) {
      setError(getApiErrorMessage(sendError, t("admin.notifications.sendError")));
    } finally {
      setSending(false);
    }
  };

  const recipientRequired = request.recipientScope === "SelectedUsers" && selectedRecipients.size === 0;

  const toggleRecipient = (recipient: AdminNotificationRecipient) => {
    setSelectedRecipients((current) => current.has(recipient.id)
      ? removeSelectedRecipient(current, recipient.id)
      : mergeSelectedRecipients(current, [recipient]));
  };

  return (
    <div className="page-stack">
      <AdminNavigation />
      <PageHeader
        eyebrow={t("admin.common.eyebrow")}
        title={t("admin.notifications.title")}
        description={t("admin.notifications.description")}
        icon={Megaphone}
      />

      {(error || message) && (
        <div aria-live="polite">
          {error && (
            <div className="alert-error flex gap-2.5" role="alert">
              <AlertCircle aria-hidden="true" size={17} />
              <p>{error}</p>
            </div>
          )}
          {message && (
            <div className="alert-success flex gap-2.5" role="status">
              <CheckCircle2 aria-hidden="true" size={17} />
              <p>{message}</p>
            </div>
          )}
        </div>
      )}

      <section className="card" aria-labelledby="notification-compose-title">
        <p className="section-kicker">{t("admin.notifications.composeEyebrow")}</p>
        <h2 id="notification-compose-title" className="mt-1 card-title">
          {t("admin.notifications.composeTitle")}
        </h2>
        <form className="mt-5 grid gap-4 lg:grid-cols-2" onSubmit={send}>
          <label className="field">
            <span>{t("admin.notifications.scope")}</span>
            <select
              className="select"
              value={request.recipientScope}
              onChange={(event) =>
                setRequest({
                  ...request,
                  recipientScope: event.target.value as AdminSendNotificationRequest["recipientScope"],
                })
              }
            >
              <option value="SelectedUsers">{t("admin.notifications.selectedUsers")}</option>
              <option value="AllUsers">{t("admin.notifications.allUsers")}</option>
            </select>
          </label>

          {request.recipientScope === "SelectedUsers" && (
            <div className="field lg:col-span-2">
              <span>{t("admin.notifications.recipientSearch")}</span>
              <div className="relative">
                <Search aria-hidden="true" className="pointer-events-none absolute start-4 top-1/2 -translate-y-1/2 text-ink-400" size={17} />
                <input
                  dir="auto"
                  className="input ps-11"
                  type="search"
                  value={recipientQuery}
                  onChange={(event) => {
                    setRecipientQuery(event.target.value);
                    setRecipientPage(1);
                  }}
                  placeholder={t("admin.notifications.recipientSearchPlaceholder")}
                  disabled={sending}
                />
              </div>

              <div className="flex flex-wrap items-center gap-2" aria-live="polite">
                <span className="badge-brand">
                  {t(selectedRecipients.size === 1
                    ? "admin.notifications.selectedCountOne"
                    : "admin.notifications.selectedCount", {
                    count: selectedRecipients.size,
                    formattedCount: formatNumber(selectedRecipients.size),
                  })}
                </span>
                {[...selectedRecipients.values()].map((recipient) => (
                  <button
                    key={recipient.id}
                    type="button"
                    className="inline-flex min-h-8 max-w-full items-center gap-1.5 rounded-pill border border-border-subtle bg-white px-2.5 text-xs font-semibold text-ink-700"
                    onClick={() => setSelectedRecipients((current) => removeSelectedRecipient(current, recipient.id))}
                    disabled={sending}
                    aria-label={t("admin.notifications.removeRecipient", { name: recipient.fullName })}
                  >
                    <span dir="auto" className="truncate">{recipient.fullName}</span>
                    <X aria-hidden="true" className="shrink-0" size={13} />
                  </button>
                ))}
              </div>

              <div className="overflow-hidden rounded-control border border-border-subtle bg-surface-muted/45" aria-busy={recipientLoading}>
                {recipientLoading ? (
                  <div className="flex min-h-20 items-center justify-center gap-2 text-sm text-ink-500">
                    <LoaderCircle aria-hidden="true" className="animate-spin" size={16} />
                    {t("admin.notifications.searching")}
                  </div>
                ) : recipientError ? (
                  <p className="p-4 text-sm text-rose-700" role="alert">{recipientError}</p>
                ) : recipientQuery.trim().length < 2 ? (
                  <p className="p-4 text-sm text-ink-500">{t("admin.notifications.searchHint")}</p>
                ) : recipientResults.length === 0 ? (
                  <p className="p-4 text-sm text-ink-500">{t("admin.notifications.searchEmpty")}</p>
                ) : (
                  <div className="max-h-64 divide-y divide-border-subtle overflow-y-auto">
                    {recipientResults.map((recipient) => {
                      const selected = selectedRecipients.has(recipient.id);
                      return (
                        <label key={recipient.id} className="flex cursor-pointer items-center gap-3 bg-white px-4 py-3 hover:bg-brand-50/50">
                          <input
                            type="checkbox"
                            checked={selected}
                            onChange={() => toggleRecipient(recipient)}
                            disabled={sending}
                          />
                          <span className="min-w-0 flex-1">
                            <span dir="auto" className="block truncate text-sm font-semibold text-ink-900">{recipient.fullName}</span>
                            <bdi dir="ltr" className="mt-0.5 block truncate text-left text-xs text-ink-500">{recipient.email}</bdi>
                          </span>
                        </label>
                      );
                    })}
                    {recipientResults.length < recipientTotal && (
                      <div className="flex justify-center bg-surface-muted/45 p-3">
                        <button
                          type="button"
                          className="btn-secondary min-h-9 px-3 py-1.5 text-xs"
                          onClick={() => setRecipientPage((page) => page + 1)}
                          disabled={recipientLoadingMore || sending}
                        >
                          {recipientLoadingMore && <LoaderCircle aria-hidden="true" className="animate-spin" size={14} />}
                          {recipientLoadingMore ? t("admin.notifications.searching") : t("admin.notifications.loadMoreRecipients")}
                        </button>
                      </div>
                    )}
                  </div>
                )}
              </div>
            </div>
          )}

          <label className="field">
            <span>{t("admin.notifications.category")}</span>
            <select
              className="select"
              value={request.category}
              onChange={(event) =>
                setRequest({
                  ...request,
                  category: event.target.value as AdminSendNotificationRequest["category"],
                })
              }
            >
              {(["General", "Reservation", "Payment", "Support", "Account"] as const).map((category) => (
                <option key={category} value={category}>
                  {t(`admin.notifications.categories.${category}`)}
                </option>
              ))}
            </select>
          </label>

          <label className="field">
            <span>{t("admin.notifications.notificationTitle")}</span>
            <input
              dir="auto"
              className="input"
              maxLength={120}
              value={request.title}
              onChange={(event) => setRequest({ ...request, title: event.target.value })}
              required
            />
          </label>

          <label className="field lg:col-span-2">
            <span>{t("admin.notifications.message")}</span>
            <textarea
              dir="auto"
              className="input min-h-28 resize-y"
              maxLength={1000}
              value={request.message}
              onChange={(event) => setRequest({ ...request, message: event.target.value })}
              required
            />
          </label>

          <div className="lg:col-span-2 lg:justify-self-end">
            <button
              className={request.recipientScope === "AllUsers" ? "btn-danger" : "btn-primary"}
              type="submit"
              disabled={sending || loading || recipientRequired || !request.title.trim() || !request.message.trim()}
            >
              {sending ? (
                <LoaderCircle aria-hidden="true" className="animate-spin" size={17} />
              ) : (
                <Send aria-hidden="true" size={17} />
              )}
              {sending ? t("admin.notifications.sending") : t("admin.notifications.send")}
            </button>
          </div>
        </form>
      </section>

      <section aria-labelledby="notification-history-title">
        <p className="section-kicker">{t("admin.notifications.historyEyebrow")}</p>
        <h2 id="notification-history-title" className="mt-1 text-2xl font-semibold text-ink-950">
          {t("admin.notifications.historyTitle")}
        </h2>
        {loading ? (
          <div className="skeleton mt-5 h-32 rounded-card" />
        ) : history.length === 0 ? (
          <div className="state-panel mt-5">
            <Megaphone aria-hidden="true" size={22} />
            <h3 className="mt-3 card-title">{t("admin.notifications.empty")}</h3>
          </div>
        ) : (
          <div className="mt-5 space-y-3">
            {history.map((campaign) => (
              <article key={campaign.id} className="card-compact">
                <div className="flex flex-col gap-3 sm:flex-row sm:items-start sm:justify-between">
                  <div className="min-w-0">
                    <div className="flex flex-wrap items-center gap-2">
                      <span className="badge-neutral">
                        {t(`admin.notifications.categories.${campaign.category}`)}
                      </span>
                      <span className="text-xs text-ink-500">
                        {campaign.recipientScope === "AllUsers" ? (
                          t("admin.notifications.allUsers")
                        ) : campaign.recipientEmail ? (
                          <bdi dir="ltr">{campaign.recipientEmail}</bdi>
                        ) : campaign.recipientScope === "SelectedUsers" ? (
                          t(campaign.targetCount === 1
                            ? "admin.notifications.selectedRecipientsHistoryOne"
                            : "admin.notifications.selectedRecipientsHistory", {
                            count: campaign.targetCount,
                            formattedCount: formatNumber(campaign.targetCount),
                          })
                        ) : (
                          t("admin.notifications.userNumber", {
                            id: formatNumber(campaign.recipientUserId ?? 0),
                          })
                        )}
                      </span>
                    </div>
                    <h3 dir="auto" className="mt-3 font-semibold text-ink-950">
                      {campaign.title}
                    </h3>
                    <p dir="auto" className="mt-1 font-reading text-sm leading-6 text-ink-600">
                      {campaign.message}
                    </p>
                  </div>
                  <div className="shrink-0 text-xs text-ink-500">
                    <p>
                      {t("admin.notifications.recipients", {
                        count: campaign.targetCount,
                        formattedCount: formatNumber(campaign.targetCount),
                      })}
                    </p>
                    <p className="mt-1">
                      {t("admin.notifications.sentBy", {
                        id: formatNumber(campaign.createdByAdminUserId),
                      })}
                    </p>
                    <time className="mt-1 block" dateTime={campaign.createdAt}>
                      {formatDateTime(campaign.createdAt)}
                    </time>
                  </div>
                </div>
              </article>
            ))}
          </div>
        )}
      </section>

      <section aria-labelledby="notification-delivery-title">
        <div className="flex flex-col gap-4 lg:flex-row lg:items-end lg:justify-between">
          <div>
            <p className="section-kicker">{t("admin.notifications.deliveryEyebrow")}</p>
            <h2 id="notification-delivery-title" className="mt-1 text-2xl font-semibold text-ink-950">
              {t("admin.notifications.deliveryTitle")}
            </h2>
          </div>
          <div className="grid gap-3 sm:grid-cols-2" aria-label={t("admin.notifications.deliveryFilters")}>
            <label className="field">
              <span>{t("admin.notifications.source")}</span>
              <select
                className="select min-w-40"
                value={sourceFilter}
                onChange={(event) => {
                  setSourceFilter(event.target.value);
                  setDeliveryPage(1);
                }}
              >
                <option value="">{t("common.all")}</option>
                <option value="System">{t("admin.notifications.sources.System")}</option>
                <option value="Admin">{t("admin.notifications.sources.Admin")}</option>
              </select>
            </label>
            <label className="field">
              <span>{t("admin.notifications.readState")}</span>
              <select
                className="select min-w-40"
                value={readFilter}
                onChange={(event) => {
                  setReadFilter(event.target.value as "" | "read" | "unread");
                  setDeliveryPage(1);
                }}
              >
                <option value="">{t("common.all")}</option>
                <option value="unread">{t("admin.notifications.unread")}</option>
                <option value="read">{t("admin.notifications.read")}</option>
              </select>
            </label>
          </div>
        </div>

        {deliveryLoading ? (
          <div className="skeleton mt-5 h-40 rounded-card" />
        ) : deliveryError ? (
          <div className="alert-error mt-5 flex gap-2.5" role="alert">
            <AlertCircle aria-hidden="true" size={17} />
            <p>{deliveryError}</p>
          </div>
        ) : deliveries.length === 0 ? (
          <div className="state-panel mt-5">
            <Inbox aria-hidden="true" size={22} />
            <h3 className="mt-3 card-title">{t("admin.notifications.deliveryEmpty")}</h3>
          </div>
        ) : (
          <div className="mt-5 divide-y divide-border-subtle overflow-hidden rounded-card border border-border-subtle bg-white">
            {deliveries.map((delivery) => (
              <article key={delivery.id} className="flex flex-col gap-3 p-4 sm:flex-row sm:items-start sm:justify-between">
                <div className="min-w-0">
                  <div className="flex flex-wrap items-center gap-2">
                    <span className={delivery.source === "Admin" ? "badge-brand" : "badge-neutral"}>
                      {t(`admin.notifications.sources.${delivery.source}`)}
                    </span>
                    <span className="badge-neutral">
                      {t(`admin.notifications.types.${delivery.type}`, { defaultValue: delivery.type })}
                    </span>
                    <span className={delivery.readAt ? "badge-neutral" : "badge-warning"}>
                      {delivery.readAt ? t("admin.notifications.read") : t("admin.notifications.unread")}
                    </span>
                  </div>
                  <p dir="auto" className="mt-3 font-semibold text-ink-950">
                    {delivery.title || delivery.resourceLabel || t(`admin.notifications.types.${delivery.type}`, { defaultValue: delivery.type })}
                  </p>
                  {delivery.message && (
                    <p dir="auto" className="mt-1 font-reading text-sm leading-6 text-ink-600">
                      {delivery.message}
                    </p>
                  )}
                  <p className="mt-2 flex flex-wrap items-center gap-1 text-xs text-ink-500">
                    <bdi dir="ltr">{delivery.userEmail}</bdi>
                    {delivery.reservationId && (
                      <span>
                        · {t("admin.notifications.reservationNumber", { id: formatNumber(delivery.reservationId) })}
                      </span>
                    )}
                  </p>
                </div>
                <div className="shrink-0 text-xs text-ink-500 sm:text-end">
                  {delivery.createdByAdminUserId && (
                    <p>
                      {t("admin.notifications.sentBy", {
                        id: formatNumber(delivery.createdByAdminUserId),
                      })}
                    </p>
                  )}
                  <time className="mt-1 block" dateTime={delivery.createdAt}>
                    {formatDateTime(delivery.createdAt)}
                  </time>
                </div>
              </article>
            ))}
          </div>
        )}

        {!deliveryLoading && deliveryTotal > 20 && (
          <div className="mt-5 flex items-center justify-between gap-3">
            <button
              className="btn-secondary"
              type="button"
              disabled={deliveryPage <= 1}
              onClick={() => setDeliveryPage((value) => Math.max(1, value - 1))}
            >
              {t("admin.notifications.previous")}
            </button>
            <span className="text-sm text-ink-500">
              {t("admin.notifications.page", { page: formatNumber(deliveryPage) })}
            </span>
            <button
              className="btn-secondary"
              type="button"
              disabled={deliveryPage * 20 >= deliveryTotal}
              onClick={() => setDeliveryPage((value) => value + 1)}
            >
              {t("admin.notifications.next")}
            </button>
          </div>
        )}
      </section>
    </div>
  );
}
