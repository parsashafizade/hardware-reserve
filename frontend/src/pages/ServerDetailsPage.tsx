import { useEffect, useState } from "react";
import {
  AlertTriangle,
  ArrowLeft,
  CalendarPlus,
  CheckCircle2,
  CircuitBoard,
  Clock3,
  Cpu,
  ReceiptText,
  RotateCcw,
  ShieldCheck,
  Sparkles,
} from "lucide-react";
import { Link, useNavigate, useParams } from "react-router-dom";
import { useTranslation } from "react-i18next";
import { serversApi } from "../api/serversApi";
import { useAuth } from "../auth/useAuth";
import { ServerSpecGrid } from "../components/server/ServerSpecGrid";
import { PageHeader } from "../components/ui/PageHeader";
import { StatusBadge } from "../components/ui/StatusBadge";
import type { Server } from "../types/api";
import { getApiErrorMessage } from "../utils/errors";
import { formatCurrency } from "../utils/format";
import { getComputeTypeLabel, hasDedicatedGpu } from "../utils/serverPresentation";

function ServerDetailsSkeleton({ label }: { label: string }) {
  return (
    <div className="page-stack" role="status" aria-label={label}>
      <div className="space-y-3">
        <div className="skeleton h-4 w-32" />
        <div className="skeleton h-11 w-full max-w-lg" />
        <div className="skeleton h-5 w-full max-w-2xl" />
      </div>
      <div className="skeleton h-80 rounded-panel" />
      <div className="grid gap-6 lg:grid-cols-[minmax(0,1fr)_22rem]">
        <div className="skeleton h-96 rounded-card" />
        <div className="skeleton h-80 rounded-card" />
      </div>
    </div>
  );
}

export function ServerDetailsPage() {
  const { t } = useTranslation();
  const { id } = useParams();
  const navigate = useNavigate();
  const { isAuthenticated } = useAuth();

  const [server, setServer] = useState<Server | null>(null);
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(true);
  const [requestVersion, setRequestVersion] = useState(0);

  useEffect(() => {
    let cancelled = false;

    const load = async () => {
      setLoading(true);
      setError("");

      try {
        const serverId = Number(id);
        if (!Number.isFinite(serverId)) {
          throw new Error(t("serverDetails.invalidId"));
        }

        const response = await serversApi.getServerById(serverId);
        if (!cancelled) {
          setServer(response);
        }
      } catch (loadError) {
        if (!cancelled) {
          setServer(null);
          setError(getApiErrorMessage(loadError, t("serverDetails.notFound")));
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
  }, [id, requestVersion, t]);

  const handleReserve = () => {
    const serverId = Number(id);
    if (!isAuthenticated) {
      navigate(`/login?returnUrl=${encodeURIComponent(`/reserve/${serverId}`)}`);
      return;
    }

    navigate(`/reserve/${serverId}`);
  };

  if (loading) {
    return <ServerDetailsSkeleton label={t("serverDetails.loading")} />;
  }

  if (!server) {
    return (
      <div className="state-panel" role="alert">
        <span className="icon-tile-neutral">
          <AlertTriangle aria-hidden="true" size={21} />
        </span>
        <h1 className="mt-4 card-title">{t("serverDetails.unavailableTitle")}</h1>
        <p className="mt-2 max-w-md body-copy">{error || t("serverDetails.notFound")}</p>
        <div className="mt-5 flex flex-wrap justify-center gap-2">
          <button type="button" className="btn-primary" onClick={() => setRequestVersion((version) => version + 1)}>
            <RotateCcw aria-hidden="true" size={16} />
            {t("actions.retry")}
          </button>
          <Link to="/servers" className="btn-secondary">
            <ArrowLeft aria-hidden="true" className="directional-icon" size={16} />
            {t("serverDetails.backToCatalog")}
          </Link>
        </div>
      </div>
    );
  }

  const gpuAccelerated = hasDedicatedGpu(server);
  const primaryHardware = gpuAccelerated ? server.gpu : server.cpu;
  const supportingHardware = gpuAccelerated ? server.cpu : t("server.labels.dedicatedProcessor");
  const reservable = server.isActive && server.operationalStatus === "Available";
  const availabilityLabel = server.operationalStatus === "Maintenance"
    ? t("serverCard.maintenance")
    : server.operationalStatus === "TemporarilyUnavailable"
      ? t("serverCard.temporarilyUnavailable")
      : reservable ? t("serverDetails.available") : t("serverDetails.unavailable");

  return (
    <div className="page-stack">
      <PageHeader
        eyebrow={t("serverDetails.eyebrow")}
        title={t("serverDetails.title")}
        description={t("serverDetails.description")}
        icon={gpuAccelerated ? CircuitBoard : Cpu}
        actions={
          <Link to="/servers" className="btn-secondary">
            <ArrowLeft aria-hidden="true" className="directional-icon" size={16} />
            {t("serverDetails.backToCatalog")}
          </Link>
        }
      />

      <section className="card-inverse p-0" aria-labelledby="configuration-title">
        <div
          aria-hidden="true"
          className="absolute -right-24 -top-24 size-80 rounded-full bg-brand-400/15 blur-3xl"
        />
        <div
          aria-hidden="true"
          className="absolute -bottom-36 left-1/4 size-72 rounded-full bg-cyan-300/10 blur-3xl"
        />

        <div className="relative grid gap-6 p-6 sm:p-7 lg:grid-cols-[minmax(0,1fr)_20rem] lg:items-center lg:p-8">
          <div>
            <div className="flex flex-wrap items-center gap-2">
              <span className="inline-flex items-center gap-2 rounded-pill border border-white/15 bg-white/10 px-3 py-1.5 text-xs font-semibold text-brand-100 backdrop-blur-md">
                {gpuAccelerated ? <Sparkles aria-hidden="true" size={14} /> : <Cpu aria-hidden="true" size={14} />}
                {getComputeTypeLabel(server)}
              </span>
              <span
                className={
                  reservable
                    ? "inline-flex items-center gap-2 rounded-pill border border-emerald-300/20 bg-emerald-300/10 px-3 py-1.5 text-xs font-semibold text-emerald-200"
                    : "inline-flex items-center gap-2 rounded-pill border border-amber-300/20 bg-amber-300/10 px-3 py-1.5 text-xs font-semibold text-amber-200"
                }
              >
                <span className="size-1.5 rounded-full bg-current" />
                {availabilityLabel}
              </span>
            </div>

            <p className="mt-6 text-xs font-bold uppercase tracking-[0.18em] text-brand-300">{t("serverDetails.primaryHardware")}</p>
            <h1 id="configuration-title" dir="auto" className="bidi-auto mt-3 max-w-3xl text-3xl font-semibold tracking-[-0.045em] text-white sm:text-4xl">
              {primaryHardware}
            </h1>
            <p dir="auto" className="bidi-auto mt-4 max-w-2xl text-base leading-7 text-ink-300">{supportingHardware}</p>

            <div className="mt-6 grid gap-3 sm:grid-cols-3">
              <div className="flex items-center gap-3 rounded-control border border-white/10 bg-white/[0.05] p-3.5">
                <Clock3 aria-hidden="true" className="text-brand-200" size={18} />
                <p className="text-xs font-medium text-ink-300">{t("serverDetails.hourlyDaily")}</p>
              </div>
              <div className="flex items-center gap-3 rounded-control border border-white/10 bg-white/[0.05] p-3.5">
                <ShieldCheck aria-hidden="true" className="text-brand-200" size={18} />
                <p className="text-xs font-medium text-ink-300">{t("serverDetails.conflictAware")}</p>
              </div>
              <div className="flex items-center gap-3 rounded-control border border-white/10 bg-white/[0.05] p-3.5">
                <ReceiptText aria-hidden="true" className="text-brand-200" size={18} />
                <p className="text-xs font-medium text-ink-300">{t("serverDetails.upfrontPrice")}</p>
              </div>
            </div>
          </div>

          <div className="rounded-card border border-white/15 bg-white/[0.09] p-5 shadow-dark backdrop-blur-xl">
            <p className="text-xs font-bold uppercase tracking-[0.16em] text-brand-300">{t("serverDetails.flexibleAccess")}</p>
            <div className="mt-5 border-b border-white/10 pb-5">
              <p className="text-sm text-ink-400">{t("server.labels.hourlyRate")}</p>
              <p dir="auto" className="bidi-auto mt-1 inline-flex items-baseline gap-2 text-4xl font-semibold tracking-[-0.05em] text-white">
                {formatCurrency(server.pricePerHour)}
                <span className="text-sm font-medium tracking-normal text-ink-400">{t("server.labels.perHour")}</span>
              </p>
            </div>
            <div className="flex items-center justify-between gap-4 pt-5">
              <p className="text-sm text-ink-400">{t("server.labels.dailyRate")}</p>
              <p dir="auto" className="bidi-auto text-lg font-semibold text-white">{formatCurrency(server.pricePerDay)}</p>
            </div>
          </div>
        </div>
      </section>

      <div className="grid gap-5 lg:grid-cols-[minmax(0,1fr)_22rem] lg:items-start">
        <section className="card" aria-labelledby="technical-specifications-title">
          <div className="flex items-start gap-3 border-b border-border-subtle pb-5">
            <span className="icon-tile">
              <CircuitBoard aria-hidden="true" size={19} />
            </span>
            <div>
              <p className="section-kicker">{t("serverDetails.profile")}</p>
              <h2 id="technical-specifications-title" className="mt-1 card-title">
                {t("serverDetails.technicalSpecs")}
              </h2>
              <p className="mt-1 text-sm text-ink-500">{t("serverDetails.specsDescription")}</p>
            </div>
          </div>
          <ServerSpecGrid server={server} className="mt-5" />
        </section>

        <aside className="card lg:sticky lg:top-28" aria-labelledby="reservation-action-title">
          <div className="flex items-start justify-between gap-3">
            <div>
              <p className="section-kicker">{t("serverDetails.nextStep")}</p>
              <h2 id="reservation-action-title" className="mt-1 card-title">
                {t("serverDetails.chooseTime")}
              </h2>
            </div>
            <StatusBadge tone={reservable ? "success" : "warning"} showDot>
              {availabilityLabel}
            </StatusBadge>
          </div>

          <div className="mt-5 rounded-control border border-border-subtle bg-surface-muted/65 p-4">
            <div className="flex items-center gap-3">
              <span className="icon-tile-success size-9">
                <CheckCircle2 aria-hidden="true" size={17} />
              </span>
              <div>
                <p className="text-sm font-semibold text-ink-900">{t("serverDetails.availabilityTitle")}</p>
                <p className="mt-0.5 text-xs leading-5 text-ink-500">{t("serverDetails.availabilityCopy")}</p>
              </div>
            </div>
          </div>

          <dl className="mt-5 space-y-3 border-y border-border-subtle py-4 text-sm">
            <div className="flex items-center justify-between gap-4">
              <dt className="text-ink-500">{t("serverDetails.hourly")}</dt>
              <dd dir="auto" className="bidi-auto font-semibold text-ink-900">{formatCurrency(server.pricePerHour)}</dd>
            </div>
            <div className="flex items-center justify-between gap-4">
              <dt className="text-ink-500">{t("serverDetails.daily")}</dt>
              <dd dir="auto" className="bidi-auto font-semibold text-ink-900">{formatCurrency(server.pricePerDay)}</dd>
            </div>
          </dl>

          <button
            className="btn-primary mt-5 w-full"
            onClick={handleReserve}
            type="button"
            disabled={!reservable}
          >
            <CalendarPlus aria-hidden="true" size={17} />
            {isAuthenticated ? t("serverDetails.selectTime") : t("serverDetails.signInToReserve")}
          </button>
          <p className="mt-3 text-center text-xs leading-5 text-ink-500">
            {t("serverDetails.confirmationNote")}
          </p>
        </aside>
      </div>
    </div>
  );
}
