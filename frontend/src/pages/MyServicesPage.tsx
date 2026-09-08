import { useEffect, useMemo, useState } from "react";
import {
  Activity,
  AlertCircle,
  ArrowRight,
  CalendarClock,
  CheckCircle2,
  Clock3,
  KeyRound,
  Network,
  ReceiptText,
  RotateCcw,
  Server as ServerIcon,
  ShieldCheck,
  UserRound,
} from "lucide-react";
import { Link } from "react-router-dom";
import { useTranslation } from "react-i18next";
import { reservationsApi } from "../api/reservationsApi";
import { AccountMetricCard } from "../components/account/AccountMetricCard";
import { AccountNavigation } from "../components/account/AccountNavigation";
import { ServerSpecGrid } from "../components/server/ServerSpecGrid";
import { PageHeader } from "../components/ui/PageHeader";
import { StatusBadge } from "../components/ui/StatusBadge";
import { SecureAccessField } from "../components/account/SecureAccessField";
import type { MyService } from "../types/api";
import { getApiErrorMessage } from "../utils/errors";
import { formatCurrency, formatDateTime, formatDuration } from "../utils/format";
import { getComputeTypeLabel, hasDedicatedGpu } from "../utils/serverPresentation";
import { useLocale } from "../i18n/useLocale";
import { useCurrentTime } from "../hooks/useCurrentTime";

interface ServiceWindowPresentation {
  label: string;
  tone: "neutral" | "brand" | "success";
  description: string;
}

function hasCredentials(service: MyService): service is MyService & {
  assignedIp: string;
  assignedUsername: string;
  assignedPassword: string;
} {
  return Boolean(service.assignedIp && service.assignedUsername && service.assignedPassword);
}

function ServiceSkeleton() {
  return (
    <div className="overflow-hidden rounded-card border border-border-subtle bg-white shadow-card" aria-hidden="true">
      <div className="flex justify-between gap-4 border-b border-border-subtle p-5">
        <div className="space-y-2">
          <div className="skeleton h-4 w-28" />
          <div className="skeleton h-6 w-60" />
        </div>
        <div className="skeleton h-7 w-24" />
      </div>
      <div className="grid gap-5 p-5 lg:grid-cols-2">
        <div className="skeleton h-72" />
        <div className="skeleton h-72" />
      </div>
    </div>
  );
}

function ServiceRecord({ service, currentTime }: { service: MyService; currentTime: number }) {
  const { t } = useTranslation();
  const { formatNumber } = useLocale();
  const [passwordVisible, setPasswordVisible] = useState(false);
  const [copiedField, setCopiedField] = useState("");
  const [copyError, setCopyError] = useState("");
  const credentialsReady = hasCredentials(service);
  const startsAt = new Date(service.startTime).getTime();
  const endsAt = new Date(service.endTime).getTime();
  const windowPresentation: ServiceWindowPresentation = currentTime < startsAt
    ? { label: t("services.scheduled"), tone: "brand", description: t("services.scheduledCopy") }
    : currentTime < endsAt
      ? { label: t("services.active"), tone: "success", description: t("services.activeCopy") }
      : { label: t("services.ended"), tone: "neutral", description: t("services.endedCopy") };
  const gpuAccelerated = hasDedicatedGpu(service.server);
  const primaryHardware = gpuAccelerated ? service.server.gpu : service.server.cpu;

  const copyValue = async (field: string, value: string) => {
    setCopyError("");
    try {
      await navigator.clipboard.writeText(value);
      setCopiedField(field);
      window.setTimeout(() => setCopiedField(""), 1800);
    } catch {
      setCopiedField("");
      setCopyError(t("services.copyBlocked"));
    }
  };

  return (
    <article className="overflow-hidden rounded-card border border-border-subtle bg-white shadow-card transition duration-base hover:border-brand-200 hover:shadow-lift">
      <div className="flex flex-col gap-4 border-b border-border-subtle bg-gradient-to-r from-white via-brand-50/45 to-white p-5 sm:flex-row sm:items-center sm:justify-between sm:px-6">
        <div className="flex min-w-0 items-center gap-3">
          <span className="icon-tile-success">
            <KeyRound aria-hidden="true" size={19} />
          </span>
          <div className="min-w-0">
            <p className="text-xs font-bold uppercase tracking-[0.14em] text-brand-700">{t("services.serviceNumber", { id: formatNumber(service.reservationId) })}</p>
            <h2 dir="auto" className="bidi-auto mt-1 truncate text-lg font-semibold tracking-[-0.025em] text-ink-950" title={primaryHardware}>{primaryHardware}</h2>
            <p className="mt-0.5 text-xs font-medium text-ink-500">{getComputeTypeLabel(service.server)} · {t("services.paidReservation")}</p>
          </div>
        </div>
        <div className="flex flex-wrap items-center gap-2">
          <StatusBadge tone={windowPresentation.tone} showDot>{windowPresentation.label}</StatusBadge>
          <Link to={`/my-reservations/${service.reservationId}`} className="btn-ghost min-h-9 px-3 py-1.5 text-xs">
            <Activity aria-hidden="true" size={14} />
            {t("cockpit.eyebrow")}
          </Link>
        </div>
      </div>

      <div className="grid gap-6 p-5 sm:p-6 lg:grid-cols-[1.08fr_0.92fr]">
        <div className="min-w-0 space-y-5">
          <section aria-labelledby={`hardware-${service.reservationId}`}>
            <div className="mb-3 flex items-center justify-between gap-3">
              <div>
                <p className="section-kicker">{t("services.configuration")}</p>
                <h3 id={`hardware-${service.reservationId}`} className="mt-1 card-title">{t("services.hardware")}</h3>
              </div>
              <Link to={`/server/${service.server.serverId}`} className="btn-ghost min-h-9 px-3 py-1.5 text-xs">
                {t("services.viewHardware")}
                <ArrowRight aria-hidden="true" className="directional-icon" size={14} />
              </Link>
            </div>
            <ServerSpecGrid server={service.server} compact />
          </section>

          <section className="rounded-control border border-border-subtle bg-surface-muted/55 p-4" aria-label={t("services.windowAndTotalAria")}>
            <div className="grid gap-4 sm:grid-cols-2">
              <div>
                <div className="flex items-center gap-2 text-xs font-bold uppercase tracking-[0.12em] text-ink-500">
                  <CalendarClock aria-hidden="true" size={14} />
                  {t("services.accessWindow")}
                </div>
                <dl className="mt-3 space-y-2.5">
                  <div>
                    <dt className="text-xs text-ink-500">{t("services.starts")}</dt>
                    <dd className="mt-0.5 text-sm font-semibold text-ink-900">{formatDateTime(service.startTime)}</dd>
                  </div>
                  <div>
                    <dt className="text-xs text-ink-500">{t("services.ends")}</dt>
                    <dd className="mt-0.5 text-sm font-semibold text-ink-900">{formatDateTime(service.endTime)}</dd>
                  </div>
                </dl>
                <p className="mt-3 inline-flex items-center gap-2 text-xs font-medium text-ink-500">
                  <Clock3 aria-hidden="true" size={14} />
                  {formatDuration(service.startTime, service.endTime)}
                </p>
              </div>
              <div className="border-t border-border-subtle pt-4 sm:border-s sm:border-t-0 sm:ps-4 sm:pt-0">
                <div className="flex items-center gap-2 text-xs font-bold uppercase tracking-[0.12em] text-ink-500">
                  <ReceiptText aria-hidden="true" size={14} />
                  {t("services.paidTotal")}
                </div>
                <p dir="auto" className="bidi-auto mt-3 text-2xl font-semibold tracking-[-0.04em] text-ink-950">{formatCurrency(service.totalPrice)}</p>
                <p className="mt-2 font-reading text-xs leading-5 text-ink-500">{windowPresentation.description}</p>
              </div>
            </div>
          </section>
        </div>

        <section className="card-inverse p-5 sm:p-6" aria-labelledby={`access-${service.reservationId}`}>
          <div aria-hidden="true" className="absolute -right-12 -top-12 size-40 rounded-full bg-brand-400/10 blur-3xl" />
          <div className="relative">
            <div className="flex items-start justify-between gap-3">
              <div>
                <p className="text-xs font-bold uppercase tracking-[0.14em] text-brand-200">{t("services.secureAccess")}</p>
                <h3 id={`access-${service.reservationId}`} className="mt-1 text-lg font-semibold text-white">{t("services.connectionDetails")}</h3>
              </div>
              <span className={credentialsReady ? "icon-tile-inverse size-10 text-emerald-200" : "icon-tile-inverse size-10"}>
                {credentialsReady ? <ShieldCheck aria-hidden="true" size={18} /> : <KeyRound aria-hidden="true" size={18} />}
              </span>
            </div>

            {credentialsReady ? (
              <div className="mt-5 space-y-2.5">
                <SecureAccessField icon={Network} label={t("services.ipAddress")} value={service.assignedIp} copied={copiedField === "ip"} onCopy={() => void copyValue("ip", service.assignedIp)} />
                <SecureAccessField icon={UserRound} label={t("services.username")} value={service.assignedUsername} copied={copiedField === "username"} onCopy={() => void copyValue("username", service.assignedUsername)} />
                <SecureAccessField
                  icon={KeyRound}
                  label={t("services.password")}
                  value={service.assignedPassword}
                  concealed
                  revealed={passwordVisible}
                  copied={copiedField === "password"}
                  onToggleVisibility={() => setPasswordVisible((visible) => !visible)}
                  onCopy={() => void copyValue("password", service.assignedPassword)}
                />
                {copyError && <p className="font-reading text-xs leading-5 text-rose-200" role="alert">{copyError}</p>}
                <p className="flex items-start gap-2 pt-1 font-reading text-xs leading-5 text-ink-400">
                  <ShieldCheck aria-hidden="true" className="mt-0.5 shrink-0 text-brand-200" size={14} />
                  {t("services.privateNote")}
                </p>
              </div>
            ) : (
              <div className="mt-6 flex min-h-44 flex-col items-center justify-center rounded-control border border-dashed border-white/15 bg-white/[0.045] px-5 py-6 text-center">
                <span className="icon-tile-inverse">
                  <KeyRound aria-hidden="true" size={19} />
                </span>
                <p className="mt-4 text-sm font-semibold text-white">{t("services.preparing")}</p>
                <p className="mt-2 max-w-xs font-reading text-xs leading-5 text-ink-400">{t("services.notAssigned")}</p>
              </div>
            )}
          </div>
        </section>
      </div>
    </article>
  );
}

export function MyServicesPage() {
  const { t } = useTranslation();
  const { formatNumber } = useLocale();
  const [services, setServices] = useState<MyService[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [requestVersion, setRequestVersion] = useState(0);
  const currentTime = useCurrentTime();

  useEffect(() => {
    let cancelled = false;

    const load = async () => {
      setLoading(true);
      setError("");
      try {
        const data = await reservationsApi.getMyServices();
        if (!cancelled) {
          setServices(data);
        }
      } catch (loadError) {
        if (!cancelled) {
          setServices([]);
          setError(getApiErrorMessage(loadError, t("services.loadError")));
        }
      } finally {
        if (!cancelled) {
          setLoading(false);
        }
      }
    };

    void load();
    return () => {
      cancelled = true;
    };
  }, [requestVersion, t]);

  const summary = useMemo(() => {
    const active = services.filter((service) => {
      const startsAt = new Date(service.startTime).getTime();
      const endsAt = new Date(service.endTime).getTime();
      return currentTime >= startsAt && currentTime < endsAt;
    }).length;
    const accessReady = services.filter(hasCredentials).length;
    return { active, accessReady };
  }, [currentTime, services]);

  return (
    <div className="page-stack">
      <AccountNavigation />

      <PageHeader
        eyebrow={t("services.eyebrow")}
        title={t("services.title")}
        description={t("services.description")}
        icon={KeyRound}
        actions={
          <Link to="/servers" className="btn-primary">
            <ServerIcon aria-hidden="true" size={17} />
            {t("services.reserveHardware")}
          </Link>
        }
      />

      <section className="grid gap-3 sm:grid-cols-3" aria-label={t("services.summaryAria")}>
        <AccountMetricCard icon={CheckCircle2} label={t("services.paidServices")} value={loading ? "-" : formatNumber(services.length)} detail={t("services.paidServicesDetail")} tone="brand" />
        <AccountMetricCard icon={CalendarClock} label={t("services.activeNow")} value={loading ? "-" : formatNumber(summary.active)} detail={t("services.activeNowDetail")} tone="success" />
        <AccountMetricCard icon={ShieldCheck} label={t("services.accessReady")} value={loading ? "-" : formatNumber(summary.accessReady)} detail={t("services.accessReadyDetail")} />
      </section>

      <section aria-labelledby="service-records-title">
        <div className="mb-5 flex flex-col gap-2 sm:flex-row sm:items-end sm:justify-between">
          <div>
            <p className="section-kicker">{t("services.provisioned")}</p>
            <h2 id="service-records-title" className="mt-1 text-2xl font-semibold tracking-[-0.03em] text-ink-950">{t("services.records")}</h2>
          </div>
          {!loading && services.length > 0 && <p className="text-sm font-medium text-ink-500">{t("services.paidOnly")}</p>}
        </div>

        {loading ? (
          <div className="space-y-4" role="status" aria-label={t("services.loading")}>
            <ServiceSkeleton />
            <ServiceSkeleton />
          </div>
        ) : error ? (
          <div className="state-panel" role="alert">
            <span className="icon-tile-neutral">
              <AlertCircle aria-hidden="true" size={21} />
            </span>
            <h2 className="mt-4 card-title">{t("services.unavailableTitle")}</h2>
            <p className="mt-2 max-w-md body-copy">{error}</p>
            <button type="button" className="btn-primary mt-5" onClick={() => setRequestVersion((version) => version + 1)}>
              <RotateCcw aria-hidden="true" size={16} />
              {t("actions.retry")}
            </button>
          </div>
        ) : services.length === 0 ? (
          <div className="state-panel">
            <span className="icon-tile">
              <KeyRound aria-hidden="true" size={21} />
            </span>
            <h2 className="mt-4 card-title">{t("services.emptyTitle")}</h2>
            <p className="mt-2 max-w-md body-copy">{t("services.emptyCopy")}</p>
            <div className="mt-5 flex flex-col gap-2 sm:flex-row">
              <Link to="/my-reservations" className="btn-secondary">{t("services.reviewReservations")}</Link>
              <Link to="/servers" className="btn-primary">
                {t("services.browseHardware")}
                <ArrowRight aria-hidden="true" className="directional-icon" size={16} />
              </Link>
            </div>
          </div>
        ) : (
          <div className="content-swap-enter space-y-4">
            {services.map((service) => (
              <ServiceRecord key={service.reservationId} service={service} currentTime={currentTime} />
            ))}
          </div>
        )}
      </section>
    </div>
  );
}
