import { useEffect, useState } from "react";
import {
  AlertCircle,
  Ban,
  CheckCircle2,
  Download,
  Eye,
  EyeOff,
  KeyRound,
  LoaderCircle,
  ReceiptText,
  RotateCcw,
  Server as ServerIcon,
  UserRound,
  Search,
} from "lucide-react";
import { adminApi } from "../api/adminApi";
import { useTranslation } from "react-i18next";
import { AdminNavigation } from "../components/admin/AdminNavigation";
import { PaymentStatusBadge, ReservationStatusBadge } from "../components/account/AccountStatusBadges";
import { PageHeader } from "../components/ui/PageHeader";
import { StatusBadge } from "../components/ui/StatusBadge";
import { ADMIN_ASSIGNMENT_FILTERS, type AdminAssignmentFilter, type AdminOrder, type AdminReservationDetail } from "../types/api";
import { downloadBlob } from "../utils/download";
import { getApiErrorMessage } from "../utils/errors";
import { formatCurrency, formatDateTime, formatDuration } from "../utils/format";
import { useLocale } from "../i18n/useLocale";
import { useSearchParams } from "react-router-dom";
import { useCurrentTime } from "../hooks/useCurrentTime";

interface CredentialDraft {
  assignedIp: string;
  assignedUsername: string;
  assignedPassword: string;
}

const emptyDraft: CredentialDraft = { assignedIp: "", assignedUsername: "", assignedPassword: "" };

function isPaid(order: AdminOrder): boolean {
  return order.reservationStatus.replace(/[\s_-]/g, "").toLowerCase() === "paid";
}

export function AdminOrdersPage() {
  const { t } = useTranslation();
  const { formatNumber } = useLocale();
  const [searchParams] = useSearchParams();
  const [orders, setOrders] = useState<AdminOrder[]>([]);
  const [drafts, setDrafts] = useState<Record<number, CredentialDraft>>({});
  const [credentialDetails, setCredentialDetails] = useState<Record<number, AdminReservationDetail>>({});
  const [visibleCredentialDetails, setVisibleCredentialDetails] = useState<Set<number>>(() => new Set());
  const [revealedPasswords, setRevealedPasswords] = useState<Set<number>>(() => new Set());
  const [credentialDetailsLoadingId, setCredentialDetailsLoadingId] = useState<number | null>(null);
  const [credentialDetailsErrors, setCredentialDetailsErrors] = useState<Record<number, string>>({});
  const [loading, setLoading] = useState(true);
  const [exporting, setExporting] = useState(false);
  const [assigningId, setAssigningId] = useState<number | null>(null);
  const [error, setError] = useState("");
  const [message, setMessage] = useState("");
  const [requestVersion, setRequestVersion] = useState(0);
  const [query, setQuery] = useState("");
  const [status, setStatus] = useState(searchParams.get("status") ?? "");
  const [assignmentStatus, setAssignmentStatus] = useState<AdminAssignmentFilter>(() => {
    const requested = searchParams.get("assignmentStatus");
    return ADMIN_ASSIGNMENT_FILTERS.includes(requested as AdminAssignmentFilter)
      ? requested as AdminAssignmentFilter
      : "All";
  });
  const [page, setPage] = useState(1);
  const [totalCount, setTotalCount] = useState(0);
  const [cancellingId, setCancellingId] = useState<number | null>(null);
  const currentTime = useCurrentTime(60_000);

  useEffect(() => {
    let cancelled = false;
    const load = async () => {
      setLoading(true);
      setError("");
      try {
        const data = await adminApi.getReservations({ query: query.trim() || undefined, status: status || undefined, assignmentStatus, page, pageSize: 20 });
        if (!cancelled) { setOrders(data.items); setTotalCount(data.totalCount); }
      } catch (loadError) {
        if (!cancelled) {
          setOrders([]);
          setError(getApiErrorMessage(loadError, t("admin.orders.loadError")));
        }
      } finally {
        if (!cancelled) setLoading(false);
      }
    };
    void load();
    return () => { cancelled = true; };
  }, [assignmentStatus, page, query, requestVersion, status, t]);

  useEffect(() => {
    setVisibleCredentialDetails(new Set());
    setRevealedPasswords(new Set());
    setCredentialDetailsErrors({});
  }, [assignmentStatus, page, query, status]);

  const toggleCredentialDetails = async (reservationId: number) => {
    if (visibleCredentialDetails.has(reservationId)) {
      setVisibleCredentialDetails((current) => {
        const next = new Set(current);
        next.delete(reservationId);
        return next;
      });
      setRevealedPasswords((current) => {
        const next = new Set(current);
        next.delete(reservationId);
        return next;
      });
      return;
    }

    setCredentialDetailsLoadingId(reservationId);
    setCredentialDetailsErrors((current) => ({ ...current, [reservationId]: "" }));
    try {
      const details = await adminApi.getReservation(reservationId);
      setCredentialDetails((current) => ({ ...current, [reservationId]: details }));
      setVisibleCredentialDetails((current) => new Set(current).add(reservationId));
    } catch (detailsError) {
      setCredentialDetailsErrors((current) => ({
        ...current,
        [reservationId]: getApiErrorMessage(detailsError, t("admin.orders.detailsLoadError")),
      }));
    } finally {
      setCredentialDetailsLoadingId(null);
    }
  };

  const togglePassword = (reservationId: number) => {
    setRevealedPasswords((current) => {
      const next = new Set(current);
      if (next.has(reservationId)) next.delete(reservationId);
      else next.add(reservationId);
      return next;
    });
  };

  const updateDraft = (reservationId: number, field: keyof CredentialDraft, value: string) => {
    setDrafts((previous) => ({
      ...previous,
      [reservationId]: { ...emptyDraft, ...previous[reservationId], [field]: value },
    }));
    setMessage("");
  };

  const assign = async (reservationId: number) => {
    const draft = drafts[reservationId];
    if (!draft?.assignedIp.trim() || !draft.assignedUsername.trim() || !draft.assignedPassword.trim()) {
      setError(t("admin.orders.fieldsRequired"));
      return;
    }
    const order = orders.find((item) => item.reservationId === reservationId);
    if (order?.credentialsAssigned && !window.confirm(t("admin.orders.overwriteConfirm"))) {
      return;
    }

    setAssigningId(reservationId);
    setError("");
    setMessage("");
    try {
      const assigned = await adminApi.assignCredentials({
        reservationId,
        assignedIp: draft.assignedIp.trim(),
        assignedUsername: draft.assignedUsername.trim(),
        assignedPassword: draft.assignedPassword,
      });
      setCredentialDetails((current) => ({ ...current, [reservationId]: assigned }));
      setVisibleCredentialDetails((current) => new Set(current).add(reservationId));
      setRevealedPasswords((current) => {
        const next = new Set(current);
        next.delete(reservationId);
        return next;
      });
      setDrafts((previous) => ({ ...previous, [reservationId]: emptyDraft }));
      setMessage(t("admin.orders.assignSuccess", { id: formatNumber(reservationId) }));
      const refreshed = await adminApi.getReservations({ query: query.trim() || undefined, status: status || undefined, assignmentStatus, page, pageSize: 20 });
      setOrders(refreshed.items);
      setTotalCount(refreshed.totalCount);
    } catch (assignError) {
      setError(getApiErrorMessage(assignError, t("admin.orders.assignError")));
    } finally {
      setAssigningId(null);
    }
  };

  const cancelReservation = async (reservationId: number) => {
    if (!window.confirm(t("admin.orders.cancelConfirm"))) return;
    setCancellingId(reservationId);
    setError("");
    setMessage("");
    try {
      await adminApi.cancelReservation(reservationId);
      setMessage(t("admin.orders.cancelSuccess", { id: formatNumber(reservationId) }));
      setRequestVersion((version) => version + 1);
    } catch (cancelError) {
      setError(getApiErrorMessage(cancelError, t("admin.orders.cancelError")));
    } finally {
      setCancellingId(null);
    }
  };

  const exportExcel = async () => {
    setExporting(true);
    setError("");
    try {
      const blob = await adminApi.exportOrdersExcel();
      downloadBlob(blob, `orders-${Date.now()}.xlsx`);
    } catch (exportError) {
      setError(getApiErrorMessage(exportError, t("admin.orders.exportError")));
    } finally {
      setExporting(false);
    }
  };

  return (
    <div className="page-stack">
      <AdminNavigation />
      <PageHeader
        eyebrow={t("admin.common.eyebrow")}
        title={t("admin.orders.title")}
        description={t("admin.orders.description")}
        icon={ReceiptText}
        actions={
          <button className="btn-primary" type="button" onClick={() => void exportExcel()} disabled={loading || exporting}>
            {exporting ? <LoaderCircle aria-hidden="true" className="animate-spin" size={17} /> : <Download aria-hidden="true" size={17} />}
            {exporting ? t("admin.orders.exporting") : t("admin.orders.exportExcel")}
          </button>
        }
      />

      {(error || message) && (
        <div aria-live="polite">
          {error && <div className="alert-error flex items-start gap-2.5" role="alert"><AlertCircle aria-hidden="true" className="mt-0.5" size={17} /><p>{error}</p></div>}
          {message && <div className="alert-success flex items-start gap-2.5" role="status"><CheckCircle2 aria-hidden="true" className="mt-0.5" size={17} /><p>{message}</p></div>}
        </div>
      )}

      <section className="card-compact" aria-label={t("admin.orders.filters")}>
        <div className="grid gap-3 md:grid-cols-2 xl:grid-cols-[1fr_13rem_13rem_auto]">
          <label className="field"><span>{t("admin.orders.search")}</span><div className="relative"><Search aria-hidden="true" className="pointer-events-none absolute start-3 top-1/2 -translate-y-1/2 text-ink-400" size={16} /><input dir="auto" className="input ps-10" value={query} onChange={(event) => { setQuery(event.target.value); setPage(1); }} placeholder={t("admin.orders.searchPlaceholder")} /></div></label>
          <label className="field"><span>{t("common.status")}</span><select className="select" value={status} onChange={(event) => { setStatus(event.target.value); setPage(1); }}><option value="">{t("common.all")}</option>{["PendingPayment", "Active", "Upcoming", "Completed", "Cancelled"].map((value) => <option key={value} value={value}>{t(`admin.orders.filtersStatus.${value}`)}</option>)}</select></label>
          <label className="field"><span>{t("admin.orders.assignmentFilter")}</span><select className="select" value={assignmentStatus} onChange={(event) => { setAssignmentStatus(event.target.value as AdminAssignmentFilter); setPage(1); }}>{ADMIN_ASSIGNMENT_FILTERS.map((value) => <option key={value} value={value}>{t(`admin.orders.assignmentFilters.${value}`)}</option>)}</select></label>
          <button className="btn-secondary self-end" type="button" onClick={() => { setQuery(""); setStatus(""); setAssignmentStatus("All"); setPage(1); }}>{t("actions.clearFilters")}</button>
        </div>
      </section>

      <section aria-labelledby="orders-list-title">
        <div className="mb-5 flex flex-col gap-2 sm:flex-row sm:items-end sm:justify-between">
          <div><p className="section-kicker">{t("admin.orders.records")}</p><h2 id="orders-list-title" className="mt-1 text-2xl font-semibold tracking-[-0.03em] text-ink-950">{t("admin.orders.recordsCopy")}</h2></div>
          {!loading && <p className="text-sm font-medium text-ink-500">{t("admin.orders.count", { count: totalCount, formattedCount: formatNumber(totalCount) })}</p>}
        </div>

        {loading ? (
          <div className="space-y-4" role="status" aria-label={t("admin.orders.loading")}><div className="skeleton h-72 rounded-card" /><div className="skeleton h-72 rounded-card" /></div>
        ) : error && orders.length === 0 ? (
          <div className="state-panel" role="alert">
            <span className="icon-tile-neutral"><AlertCircle aria-hidden="true" size={21} /></span>
            <h2 className="mt-4 card-title">{t("admin.orders.unavailable")}</h2><p className="mt-2 max-w-md body-copy">{error}</p>
            <button type="button" className="btn-primary mt-5" onClick={() => setRequestVersion((version) => version + 1)}><RotateCcw aria-hidden="true" size={16} />{t("actions.retry")}</button>
          </div>
        ) : orders.length === 0 ? (
          <div className="state-panel"><span className="icon-tile-neutral"><ReceiptText aria-hidden="true" size={21} /></span><h2 className="mt-4 card-title">{t("admin.orders.empty")}</h2><p className="mt-2 max-w-md body-copy">{t("admin.orders.emptyCopy")}</p></div>
        ) : (
          <div className="space-y-4">
            {orders.map((order) => {
              const paid = isPaid(order);
              const draft = drafts[order.reservationId] ?? emptyDraft;
              const assigning = assigningId === order.reservationId;
              return (
                <article key={order.reservationId} className="overflow-hidden rounded-card border border-border-subtle bg-white shadow-card">
                  <div className="flex flex-col gap-4 border-b border-border-subtle bg-gradient-to-r from-white via-brand-50/40 to-white p-5 sm:flex-row sm:items-center sm:justify-between sm:px-6">
                    <div><p className="section-kicker">{t("admin.orders.reservationNumber", { id: formatNumber(order.reservationId) })}</p><h3 dir="auto" className="mt-1 text-lg font-semibold text-ink-950">{order.gpu !== "None" ? order.gpu : order.cpu}</h3></div>
                    <div className="flex flex-wrap gap-2"><ReservationStatusBadge status={order.reservationStatus} /><PaymentStatusBadge status={order.paymentStatus} /><StatusBadge tone={order.credentialsAssigned ? "success" : "warning"} showDot>{order.credentialsAssigned ? t("admin.orders.assigned") : t("admin.orders.notAssigned")}</StatusBadge></div>
                  </div>

                  <div className="grid gap-5 p-5 sm:p-6 lg:grid-cols-3">
                    <section className="rounded-control border border-border-subtle bg-surface-muted/55 p-4" aria-label={t("admin.orders.customer")}>
                      <p className="inline-flex items-center gap-2 text-xs font-bold uppercase tracking-[0.12em] text-ink-500"><UserRound aria-hidden="true" size={14} />{t("admin.orders.customer")}</p>
                      <p dir="auto" className="mt-3 font-semibold text-ink-900">{order.userFullName}</p><p dir="ltr" className="mt-1 break-all text-left text-xs text-ink-500">{order.userEmail}</p><p className="mt-3 text-xs text-ink-500">{t("admin.orders.userNumber", { id: formatNumber(order.userId) })}</p>
                    </section>
                    <section className="rounded-control border border-border-subtle bg-surface-muted/55 p-4" aria-label={t("admin.orders.hardware")}>
                      <p className="inline-flex items-center gap-2 text-xs font-bold uppercase tracking-[0.12em] text-ink-500"><ServerIcon aria-hidden="true" size={14} />{t("admin.orders.hardware")}</p>
                      <p dir="auto" className="mt-3 font-semibold text-ink-900">{order.cpu}</p><p dir="auto" className="mt-1 text-xs text-ink-500">{order.gpu === "None" ? t("server.specs.noDedicatedGpu") : order.gpu} · {order.ram} · {order.storage}</p><p dir="auto" className="mt-3 text-xs text-ink-500">{order.os} · {t("admin.orders.serverNumber", { id: formatNumber(order.serverId) })}</p>
                    </section>
                    <section className="rounded-control border border-border-subtle bg-surface-muted/55 p-4" aria-label={t("admin.orders.scheduleTotal")}>
                      <p className="text-xs font-bold uppercase tracking-[0.12em] text-ink-500">{t("admin.orders.scheduleTotal")}</p>
                      <p className="mt-3 text-sm font-semibold text-ink-900">{formatCurrency(order.totalPrice)}</p><p className="mt-1 text-xs text-ink-500">{formatDuration(order.startTime, order.endTime)}</p><p className="mt-3 text-xs leading-5 text-ink-500">{formatDateTime(order.startTime)} {t("common.to")} {formatDateTime(order.endTime)}</p>
                    </section>
                  </div>

                  <div className="border-t border-border-subtle bg-surface-muted/35 p-5 sm:p-6">
                    <div className="flex items-start gap-3"><span className={paid ? "icon-tile-success size-10" : "icon-tile-neutral size-10"}><KeyRound aria-hidden="true" size={17} /></span><div><h4 className="text-sm font-semibold text-ink-900">{t("admin.orders.assignTitle")}</h4><p className="mt-0.5 text-xs leading-5 text-ink-500">{paid ? order.credentialsAssigned ? t("admin.orders.assignedHint") : t("admin.orders.assignPaidHint") : t("admin.orders.assignUnpaidHint")}</p></div></div>
                    {order.credentialsAssigned && (
                      <div className="mt-4 rounded-control border border-emerald-200 bg-emerald-50/60 p-4">
                        <div className="flex flex-wrap items-center justify-between gap-3">
                          <div><p className="text-sm font-semibold text-emerald-950">{t("admin.orders.currentDetails")}</p><p className="mt-0.5 text-xs text-emerald-800">{t("admin.orders.currentDetailsHint")}</p></div>
                          <button className="btn-secondary min-h-9 px-3 py-1.5 text-xs" type="button" onClick={() => void toggleCredentialDetails(order.reservationId)} disabled={credentialDetailsLoadingId === order.reservationId}>
                            {credentialDetailsLoadingId === order.reservationId ? <LoaderCircle aria-hidden="true" className="animate-spin" size={15} /> : visibleCredentialDetails.has(order.reservationId) ? <EyeOff aria-hidden="true" size={15} /> : <Eye aria-hidden="true" size={15} />}
                            {credentialDetailsLoadingId === order.reservationId ? t("admin.orders.loadingDetails") : visibleCredentialDetails.has(order.reservationId) ? t("admin.orders.hideDetails") : t("admin.orders.reviewDetails")}
                          </button>
                        </div>
                        {credentialDetailsErrors[order.reservationId] && <p className="mt-3 text-xs text-rose-700" role="alert">{credentialDetailsErrors[order.reservationId]}</p>}
                        {visibleCredentialDetails.has(order.reservationId) && credentialDetails[order.reservationId] && (
                          <dl className="mt-4 grid gap-3 border-t border-emerald-200 pt-4 sm:grid-cols-3">
                            <div><dt className="text-xs font-medium text-emerald-800">{t("admin.orders.ipAddress")}</dt><dd dir="ltr" className="mt-1 break-all text-left font-mono text-sm font-semibold text-ink-950">{credentialDetails[order.reservationId].assignedIp}</dd></div>
                            <div><dt className="text-xs font-medium text-emerald-800">{t("admin.orders.username")}</dt><dd dir="ltr" className="mt-1 break-all text-left font-mono text-sm font-semibold text-ink-950">{credentialDetails[order.reservationId].assignedUsername}</dd></div>
                            <div><dt className="text-xs font-medium text-emerald-800">{t("admin.orders.password")}</dt><dd className="mt-1 flex items-center gap-2"><span dir="ltr" className="min-w-0 break-all text-left font-mono text-sm font-semibold text-ink-950">{revealedPasswords.has(order.reservationId) ? credentialDetails[order.reservationId].assignedPassword : "••••••••••••"}</span><button type="button" className="btn-icon size-8 min-h-8 min-w-8" onClick={() => togglePassword(order.reservationId)} aria-label={revealedPasswords.has(order.reservationId) ? t("admin.orders.hidePassword") : t("admin.orders.revealPassword")}>{revealedPasswords.has(order.reservationId) ? <EyeOff aria-hidden="true" size={14} /> : <Eye aria-hidden="true" size={14} />}</button></dd></div>
                          </dl>
                        )}
                      </div>
                    )}
                    {paid && (
                      <div className="mt-4 grid gap-3 lg:grid-cols-[1fr_1fr_1fr_auto]">
                        <label className="field"><span>{t("admin.orders.ipAddress")}</span><input dir="ltr" className="input text-left" value={draft.assignedIp} onChange={(event) => updateDraft(order.reservationId, "assignedIp", event.target.value)} placeholder="203.0.113.10" disabled={assigning} /></label>
                        <label className="field"><span>{t("admin.orders.username")}</span><input dir="ltr" className="input text-left" value={draft.assignedUsername} onChange={(event) => updateDraft(order.reservationId, "assignedUsername", event.target.value)} placeholder={t("admin.orders.usernamePlaceholder")} autoComplete="off" disabled={assigning} /></label>
                        <label className="field"><span>{t("admin.orders.password")}</span><input dir="ltr" className="input text-left" type="password" value={draft.assignedPassword} onChange={(event) => updateDraft(order.reservationId, "assignedPassword", event.target.value)} placeholder={t("admin.orders.passwordPlaceholder")} autoComplete="new-password" disabled={assigning} /></label>
                        <button className="btn-primary self-end" type="button" onClick={() => void assign(order.reservationId)} disabled={assigning || !draft.assignedIp.trim() || !draft.assignedUsername.trim() || !draft.assignedPassword}>
                          {assigning ? <LoaderCircle aria-hidden="true" className="animate-spin" size={17} /> : <KeyRound aria-hidden="true" size={17} />}{assigning ? t("admin.orders.assigning") : order.credentialsAssigned ? t("admin.orders.replace") : t("admin.orders.assign")}
                        </button>
                      </div>
                    )}
                    {order.reservationStatus !== "Cancelled" && new Date(order.endTime).getTime() > currentTime && <div className="mt-4 flex justify-end border-t border-border-subtle pt-4"><button className="btn-danger" type="button" onClick={() => void cancelReservation(order.reservationId)} disabled={cancellingId === order.reservationId}>{cancellingId === order.reservationId ? <LoaderCircle aria-hidden="true" className="animate-spin" size={16} /> : <Ban aria-hidden="true" size={16} />}{t("admin.orders.cancelReservation")}</button></div>}
                  </div>
                </article>
              );
            })}
          </div>
        )}
        {!loading && totalCount > 20 && <div className="mt-5 flex items-center justify-between gap-3"><button className="btn-secondary" type="button" disabled={page <= 1} onClick={() => setPage((value) => Math.max(1, value - 1))}>{t("admin.orders.previous")}</button><span className="text-sm text-ink-500">{t("admin.orders.page", { page: formatNumber(page) })}</span><button className="btn-secondary" type="button" disabled={page * 20 >= totalCount} onClick={() => setPage((value) => value + 1)}>{t("admin.orders.next")}</button></div>}
      </section>
    </div>
  );
}
