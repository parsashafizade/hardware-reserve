import {
  Activity,
  ArrowRight,
  CalendarClock,
  CheckCircle2,
  Clock3,
  Cpu,
  Headphones,
  History,
  LoaderCircle,
  MemoryStick,
  RefreshCcw,
  Search,
  Server as ServerIcon,
  Sparkles,
  WalletCards,
  type LucideIcon,
} from "lucide-react";
import { useMemo } from "react";
import { useTranslation } from "react-i18next";
import { Link, useNavigate } from "react-router-dom";
import { useAuth } from "../../auth/useAuth";
import { useDashboard } from "../../dashboard/useDashboard";
import { useCurrentTime } from "../../hooks/useCurrentTime";
import { useLocale } from "../../i18n/useLocale";
import { useNotifications } from "../../notifications/useNotifications";
import { useSupport } from "../../support/useSupport";
import type { DashboardPrimaryState, DashboardReservation } from "../../types/dashboard";
import type { UserNotification } from "../../types/notifications";
import { formatDateTime, isolateBidiText } from "../../utils/format";
import { deriveReservationLifecycle } from "../../utils/reservationLifecycle";
import { hasDedicatedGpu } from "../../utils/serverPresentation";
import { NotificationItem } from "../notifications/NotificationItem";

interface StatePresentation {
  icon: LucideIcon;
  tone: string;
}

const statePresentation: Record<DashboardPrimaryState, StatePresentation> = {
  PENDING_PAYMENT: { icon: WalletCards, tone: "text-amber-200" },
  ACTIVE: { icon: Activity, tone: "text-emerald-200" },
  STARTING_SOON: { icon: Clock3, tone: "text-amber-200" },
  UPCOMING: { icon: CalendarClock, tone: "text-brand-200" },
  RECENT_COMPLETED: { icon: CheckCircle2, tone: "text-ink-300" },
  DISCOVERY: { icon: Sparkles, tone: "text-brand-200" },
};

function formatCountdown(seconds: number, formatNumber: ReturnType<typeof useLocale>["formatNumber"]): string {
  const hours = Math.floor(seconds / 3_600);
  const minutes = Math.floor((seconds % 3_600) / 60);
  const remainingSeconds = seconds % 60;
  return [hours, minutes, remainingSeconds]
    .map((value) => formatNumber(value, { minimumIntegerDigits: 2, useGrouping: false }))
    .join(":");
}

function DashboardSkeleton({ label }: { label: string }) {
  return (
    <section className="dashboard-hero" role="status" aria-label={label}>
      <div className="container-shell relative py-10 sm:py-14">
        <div className="skeleton h-4 w-40 bg-white/10" />
        <div className="mt-5 grid gap-5 lg:grid-cols-[minmax(0,1.35fr)_minmax(18rem,0.65fr)]">
          <div className="skeleton h-64 bg-white/10" />
          <div className="skeleton h-64 bg-white/10" />
        </div>
      </div>
    </section>
  );
}

function primaryAction(state: DashboardPrimaryState, reservation?: DashboardReservation | null) {
  if (!reservation) {
    return { to: "/servers?finder=open", key: "finder" };
  }
  if (state === "PENDING_PAYMENT") {
    return { to: `/checkout/${reservation.reservationId}`, key: "payment" };
  }
  if (state === "RECENT_COMPLETED" && reservation.canReserveAgain) {
    return { to: `/reserve/${reservation.server.serverId}`, key: "again" };
  }
  if (state === "RECENT_COMPLETED") {
    return { to: "/servers", key: "browse" };
  }
  return { to: `/my-reservations/${reservation.reservationId}`, key: state === "ACTIVE" ? "service" : "reservation" };
}

export function PersonalizedHome() {
  const { t } = useTranslation();
  const { session } = useAuth();
  const { formatNumber, formatCurrency } = useLocale();
  const { summary, loading, refreshing, error, clockOffsetMilliseconds, refresh } = useDashboard();
  const { notifications, markRead } = useNotifications();
  const { openConversation, openSupport } = useSupport();
  const navigate = useNavigate();
  const currentTime = useCurrentTime(1_000);

  const reservation = summary?.primaryReservation ?? null;
  const lifecycle = useMemo(() => {
    if (!summary || !reservation) {
      return null;
    }
    return deriveReservationLifecycle(
      { ...reservation, serverTimeUtc: summary.serverTimeUtc },
      currentTime + clockOffsetMilliseconds,
    );
  }, [clockOffsetMilliseconds, currentTime, reservation, summary]);

  if (loading && !summary) {
    return <DashboardSkeleton label={t("personalizedHome.loading")} />;
  }

  const effectiveState: DashboardPrimaryState = lifecycle?.phase === "active"
    ? "ACTIVE"
    : lifecycle?.phase === "startingSoon"
      ? "STARTING_SOON"
      : lifecycle?.phase === "upcoming"
        ? "UPCOMING"
        : summary?.primaryState ?? "DISCOVERY";
  const presentation = statePresentation[effectiveState];
  const StateIcon = presentation.icon;
  const hardwareLabel = reservation
    ? hasDedicatedGpu(reservation.server) ? reservation.server.gpu : reservation.server.cpu
    : "";
  const action = primaryAction(effectiveState, reservation);
  const countdown = lifecycle?.countdownSeconds == null
    ? null
    : formatCountdown(lifecycle.countdownSeconds, formatNumber);
  const recentNotifications = notifications.slice(0, 3);

  const openNotification = async (notification: UserNotification) => {
    try {
      await markRead(notification.id);
    } catch {
      // Navigation remains available and the notification provider reconciles read state later.
    }
    if (notification.supportConversationId) {
      await openConversation(notification.supportConversationId);
    } else if (notification.reservationId) {
      navigate(`/my-reservations/${notification.reservationId}`);
    }
  };

  return (
    <>
      <section className="dashboard-hero text-white" aria-labelledby="personalized-home-title">
        <div aria-hidden="true" className="absolute -end-32 -top-36 size-[28rem] rounded-full bg-brand-400/15 blur-3xl" />
        <div aria-hidden="true" className="absolute -start-24 bottom-0 size-72 rounded-full bg-blue-400/10 blur-3xl" />
        <div className="container-shell relative py-10 sm:py-14 lg:py-16">
          <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
            <div>
              <p className="text-xs font-bold uppercase tracking-[0.16em] text-brand-200">{t("personalizedHome.eyebrow")}</p>
              <p dir="auto" className="bidi-auto mt-1 text-sm text-ink-300">
                {t("personalizedHome.greeting", { name: session?.user.fullName ?? "" })}
              </p>
            </div>
            <button type="button" className="btn-outline-light min-h-10 px-3 py-2 text-xs" onClick={() => void refresh()} disabled={refreshing}>
              {refreshing ? <LoaderCircle aria-hidden="true" className="animate-spin" size={15} /> : <RefreshCcw aria-hidden="true" size={15} />}
              {t("personalizedHome.refresh")}
            </button>
          </div>

          {error && !summary ? (
            <div className="mt-6 rounded-card border border-white/10 bg-white/[0.06] p-6 sm:p-8" role="alert">
              <h1 id="personalized-home-title" className="text-2xl font-semibold text-white">{t("personalizedHome.fallbackTitle")}</h1>
              <p className="mt-2 max-w-xl font-reading text-sm leading-6 text-ink-300">{error}</p>
              <div className="mt-5 flex flex-col gap-2 sm:flex-row">
                <button type="button" className="btn-light" onClick={() => void refresh()}>{t("actions.retry")}</button>
                <Link to="/servers" className="btn-outline-light">{t("actions.browseServers")}</Link>
              </div>
            </div>
          ) : (
            <div className="mt-6 grid items-stretch gap-5 lg:grid-cols-[minmax(0,1.35fr)_minmax(18rem,0.65fr)]">
              <div className="relative overflow-hidden rounded-panel border border-white/10 bg-white/[0.07] p-6 shadow-dark backdrop-blur-md sm:p-8">
                <div className="flex items-start gap-4">
                  <span className={`icon-tile-inverse size-12 ${presentation.tone}`}><StateIcon aria-hidden="true" size={22} /></span>
                  <div className="min-w-0">
                    <p className="text-xs font-semibold text-brand-200">{t(`personalizedHome.states.${effectiveState}.label`)}</p>
                    <h1 id="personalized-home-title" dir="auto" className="bidi-auto mt-2 max-w-2xl text-2xl font-semibold leading-tight text-white sm:text-3xl lg:text-[2.15rem]">
                      {t(`personalizedHome.states.${effectiveState}.title`, { server: isolateBidiText(hardwareLabel) })}
                    </h1>
                    <p className="mt-3 max-w-2xl font-reading text-sm leading-6 text-ink-300 sm:text-base">
                      {t(`personalizedHome.states.${effectiveState}.copy`)}
                    </p>
                  </div>
                </div>

                {countdown && (
                  <div className="mt-6 inline-flex items-center gap-3 rounded-control border border-white/10 bg-surface-inverse/40 px-4 py-3">
                    <Clock3 aria-hidden="true" className="text-brand-200" size={18} />
                    <span dir="ltr" className="technical-value text-xl font-semibold text-white">{countdown}</span>
                    <span className="text-xs font-medium text-ink-300">
                      {effectiveState === "ACTIVE" ? t("personalizedHome.remaining") : t("personalizedHome.untilStart")}
                    </span>
                  </div>
                )}

                <div className="mt-7 flex flex-col gap-3 sm:flex-row">
                  <Link to={action.to} className="btn-light px-6">
                    {t(`personalizedHome.actions.${action.key}`)}
                    <ArrowRight aria-hidden="true" className="directional-icon" size={17} />
                  </Link>
                  {effectiveState !== "DISCOVERY" && (
                    <Link to="/servers?finder=open" className="btn-outline-light">
                      <Sparkles aria-hidden="true" size={16} />
                      {t("personalizedHome.actions.finder")}
                    </Link>
                  )}
                </div>
              </div>

              <aside className="rounded-panel border border-white/10 bg-surface-inverse/55 p-5 shadow-dark sm:p-6" aria-label={t("personalizedHome.summary") }>
                {reservation ? (
                  <>
                    <div className="flex items-center justify-between gap-3">
                      <p className="text-xs font-bold uppercase tracking-[0.14em] text-brand-200">{t("personalizedHome.summary")}</p>
                      <span className="rounded-pill border border-white/10 bg-white/[0.07] px-2.5 py-1 text-[11px] font-semibold text-ink-200">
                        {t("personalizedHome.reservationId", { id: formatNumber(reservation.reservationId, { useGrouping: false }) })}
                      </span>
                    </div>
                    <dl className="mt-5 grid gap-3">
                      <div className="rounded-control border border-white/10 bg-white/[0.05] p-3.5">
                        <dt className="text-xs text-ink-400">{effectiveState === "ACTIVE" ? t("personalizedHome.ends") : effectiveState === "RECENT_COMPLETED" ? t("personalizedHome.ended") : t("personalizedHome.starts")}</dt>
                        <dd className="mt-1 text-sm font-semibold text-white">{formatDateTime(effectiveState === "ACTIVE" || effectiveState === "RECENT_COMPLETED" ? reservation.endTime : reservation.startTime)}</dd>
                      </div>
                      <div className="grid grid-cols-2 gap-3">
                        <div className="rounded-control border border-white/10 bg-white/[0.05] p-3.5"><dt className="inline-flex items-center gap-1.5 text-xs text-ink-400"><Cpu aria-hidden="true" size={13} />CPU</dt><dd dir="auto" className="bidi-auto mt-1 truncate text-xs font-semibold text-white">{reservation.server.cpu}</dd></div>
                        <div className="rounded-control border border-white/10 bg-white/[0.05] p-3.5"><dt className="inline-flex items-center gap-1.5 text-xs text-ink-400"><MemoryStick aria-hidden="true" size={13} />RAM</dt><dd dir="ltr" className="technical-value mt-1 text-xs font-semibold text-white">{reservation.server.ram}</dd></div>
                      </div>
                      <div className="rounded-control border border-white/10 bg-white/[0.05] p-3.5"><dt className="text-xs text-ink-400">{t("personalizedHome.total")}</dt><dd dir="auto" className="bidi-auto mt-1 text-base font-semibold text-white">{formatCurrency(reservation.totalPrice)}</dd></div>
                    </dl>
                  </>
                ) : (
                  <div className="flex h-full min-h-56 flex-col justify-center text-center">
                    <span className="icon-tile-inverse mx-auto"><Search aria-hidden="true" size={19} /></span>
                    <h2 className="mt-4 text-lg font-semibold text-white">{t("personalizedHome.newUserTitle")}</h2>
                    <p className="mt-2 font-reading text-sm leading-6 text-ink-300">{t("personalizedHome.newUserCopy")}</p>
                    <Link to="/servers" className="btn-outline-light mt-5 w-full"><ServerIcon aria-hidden="true" size={16} />{t("actions.browseServers")}</Link>
                  </div>
                )}
              </aside>
            </div>
          )}
        </div>
      </section>

      <section className="bg-surface-base py-12 sm:py-16" aria-labelledby="dashboard-overview-title">
        <div className="container-shell">
          <div className="flex flex-col gap-3 sm:flex-row sm:items-end sm:justify-between">
            <div>
              <p className="section-kicker">{t("personalizedHome.overviewEyebrow")}</p>
              <h2 id="dashboard-overview-title" className="mt-2 text-2xl font-semibold text-ink-950 sm:text-3xl">{t("personalizedHome.overviewTitle")}</h2>
            </div>
            {summary && summary.metrics.totalReservations > 0 && (
              <div className="flex flex-wrap gap-2" aria-label={t("personalizedHome.metrics.label") }>
                {([
                  ["active", summary.metrics.active],
                  ["upcoming", summary.metrics.upcoming],
                  ["completed", summary.metrics.completed],
                ] as const).map(([key, value]) => (
                  <span key={key} className="badge bg-white">
                    <span className="font-bold text-brand-700">{formatNumber(value)}</span>
                    {t(`personalizedHome.metrics.${key}`)}
                  </span>
                ))}
              </div>
            )}
          </div>

          <div className="mt-7 grid items-start gap-6 lg:grid-cols-[0.85fr_1.15fr]">
            <section className="card" aria-labelledby="quick-actions-title">
              <div className="flex items-center gap-3">
                <span className="icon-tile"><Sparkles aria-hidden="true" size={18} /></span>
                <div><p className="section-kicker">{t("personalizedHome.quickEyebrow")}</p><h3 id="quick-actions-title" className="mt-1 card-title">{t("personalizedHome.quickTitle")}</h3></div>
              </div>
              <div className="mt-5 grid gap-2 sm:grid-cols-2 lg:grid-cols-1 xl:grid-cols-2">
                <Link to="/servers?finder=open" className="btn-secondary justify-start"><Sparkles aria-hidden="true" size={16} />{t("personalizedHome.actions.finder")}</Link>
                <Link to="/servers" className="btn-secondary justify-start"><ServerIcon aria-hidden="true" size={16} />{t("actions.browseServers")}</Link>
                <Link to="/my-reservations" className="btn-secondary justify-start"><History aria-hidden="true" size={16} />{t("navigation.reservations")}</Link>
                <button type="button" className="btn-secondary justify-start" onClick={() => openSupport()}><Headphones aria-hidden="true" size={16} />{t("commandPalette.commands.support")}</button>
              </div>
            </section>

            <section className="overflow-hidden rounded-card border border-border-subtle bg-white shadow-card" aria-labelledby="recent-activity-title">
              <header className="flex items-center justify-between gap-4 border-b border-border-subtle px-5 py-4 sm:px-6">
                <div><p className="section-kicker">{t("personalizedHome.activityEyebrow")}</p><h3 id="recent-activity-title" className="mt-1 card-title">{t("personalizedHome.activityTitle")}</h3></div>
                <Link to="/activity" className="text-sm font-semibold text-brand-700 hover:text-brand-900">{t("personalizedHome.viewActivity")}</Link>
              </header>
              {recentNotifications.length > 0 ? (
                <div className="divide-y divide-border-subtle">
                  {recentNotifications.map((notification) => <NotificationItem key={notification.id} notification={notification} currentTime={currentTime} compact onOpen={(item) => void openNotification(item)} />)}
                </div>
              ) : (
                <div className="px-6 py-9 text-center">
                  <span className="icon-tile-neutral mx-auto"><CheckCircle2 aria-hidden="true" size={18} /></span>
                  <p className="mt-3 text-sm font-semibold text-ink-900">{t("notifications.empty")}</p>
                  <p className="mt-1 font-reading text-xs text-ink-500">{t("personalizedHome.activityEmpty")}</p>
                </div>
              )}
            </section>
          </div>
        </div>
      </section>
    </>
  );
}
