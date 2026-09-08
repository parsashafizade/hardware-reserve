import { useEffect, useState, type ReactNode } from "react";
import {
  ArrowRight,
  Boxes,
  LayoutDashboard,
  Headphones,
  ReceiptText,
  RotateCcw,
  ShieldCheck,
  Users,
  Bell,
  CalendarClock,
  CircleDollarSign,
  ServerOff,
  type LucideIcon,
} from "lucide-react";
import { Link } from "react-router-dom";
import { useTranslation } from "react-i18next";
import { adminApi } from "../api/adminApi";
import { AdminNavigation } from "../components/admin/AdminNavigation";
import { PageHeader } from "../components/ui/PageHeader";
import type { DashboardStats } from "../types/api";
import { getApiErrorMessage } from "../utils/errors";
import { useLocale } from "../i18n/useLocale";
import { getAdminActionBadgeLabel } from "../utils/adminActionBadges";
import { useCurrentTime } from "../hooks/useCurrentTime";

function StatCard({ icon: Icon, label, value, detail }: { icon: LucideIcon; label: string; value: ReactNode; detail: string }) {
  return (
    <div className="rounded-card border border-border-subtle bg-white p-5 shadow-card">
      <div className="flex items-start justify-between gap-4">
        <div>
          <p className="text-xs font-medium text-ink-500">{label}</p>
          <p className="mt-2 text-3xl font-semibold tracking-[-0.045em] text-ink-950">{value}</p>
          <p className="mt-1 text-xs leading-5 text-ink-500">{detail}</p>
        </div>
        <span className="icon-tile"><Icon aria-hidden="true" size={18} /></span>
      </div>
    </div>
  );
}

function AdminAction({ to, icon: Icon, title, copy, count, countLabel }: { to: string; icon: LucideIcon; title: string; copy: string; count?: number; countLabel?: string }) {
  const { formatNumber } = useLocale();
  const badge = getAdminActionBadgeLabel(count ?? 0, formatNumber);
  return (
    <Link to={to} className="interactive-card group rounded-card border border-border-subtle bg-white p-5 shadow-card sm:p-6">
      <div className="flex items-start justify-between gap-4">
        <span className="flex items-center gap-2">
          <span className="icon-tile"><Icon aria-hidden="true" size={19} /></span>
          {badge && <span aria-label={countLabel} className="inline-flex min-w-6 items-center justify-center rounded-full bg-rose-600 px-1.5 py-0.5 text-xs font-bold leading-5 text-white">{badge}</span>}
        </span>
        <ArrowRight aria-hidden="true" className="directional-icon text-ink-400 transition duration-base group-hover:text-brand-700" size={17} />
      </div>
      <h2 className="mt-5 card-title">{title}</h2>
      <p className="mt-2 text-sm leading-6 text-ink-500">{copy}</p>
    </Link>
  );
}

export function AdminDashboardPage() {
  const { t } = useTranslation();
  const { formatNumber, formatDate } = useLocale();
  const [stats, setStats] = useState<DashboardStats | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [requestVersion, setRequestVersion] = useState(0);
  const refreshClock = useCurrentTime(5 * 60_000);

  useEffect(() => {
    let cancelled = false;
    const loadStats = async () => {
      setLoading(true);
      setError("");
      try {
        const response = await adminApi.getDashboardStats();
        if (!cancelled) setStats(response);
      } catch (loadError) {
        if (!cancelled) {
          setStats(null);
          setError(getApiErrorMessage(loadError, t("admin.dashboard.loadError")));
        }
      } finally {
        if (!cancelled) setLoading(false);
      }
    };
    void loadStats();
    return () => { cancelled = true; };
  }, [refreshClock, requestVersion, t]);

  return (
    <div className="page-stack">
      <AdminNavigation />
      <PageHeader
        eyebrow={t("admin.common.eyebrow")}
        title={t("admin.dashboard.title")}
        description={t("admin.dashboard.description")}
        icon={LayoutDashboard}
        actions={<span className="badge-brand"><ShieldCheck aria-hidden="true" size={14} />{t("admin.dashboard.access")}</span>}
      />

      {error && !stats ? (
        <div className="state-panel" role="alert">
          <span className="icon-tile-neutral"><LayoutDashboard aria-hidden="true" size={21} /></span>
          <h2 className="mt-4 card-title">{t("admin.dashboard.unavailable")}</h2>
          <p className="mt-2 max-w-md body-copy">{error}</p>
          <button type="button" className="btn-primary mt-5" onClick={() => setRequestVersion((version) => version + 1)}>
            <RotateCcw aria-hidden="true" size={16} />{t("actions.retry")}
          </button>
        </div>
      ) : (
        <section className="grid gap-4 md:grid-cols-3" aria-label={t("admin.dashboard.statsAria")}>
          <StatCard icon={Users} label={t("admin.dashboard.totalUsers")} value={loading || !stats ? "-" : formatNumber(stats.totalUsers)} detail={t("admin.dashboard.totalUsersDetail")} />
          <StatCard icon={Boxes} label={t("admin.dashboard.totalServers")} value={loading || !stats ? "-" : formatNumber(stats.totalServers)} detail={t("admin.dashboard.totalServersDetail")} />
          <StatCard icon={ReceiptText} label={t("admin.dashboard.totalPurchases")} value={loading || !stats ? "-" : formatNumber(stats.totalPurchases)} detail={t("admin.dashboard.totalPurchasesDetail")} />
        </section>
      )}

      {stats && (
        <section aria-labelledby="operations-attention-title">
          <p className="section-kicker">{t("admin.dashboard.attentionEyebrow")}</p>
          <h2 id="operations-attention-title" className="mt-1 text-2xl font-semibold text-ink-950">{t("admin.dashboard.attentionTitle")}</h2>
          <div className="mt-5 grid gap-3 sm:grid-cols-2 xl:grid-cols-4">
            <Link to="/admin/orders?status=Active" className="card-compact interactive-card"><CalendarClock aria-hidden="true" className="text-brand-700" size={18} /><p className="mt-3 text-xs text-ink-500">{t("admin.dashboard.activeReservations")}</p><p className="mt-1 text-2xl font-semibold text-ink-950">{formatNumber(stats.activeReservations)}</p></Link>
            <Link to="/admin/orders?status=Upcoming" className="card-compact interactive-card"><CalendarClock aria-hidden="true" className="text-amber-600" size={18} /><p className="mt-3 text-xs text-ink-500">{t("admin.dashboard.startingSoon")}</p><p className="mt-1 text-2xl font-semibold text-ink-950">{formatNumber(stats.startingSoonReservations)}</p></Link>
            <Link to="/admin/orders?status=PendingPayment" className="card-compact interactive-card"><CircleDollarSign aria-hidden="true" className="text-amber-600" size={18} /><p className="mt-3 text-xs text-ink-500">{t("admin.dashboard.pendingPayments")}</p><p className="mt-1 text-2xl font-semibold text-ink-950">{formatNumber(stats.pendingPayments)}</p></Link>
            <Link to="/admin/servers" className="card-compact interactive-card"><ServerOff aria-hidden="true" className="text-rose-600" size={18} /><p className="mt-3 text-xs text-ink-500">{t("admin.dashboard.unavailableServers")}</p><p className="mt-1 text-2xl font-semibold text-ink-950">{formatNumber(stats.unavailableServers)}</p></Link>
            <Link to="/admin/support?status=WAITING_FOR_ADMIN" className="card-compact interactive-card"><Headphones aria-hidden="true" className="text-blue-600" size={18} /><p className="mt-3 text-xs text-ink-500">{t("admin.dashboard.waitingSupport")}</p><p className="mt-1 text-2xl font-semibold text-ink-950">{formatNumber(stats.waitingSupportConversations)}</p></Link>
          </div>
        </section>
      )}

      <section aria-labelledby="admin-workspaces-title">
        <p className="section-kicker">{t("admin.dashboard.workspaces")}</p>
        <h2 id="admin-workspaces-title" className="mt-1 text-2xl font-semibold tracking-[-0.03em] text-ink-950">{t("admin.dashboard.operations")}</h2>
        <div className="mt-5 grid gap-4 md:grid-cols-2 xl:grid-cols-5">
          <AdminAction to="/admin/servers" icon={Boxes} title={t("admin.dashboard.serversTitle")} copy={t("admin.dashboard.serversCopy")} />
          <AdminAction to="/admin/orders?assignmentStatus=NeedsAssignment" icon={ReceiptText} title={t("admin.dashboard.ordersTitle")} copy={t("admin.dashboard.ordersCopy")} count={stats?.pendingAssignmentReservations} countLabel={t("admin.dashboard.pendingAssignmentsBadge")} />
          <AdminAction to="/admin/users" icon={Users} title={t("admin.dashboard.usersTitle")} copy={t("admin.dashboard.usersCopy")} />
          <AdminAction to="/admin/support" icon={Headphones} title={t("admin.dashboard.supportTitle")} copy={t("admin.dashboard.supportCopy")} count={stats?.supportAttentionConversations} countLabel={t("admin.dashboard.supportAttentionBadge")} />
          <AdminAction to="/admin/notifications" icon={Bell} title={t("admin.dashboard.notificationsTitle")} copy={t("admin.dashboard.notificationsCopy")} />
        </div>
      </section>

      {stats && stats.recentAuditEvents.length > 0 && <section aria-labelledby="recent-admin-activity"><p className="section-kicker">{t("admin.dashboard.auditEyebrow")}</p><h2 id="recent-admin-activity" className="mt-1 text-2xl font-semibold text-ink-950">{t("admin.dashboard.auditTitle")}</h2><div className="mt-5 divide-y divide-border-subtle overflow-hidden rounded-card border border-border-subtle bg-white">{stats.recentAuditEvents.map((event) => <div key={event.id} className="flex flex-col gap-1 p-4 sm:flex-row sm:items-center sm:justify-between"><div><p className="font-semibold text-ink-900">{t(`admin.audit.actions.${event.action}`, { defaultValue: event.action })}</p><p dir="auto" className="mt-1 text-xs text-ink-500">{event.details}</p></div><time className="text-xs text-ink-500" dateTime={event.createdAt}>{formatDate(event.createdAt, { dateStyle: "medium", timeStyle: "short" })}</time></div>)}</div></section>}
    </div>
  );
}
