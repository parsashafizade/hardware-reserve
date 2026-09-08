import { useEffect, useState } from "react";
import { AlertCircle, ArrowLeft, Bell, CircleDollarSign, Headphones, ReceiptText, UserRound } from "lucide-react";
import { Link, useParams } from "react-router-dom";
import { useTranslation } from "react-i18next";
import { adminApi } from "../api/adminApi";
import { AdminNavigation } from "../components/admin/AdminNavigation";
import { PageHeader } from "../components/ui/PageHeader";
import { StatusBadge } from "../components/ui/StatusBadge";
import { ReservationStatusBadge } from "../components/account/AccountStatusBadges";
import { BidiText } from "../components/support/BidiText";
import type { AdminUserOverview } from "../types/api";
import { getApiErrorMessage } from "../utils/errors";
import { formatCurrency, formatDateTime } from "../utils/format";
import { useLocale } from "../i18n/useLocale";

export function AdminUserOverviewPage() {
  const { userId } = useParams();
  const { t } = useTranslation();
  const { formatNumber } = useLocale();
  const [user, setUser] = useState<AdminUserOverview | null>(null);
  const [error, setError] = useState("");
  const numericUserId = Number(userId);

  useEffect(() => {
    let cancelled = false;
    adminApi.getUserOverview(numericUserId).then((response) => { if (!cancelled) setUser(response); }).catch((loadError) => { if (!cancelled) setError(getApiErrorMessage(loadError, t("admin.userOverview.loadError"))); });
    return () => { cancelled = true; };
  }, [numericUserId, t]);

  return <div className="page-stack"><AdminNavigation /><Link to="/admin/users" className="btn-ghost w-fit"><ArrowLeft aria-hidden="true" className="directional-icon" size={16} />{t("admin.userOverview.back")}</Link>{error ? <div className="state-panel" role="alert"><AlertCircle aria-hidden="true" size={22} /><h2 className="mt-3 card-title">{t("admin.userOverview.unavailable")}</h2><p className="mt-2 body-copy">{error}</p></div> : !user ? <div className="skeleton h-56 rounded-card" role="status" aria-label={t("admin.userOverview.loading")} /> : <><PageHeader eyebrow={t("admin.userOverview.eyebrow")} title={<BidiText text={user.fullName} as="span" className="block" />} description={<bdi dir="ltr" className="block break-all text-left">{user.email}</bdi>} icon={UserRound} actions={<StatusBadge tone={user.isEmailVerified ? "success" : "warning"} showDot>{user.isEmailVerified ? t("admin.userOverview.verified") : t("admin.userOverview.unverified")}</StatusBadge>} /><section className="grid gap-3 sm:grid-cols-2 xl:grid-cols-5" aria-label={t("admin.userOverview.metrics")}><Metric icon={ReceiptText} label={t("admin.userOverview.reservations")} value={formatNumber(user.reservationCount)} /><Metric icon={UserRound} label={t("admin.userOverview.active")} value={formatNumber(user.activeReservationCount)} /><Metric icon={CircleDollarSign} label={t("admin.userOverview.payments")} value={formatNumber(user.completedPaymentCount)} /><Metric icon={Headphones} label={t("admin.userOverview.support")} value={formatNumber(user.supportConversationCount)} /><Metric icon={Bell} label={t("admin.userOverview.unread")} value={formatNumber(user.unreadNotificationCount)} /></section><section aria-labelledby="user-reservations-title"><p className="section-kicker">{t("admin.userOverview.history")}</p><h2 id="user-reservations-title" className="mt-1 text-2xl font-semibold text-ink-950">{t("admin.userOverview.recentReservations")}</h2>{user.recentReservations.length === 0 ? <div className="state-panel mt-5"><ReceiptText aria-hidden="true" size={22} /><p className="mt-3 body-copy">{t("admin.userOverview.noReservations")}</p></div> : <div className="mt-5 grid gap-3 lg:grid-cols-2">{user.recentReservations.map((reservation) => <article key={reservation.reservationId} className="card-compact"><div className="flex items-start justify-between gap-3"><div><p className="section-kicker">#{formatNumber(reservation.reservationId)}</p><h3 dir="auto" className="mt-1 font-semibold text-ink-950">{reservation.gpu === "None" ? reservation.cpu : reservation.gpu}</h3></div><ReservationStatusBadge status={reservation.reservationStatus} /></div><dl className="mt-4 grid grid-cols-2 gap-3 text-xs"><div><dt className="text-ink-500">{t("admin.userOverview.schedule")}</dt><dd className="mt-1 font-semibold text-ink-900">{formatDateTime(reservation.startTime)}</dd></div><div><dt className="text-ink-500">{t("common.total")}</dt><dd className="mt-1 font-semibold text-ink-900">{formatCurrency(reservation.totalPrice)}</dd></div></dl></article>)}</div>}</section></>}</div>;
}

function Metric({ icon: Icon, label, value }: { icon: typeof UserRound; label: string; value: string }) {
  return <div className="card-compact"><span className="icon-tile-neutral"><Icon aria-hidden="true" size={17} /></span><p className="mt-3 text-xs text-ink-500">{label}</p><p className="mt-1 text-2xl font-semibold text-ink-950">{value}</p></div>;
}
