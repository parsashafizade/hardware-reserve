import {
  Activity,
  AlertCircle,
  ArrowLeft,
  CalendarClock,
  CheckCircle2,
  CircleDollarSign,
  Clock3,
  Headphones,
  KeyRound,
  LoaderCircle,
  Network,
  RefreshCcw,
  Server as ServerIcon,
  ShieldCheck,
  Timer,
  UserRound,
  WalletCards,
  XCircle,
  type LucideIcon,
} from "lucide-react";
import { useCallback, useEffect, useMemo, useState } from "react";
import { useTranslation } from "react-i18next";
import { Link, useParams } from "react-router-dom";
import { reservationsApi } from "../api/reservationsApi";
import { AccountNavigation } from "../components/account/AccountNavigation";
import { PaymentStatusBadge, ReservationStatusBadge } from "../components/account/AccountStatusBadges";
import { SecureAccessField } from "../components/account/SecureAccessField";
import { ServerSpecGrid } from "../components/server/ServerSpecGrid";
import { PageHeader } from "../components/ui/PageHeader";
import { StatusBadge } from "../components/ui/StatusBadge";
import { useLocale } from "../i18n/useLocale";
import { useSupport } from "../support/useSupport";
import type { ReservationCockpit } from "../types/api";
import { getApiErrorMessage } from "../utils/errors";
import { formatCurrency, formatDateTime, formatDuration, isolateBidiText } from "../utils/format";
import { deriveReservationLifecycle, type ReservationLifecyclePhase } from "../utils/reservationLifecycle";
import { hasDedicatedGpu } from "../utils/serverPresentation";

const timelineSteps = ["reserved", "payment", "scheduled", "active", "completed"] as const;

interface PhasePresentation {
  icon: LucideIcon;
  tone: "neutral" | "brand" | "success" | "warning";
}

const phasePresentation: Record<ReservationLifecyclePhase, PhasePresentation> = {
  awaitingPayment: { icon: WalletCards, tone: "warning" },
  upcoming: { icon: CalendarClock, tone: "brand" },
  startingSoon: { icon: Timer, tone: "warning" },
  active: { icon: Activity, tone: "success" },
  completed: { icon: CheckCircle2, tone: "neutral" },
  cancelled: { icon: XCircle, tone: "neutral" },
};

function hasCredentials(reservation: ReservationCockpit): reservation is ReservationCockpit & {
  assignedIp: string;
  assignedUsername: string;
  assignedPassword: string;
} {
  return Boolean(reservation.assignedIp && reservation.assignedUsername && reservation.assignedPassword);
}

function CockpitSkeleton({ label }: { label: string }) {
  return (
    <div className="page-stack" role="status" aria-label={label}>
      <div className="skeleton h-20 rounded-card" />
      <div className="skeleton h-60 rounded-panel" />
      <div className="grid gap-6 lg:grid-cols-[minmax(0,1fr)_22rem]">
        <div className="space-y-5"><div className="skeleton h-72 rounded-card" /><div className="skeleton h-72 rounded-card" /></div>
        <div className="skeleton h-96 rounded-card" />
      </div>
    </div>
  );
}

export function ServiceCockpitPage() {
  const { t } = useTranslation();
  const { formatNumber } = useLocale();
  const { reservationId } = useParams();
  const { openSupportWithDraft } = useSupport();
  const [reservation, setReservation] = useState<ReservationCockpit | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [requestVersion, setRequestVersion] = useState(0);
  const [clockOffset, setClockOffset] = useState(0);
  const [now, setNow] = useState(Date.now());
  const [passwordVisible, setPasswordVisible] = useState(false);
  const [copiedField, setCopiedField] = useState("");
  const [copyError, setCopyError] = useState("");

  const load = useCallback(async () => {
    const id = Number(reservationId);
    if (!Number.isInteger(id) || id <= 0) {
      setReservation(null);
      setError(t("cockpit.loadError"));
      setLoading(false);
      return;
    }
    setLoading(true);
    setError("");
    try {
      const response = await reservationsApi.getCockpit(id);
      const offset = new Date(response.serverTimeUtc).getTime() - Date.now();
      setReservation(response);
      setClockOffset(offset);
      setNow(Date.now() + offset);
    } catch (requestError) {
      setReservation(null);
      setError(getApiErrorMessage(requestError, t("cockpit.loadError")));
    } finally {
      setLoading(false);
    }
  }, [reservationId, t]);

  useEffect(() => {
    void load();
  }, [load, requestVersion]);

  useEffect(() => {
    if (!reservation) {
      return;
    }
    const update = () => setNow(Date.now() + clockOffset);
    update();
    const interval = window.setInterval(update, 1_000);
    document.addEventListener("visibilitychange", update);
    return () => {
      window.clearInterval(interval);
      document.removeEventListener("visibilitychange", update);
    };
  }, [clockOffset, reservation]);

  const lifecycle = useMemo(
    () => reservation ? deriveReservationLifecycle(reservation, now) : null,
    [now, reservation],
  );

  if (loading && !reservation) {
    return <CockpitSkeleton label={t("cockpit.loading")} />;
  }

  if (!reservation || !lifecycle) {
    return (
      <div className="state-panel" role="alert">
        <span className="icon-tile-neutral"><AlertCircle aria-hidden="true" size={21} /></span>
        <h1 className="mt-4 card-title">{t("cockpit.unavailableTitle")}</h1>
        <p className="mt-2 max-w-md body-copy">{error || t("cockpit.loadError")}</p>
        <div className="mt-5 flex flex-col gap-2 sm:flex-row">
          <button type="button" className="btn-primary" onClick={() => setRequestVersion((value) => value + 1)}>
            <RefreshCcw aria-hidden="true" size={16} />{t("actions.retry")}
          </button>
          <Link to="/my-reservations" className="btn-secondary">
            <ArrowLeft aria-hidden="true" className="directional-icon" size={16} />{t("cockpit.back")}
          </Link>
        </div>
      </div>
    );
  }

  const presentation = phasePresentation[lifecycle.phase];
  const PhaseIcon = presentation.icon;
  const primaryHardware = hasDedicatedGpu(reservation.server) ? reservation.server.gpu : reservation.server.cpu;
  const credentialsReady = hasCredentials(reservation);
  const countdown = lifecycle.countdownSeconds === null ? null : (() => {
    const hours = Math.floor(lifecycle.countdownSeconds / 3_600);
    const minutes = Math.floor((lifecycle.countdownSeconds % 3_600) / 60);
    const seconds = lifecycle.countdownSeconds % 60;
    return [hours, minutes, seconds]
      .map((value) => formatNumber(value, { minimumIntegerDigits: 2, useGrouping: false }))
      .join(":");
  })();
  const countdownCopy = lifecycle.phase === "awaitingPayment"
    ? t("cockpit.countdown.payment")
    : lifecycle.phase === "active"
      ? t("cockpit.countdown.endsIn", { time: countdown ? isolateBidiText(countdown) : "" })
      : lifecycle.phase === "upcoming" || lifecycle.phase === "startingSoon"
        ? t("cockpit.countdown.startsIn", { time: countdown ? isolateBidiText(countdown) : "" })
        : t(`cockpit.countdown.${lifecycle.phase}`);

  const copyValue = async (field: string, value: string) => {
    setCopyError("");
    try {
      await navigator.clipboard.writeText(value);
      setCopiedField(field);
      window.setTimeout(() => setCopiedField(""), 1_800);
    } catch {
      setCopiedField("");
      setCopyError(t("cockpit.copyFailed"));
    }
  };

  const openContextualSupport = () => {
    openSupportWithDraft(t("cockpit.supportDraft", {
      id: formatNumber(reservation.reservationId, { useGrouping: false }),
      server: primaryHardware,
      status: t(`cockpit.state.${lifecycle.phase}`),
    }));
  };

  return (
    <div className="page-stack">
      <AccountNavigation />
      <PageHeader
        eyebrow={t("cockpit.eyebrow")}
        title={t("cockpit.title", { id: formatNumber(reservation.reservationId, { useGrouping: false }) })}
        description={t("cockpit.description")}
        icon={Activity}
        actions={(
          <Link to="/my-reservations" className="btn-secondary">
            <ArrowLeft aria-hidden="true" className="directional-icon" size={16} />{t("cockpit.back")}
          </Link>
        )}
      />

      <section className="card-inverse px-5 py-6 sm:px-7 sm:py-7" aria-labelledby="cockpit-current-state">
        <div aria-hidden="true" className="absolute -end-16 -top-20 size-64 rounded-full bg-brand-400/15 blur-3xl" />
        <div className="relative flex flex-col gap-6 md:flex-row md:items-center md:justify-between">
          <div className="flex min-w-0 items-start gap-4">
            <span className="icon-tile-inverse size-12"><PhaseIcon aria-hidden="true" size={22} /></span>
            <div className="min-w-0">
              <StatusBadge tone={presentation.tone} showDot className="border-white/10">{t(`cockpit.state.${lifecycle.phase}`)}</StatusBadge>
              <h1 id="cockpit-current-state" dir="auto" className="bidi-auto mt-3 text-2xl font-semibold text-white sm:text-3xl">{primaryHardware}</h1>
              <p className="mt-2 max-w-xl font-reading text-sm leading-6 text-ink-300">{t(`cockpit.statusCopy.${lifecycle.phase}`)}</p>
            </div>
          </div>
          <div className="shrink-0 rounded-control border border-white/10 bg-white/[0.06] px-5 py-4 md:min-w-64 md:text-end">
            <p dir="auto" className={`bidi-auto font-semibold text-white ${countdown ? "text-2xl tabular-nums sm:text-3xl" : "text-base"}`}>
              {countdownCopy}
            </p>
            <p className="mt-1 text-xs text-ink-400">{t("cockpit.localTime")}</p>
          </div>
        </div>
      </section>

      <section className="card" aria-labelledby="cockpit-timeline-title">
        <div className="flex items-center gap-2">
          <Clock3 aria-hidden="true" className="text-brand-700" size={18} />
          <h2 id="cockpit-timeline-title" className="card-title">{t("cockpit.timeline")}</h2>
        </div>
        <ol className="mt-5 grid gap-2 sm:grid-cols-5">
          {timelineSteps.map((step, index) => {
            const state = lifecycle.phase === "cancelled"
              ? index === 0 ? "complete" : "future"
              : index < lifecycle.currentStep ? "complete" : index === lifecycle.currentStep ? "current" : "future";
            return (
              <li key={step} className={`relative flex items-center gap-3 rounded-control border p-3 sm:flex-col sm:items-start ${state === "complete" ? "border-emerald-200 bg-emerald-50/70" : state === "current" ? "border-brand-300 bg-brand-50" : "border-border-subtle bg-surface-muted/45"}`}>
                <span className={`inline-flex size-7 shrink-0 items-center justify-center rounded-full text-xs font-bold ${state === "complete" ? "bg-emerald-600 text-white" : state === "current" ? "bg-brand-700 text-white" : "bg-surface-inset text-ink-500"}`}>
                  {state === "complete" ? <CheckCircle2 aria-hidden="true" size={15} /> : formatNumber(index + 1, { useGrouping: false })}
                </span>
                <span>
                  <span className="block text-xs font-semibold text-ink-900">{t(`cockpit.timelineSteps.${step}`)}</span>
                  <span className="mt-0.5 block text-[10px] text-ink-500">{t(`cockpit.timelineState.${state}`)}</span>
                </span>
              </li>
            );
          })}
        </ol>
      </section>

      <div className="grid items-start gap-6 lg:grid-cols-[minmax(0,1fr)_22rem]">
        <div className="min-w-0 space-y-6">
          <section className="card" aria-labelledby="cockpit-server-title">
            <div className="mb-5 flex flex-col gap-3 sm:flex-row sm:items-start sm:justify-between">
              <div>
                <p className="section-kicker">{t("cockpit.serverId", { id: formatNumber(reservation.server.serverId, { useGrouping: false }) })}</p>
                <h2 id="cockpit-server-title" className="mt-1 card-title">{t("cockpit.server")}</h2>
                <p className="mt-1 text-sm text-ink-500">{t("cockpit.configuration")}</p>
              </div>
              <Link to={`/server/${reservation.server.serverId}`} className="btn-secondary min-h-10 px-4 py-2">
                <ServerIcon aria-hidden="true" size={16} />{t("cockpit.viewServer")}
              </Link>
            </div>
            <ServerSpecGrid server={reservation.server} />
          </section>

          <section className="card" aria-labelledby="cockpit-schedule-title">
            <div className="flex items-center gap-2">
              <CalendarClock aria-hidden="true" className="text-brand-700" size={18} />
              <h2 id="cockpit-schedule-title" className="card-title">{t("cockpit.schedule")}</h2>
            </div>
            <dl className="mt-5 grid gap-4 sm:grid-cols-2">
              <div className="surface-inset p-4"><dt className="meta-text">{t("cockpit.starts")}</dt><dd className="mt-1 text-sm font-semibold text-ink-900">{formatDateTime(reservation.startTime)}</dd></div>
              <div className="surface-inset p-4"><dt className="meta-text">{t("cockpit.ends")}</dt><dd className="mt-1 text-sm font-semibold text-ink-900">{formatDateTime(reservation.endTime)}</dd></div>
              <div className="surface-inset p-4"><dt className="meta-text">{t("cockpit.duration")}</dt><dd className="mt-1 text-sm font-semibold text-ink-900">{formatDuration(reservation.startTime, reservation.endTime)}</dd></div>
              <div className="surface-inset p-4"><dt className="meta-text">{t("cockpit.total")}</dt><dd dir="auto" className="bidi-auto mt-1 text-lg font-semibold text-ink-950">{formatCurrency(reservation.totalPrice)}</dd></div>
            </dl>
            <div className="mt-4 flex flex-wrap gap-2">
              <ReservationStatusBadge status={reservation.status} />
              <PaymentStatusBadge status={reservation.paymentStatus} />
              {reservation.paymentDate && <span className="badge">{t("cockpit.paymentDate")}: {formatDateTime(reservation.paymentDate)}</span>}
            </div>
          </section>

          <section className="card-inverse p-5 sm:p-6" aria-labelledby="cockpit-access-title">
            <div className="relative">
              <div className="flex items-start justify-between gap-3">
                <div>
                  <p className="text-xs font-bold uppercase tracking-[0.14em] text-brand-200">{t("cockpit.access")}</p>
                  <h2 id="cockpit-access-title" className="mt-1 text-lg font-semibold text-white">{credentialsReady ? t("cockpit.accessReady") : t("cockpit.accessPending")}</h2>
                </div>
                <span className="icon-tile-inverse size-10">{credentialsReady ? <ShieldCheck aria-hidden="true" size={18} /> : <KeyRound aria-hidden="true" size={18} />}</span>
              </div>
              {credentialsReady ? (
                <div className="mt-5 space-y-2.5">
                  <SecureAccessField icon={Network} label={t("cockpit.ip")} value={reservation.assignedIp} copied={copiedField === "ip"} onCopy={() => void copyValue("ip", reservation.assignedIp)} />
                  <SecureAccessField icon={UserRound} label={t("cockpit.username")} value={reservation.assignedUsername} copied={copiedField === "username"} onCopy={() => void copyValue("username", reservation.assignedUsername)} />
                  <SecureAccessField icon={KeyRound} label={t("cockpit.password")} value={reservation.assignedPassword} concealed revealed={passwordVisible} copied={copiedField === "password"} onToggleVisibility={() => setPasswordVisible((value) => !value)} onCopy={() => void copyValue("password", reservation.assignedPassword)} />
                  {copyError && <p className="text-xs text-rose-200" role="alert">{copyError}</p>}
                  <p className="font-reading text-xs leading-5 text-ink-400">{lifecycle.phase === "completed" ? t("cockpit.accessEndedCopy") : t("cockpit.accessReadyCopy")}</p>
                </div>
              ) : (
                <div className="mt-5 rounded-control border border-dashed border-white/15 bg-white/[0.045] px-5 py-8 text-center">
                  <KeyRound aria-hidden="true" className="mx-auto text-brand-200" size={22} />
                  <p className="mx-auto mt-3 max-w-md font-reading text-sm leading-6 text-ink-300">{t("cockpit.accessPendingCopy")}</p>
                </div>
              )}
            </div>
          </section>
        </div>

        <aside className="card lg:sticky lg:top-28" aria-labelledby="cockpit-actions-title">
          <div className="flex items-center gap-2">
            <Activity aria-hidden="true" className="text-brand-700" size={18} />
            <h2 id="cockpit-actions-title" className="card-title">{t("cockpit.actions")}</h2>
          </div>
          <div className="mt-5 grid gap-2.5">
            {lifecycle.phase === "awaitingPayment" ? (
              <Link to={`/checkout/${reservation.reservationId}`} className="btn-primary w-full">
                <WalletCards aria-hidden="true" size={17} />{t("cockpit.completePayment")}
              </Link>
            ) : reservation.paymentId ? (
              <Link to={`/checkout/${reservation.reservationId}`} className="btn-secondary w-full">
                <CircleDollarSign aria-hidden="true" size={17} />{t("cockpit.viewPayment")}
              </Link>
            ) : null}
            <button type="button" className="btn-secondary w-full" onClick={openContextualSupport}>
              <Headphones aria-hidden="true" size={17} />{t("cockpit.contactSupport")}
            </button>
            <Link to="/servers" className="btn-ghost w-full">
              <ServerIcon aria-hidden="true" size={17} />{t("cockpit.browseServers")}
            </Link>
            <button type="button" className="btn-ghost w-full" onClick={() => void load()} disabled={loading}>
              {loading ? <LoaderCircle aria-hidden="true" className="animate-spin" size={17} /> : <RefreshCcw aria-hidden="true" size={17} />}{t("cockpit.refresh")}
            </button>
          </div>
        </aside>
      </div>
    </div>
  );
}
