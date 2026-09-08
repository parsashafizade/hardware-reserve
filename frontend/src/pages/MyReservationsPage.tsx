import { useEffect, useMemo, useState, type ReactNode } from "react";
import {
  Activity,
  AlertCircle,
  ArrowRight,
  CalendarClock,
  CalendarDays,
  CheckCircle2,
  CircuitBoard,
  Clock3,
  Cpu,
  Download,
  HardDrive,
  LoaderCircle,
  MemoryStick,
  MonitorCog,
  ReceiptText,
  RotateCcw,
  Server as ServerIcon,
  WalletCards,
  type LucideIcon,
} from "lucide-react";
import { Link } from "react-router-dom";
import { useTranslation } from "react-i18next";
import { reservationsApi } from "../api/reservationsApi";
import { AccountMetricCard } from "../components/account/AccountMetricCard";
import { AccountNavigation } from "../components/account/AccountNavigation";
import { PaymentStatusBadge } from "../components/account/AccountStatusBadges";
import { PageHeader } from "../components/ui/PageHeader";
import { StatusBadge } from "../components/ui/StatusBadge";
import type { MyReservation } from "../types/api";
import { downloadBlob } from "../utils/download";
import { getApiErrorMessage } from "../utils/errors";
import { formatCurrency, formatDateTime, formatDuration } from "../utils/format";
import { getComputeTypeLabel, hasDedicatedGpu } from "../utils/serverPresentation";
import { useLocale } from "../i18n/useLocale";
import { useCurrentTime } from "../hooks/useCurrentTime";

interface SpecificationPillProps {
  icon: LucideIcon;
  children: ReactNode;
}

function normalizeStatus(status: string): string {
  return status.replace(/[\s_-]/g, "").toLowerCase();
}

function SpecificationPill({ icon: Icon, children }: SpecificationPillProps) {
  return (
    <span className="inline-flex items-center gap-2 rounded-pill border border-border-subtle bg-surface-muted/65 px-3 py-1.5 text-xs font-medium text-ink-600">
      <Icon aria-hidden="true" className="text-brand-600" size={14} />
      <bdi dir="auto" className="bidi-auto">{children}</bdi>
    </span>
  );
}

function ReservationSkeleton() {
  return (
    <div className="overflow-hidden rounded-card border border-border-subtle bg-white shadow-card" aria-hidden="true">
      <div className="flex justify-between gap-4 border-b border-border-subtle p-5">
        <div className="space-y-2">
          <div className="skeleton h-4 w-28" />
          <div className="skeleton h-6 w-56" />
        </div>
        <div className="skeleton h-7 w-28" />
      </div>
      <div className="grid gap-6 p-5 lg:grid-cols-3">
        <div className="skeleton h-32" />
        <div className="skeleton h-32" />
        <div className="skeleton h-32" />
      </div>
    </div>
  );
}

function ReservationRecord({ reservation, currentTime }: { reservation: MyReservation; currentTime: number }) {
  const { t } = useTranslation();
  const { formatNumber } = useLocale();
  const gpuAccelerated = hasDedicatedGpu(reservation.server);
  const primaryHardware = gpuAccelerated ? reservation.server.gpu : reservation.server.cpu;
  const supportingHardware = gpuAccelerated ? reservation.server.cpu : t("server.labels.dedicatedProcessor");
  const normalizedReservationStatus = normalizeStatus(reservation.status);
  const pendingPayment = normalizedReservationStatus === "pendingpayment";
  const paid = normalizedReservationStatus === "paid";
  const cancelled = normalizedReservationStatus === "cancelled";
  const startsAt = new Date(reservation.startTime).getTime();
  const endsAt = new Date(reservation.endTime).getTime();
  const phase = cancelled
    ? { label: t("reservations.phase.cancelled"), detail: t("reservations.cancelledCopy"), tone: "neutral" as const }
    : pendingPayment
      ? { label: t("reservations.phase.awaitingPayment"), detail: t("reservations.pendingCopy"), tone: "warning" as const }
      : currentTime < startsAt
        ? { label: t("reservations.phase.upcoming"), detail: t("reservations.upcomingCopy"), tone: "brand" as const }
        : currentTime < endsAt
          ? { label: t("reservations.phase.active"), detail: t("reservations.activeCopy"), tone: "success" as const }
          : { label: t("reservations.phase.completed"), detail: t("reservations.completedCopy"), tone: "neutral" as const };

  return (
    <article className="overflow-hidden rounded-card border border-border-subtle bg-white shadow-card transition duration-base hover:border-brand-200 hover:shadow-lift">
      <div className="flex flex-col gap-4 border-b border-border-subtle bg-gradient-to-r from-white via-brand-50/40 to-white p-5 sm:flex-row sm:items-center sm:justify-between sm:px-6">
        <div className="flex items-center gap-3">
          <span className="icon-tile">
            {gpuAccelerated ? <CircuitBoard aria-hidden="true" size={19} /> : <Cpu aria-hidden="true" size={19} />}
          </span>
          <div>
            <p className="text-xs font-bold uppercase tracking-[0.14em] text-brand-700">{t("reservations.reservationNumber", { id: formatNumber(reservation.reservationId) })}</p>
            <h2 dir="auto" className="bidi-auto mt-1 text-lg font-semibold tracking-[-0.025em] text-ink-950">{primaryHardware}</h2>
          </div>
        </div>
        <div className="flex flex-wrap items-center gap-2">
          <StatusBadge tone={phase.tone} showDot>{phase.label}</StatusBadge>
          {!pendingPayment && <PaymentStatusBadge status={reservation.paymentStatus} />}
        </div>
      </div>

      <div className="grid gap-6 p-5 sm:p-6 lg:grid-cols-[1.15fr_1fr_0.75fr] lg:[&>*+*]:border-s lg:[&>*+*]:border-border-subtle">
        <section aria-label={t("reservations.hardwareAria")} className="min-w-0 lg:pe-6">
          <p className="text-xs font-bold uppercase tracking-[0.14em] text-ink-500">{t("reservations.hardware")}</p>
          <p dir="auto" className="bidi-auto mt-3 truncate text-sm font-semibold text-ink-900" title={supportingHardware}>{supportingHardware}</p>
          <p className="mt-1 text-xs font-medium text-brand-700">{getComputeTypeLabel(reservation.server)}</p>
          <div className="mt-4 flex flex-wrap gap-2">
            <SpecificationPill icon={MemoryStick}>{reservation.server.ram}</SpecificationPill>
            <SpecificationPill icon={HardDrive}>{reservation.server.storage}</SpecificationPill>
            <SpecificationPill icon={MonitorCog}>{reservation.server.os}</SpecificationPill>
          </div>
        </section>

        <section aria-label={t("reservations.windowAria")} className="lg:px-6">
          <div className="flex items-center gap-2 text-xs font-bold uppercase tracking-[0.14em] text-ink-500">
            <CalendarClock aria-hidden="true" size={15} />
            {t("reservations.window")}
          </div>
          <dl className="mt-4 space-y-3">
            <div>
              <dt className="text-xs text-ink-500">{t("reservations.starts")}</dt>
              <dd className="mt-1 text-sm font-semibold text-ink-900">{formatDateTime(reservation.startTime)}</dd>
            </div>
            <div>
              <dt className="text-xs text-ink-500">{t("reservations.ends")}</dt>
              <dd className="mt-1 text-sm font-semibold text-ink-900">{formatDateTime(reservation.endTime)}</dd>
            </div>
          </dl>
          <p className="mt-3 inline-flex items-center gap-2 text-xs font-medium text-ink-500">
            <Clock3 aria-hidden="true" size={14} />
            {formatDuration(reservation.startTime, reservation.endTime)}
          </p>
        </section>

        <section aria-label={t("reservations.costAria")} className="lg:ps-6">
          <div className="flex items-center gap-2 text-xs font-bold uppercase tracking-[0.14em] text-ink-500">
            <ReceiptText aria-hidden="true" size={15} />
            {t("reservations.total")}
          </div>
          <p dir="auto" className="bidi-auto mt-4 text-2xl font-semibold tracking-[-0.04em] text-ink-950">{formatCurrency(reservation.totalPrice)}</p>
          <p className="mt-2 text-xs leading-5 text-ink-500">{phase.detail}</p>
        </section>
      </div>

      <div className="flex flex-col gap-2 border-t border-border-subtle bg-surface-muted/35 px-5 py-4 sm:flex-row sm:items-center sm:justify-between sm:px-6">
        <Link to={`/server/${reservation.server.serverId}`} className="btn-secondary min-h-10 px-4 py-2">
          <ServerIcon aria-hidden="true" size={16} />
          {t("reservations.viewHardware")}
        </Link>

        {pendingPayment && (
          <Link to={`/checkout/${reservation.reservationId}`} className="btn-primary min-h-10 px-4 py-2">
            <WalletCards aria-hidden="true" size={16} />
            {t("reservations.completePayment")}
            <ArrowRight aria-hidden="true" className="directional-icon" size={15} />
          </Link>
        )}

        {(paid || cancelled) && (
          <Link to={`/my-reservations/${reservation.reservationId}`} className={`${cancelled ? "btn-secondary" : "btn-primary"} min-h-10 px-4 py-2`}>
            <Activity aria-hidden="true" size={16} />
            {t("cockpit.eyebrow")}
            <ArrowRight aria-hidden="true" className="directional-icon" size={15} />
          </Link>
        )}
      </div>
    </article>
  );
}

export function MyReservationsPage() {
  const { t } = useTranslation();
  const { formatNumber } = useLocale();
  const [reservations, setReservations] = useState<MyReservation[]>([]);
  const [loading, setLoading] = useState(true);
  const [exporting, setExporting] = useState(false);
  const [error, setError] = useState("");
  const [requestVersion, setRequestVersion] = useState(0);
  const currentTime = useCurrentTime();

  useEffect(() => {
    let cancelled = false;

    const load = async () => {
      setLoading(true);
      setError("");

      try {
        const data = await reservationsApi.getMyReservations();
        if (!cancelled) {
          setReservations(data);
        }
      } catch (loadError) {
        if (!cancelled) {
          setReservations([]);
          setError(getApiErrorMessage(loadError, t("reservations.loadError")));
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
    const pending = reservations.filter((reservation) => normalizeStatus(reservation.status) === "pendingpayment").length;
    const paid = reservations.filter((reservation) => normalizeStatus(reservation.status) === "paid").length;
    const totalValue = reservations.reduce((total, reservation) => total + reservation.totalPrice, 0);
    return { pending, paid, totalValue };
  }, [reservations]);

  const exportCsv = async () => {
    setExporting(true);
    setError("");

    try {
      const blob = await reservationsApi.exportMyReservationsCsv();
      downloadBlob(blob, `my-reservations-${Date.now()}.csv`);
    } catch (exportError) {
      setError(getApiErrorMessage(exportError, t("reservations.exportError")));
    } finally {
      setExporting(false);
    }
  };

  return (
    <div className="page-stack">
      <AccountNavigation />

      <PageHeader
        eyebrow={t("reservations.eyebrow")}
        title={t("reservations.title")}
        description={t("reservations.description")}
        icon={CalendarDays}
        actions={
          <>
            <Link to="/servers" className="btn-secondary">
              <ServerIcon aria-hidden="true" size={17} />
              {t("reservations.browseHardware")}
            </Link>
            <button className="btn-primary" type="button" onClick={() => void exportCsv()} disabled={loading || exporting}>
              {exporting ? <LoaderCircle aria-hidden="true" className="animate-spin" size={17} /> : <Download aria-hidden="true" size={17} />}
              {exporting ? t("reservations.preparingCsv") : t("reservations.exportCsv")}
            </button>
          </>
        }
      />

      <section className="grid gap-3 sm:grid-cols-3" aria-label={t("reservations.summaryAria")}>
        <AccountMetricCard icon={CalendarDays} label={t("reservations.all")} value={loading ? "-" : formatNumber(reservations.length)} detail={t("reservations.allDetail")} tone="brand" />
        <AccountMetricCard icon={WalletCards} label={t("reservations.awaiting")} value={loading ? "-" : formatNumber(summary.pending)} detail={t("reservations.awaitingDetail")} />
        <AccountMetricCard icon={CheckCircle2} label={t("reservations.paid")} value={loading ? "-" : formatNumber(summary.paid)} detail={t("reservations.paidDetail", { value: formatCurrency(summary.totalValue) })} tone="success" />
      </section>

      {error && reservations.length > 0 && (
        <div className="alert-error flex items-start gap-2.5" role="alert">
          <AlertCircle aria-hidden="true" className="mt-0.5" size={17} />
          <p>{error}</p>
        </div>
      )}

      <section aria-labelledby="reservation-history-title">
        <div className="mb-5 flex flex-col gap-2 sm:flex-row sm:items-end sm:justify-between">
          <div>
            <p className="section-kicker">{t("reservations.history")}</p>
            <h2 id="reservation-history-title" className="mt-1 text-2xl font-semibold tracking-[-0.03em] text-ink-950">{t("reservations.records")}</h2>
          </div>
          {!loading && reservations.length > 0 && <p className="text-sm font-medium text-ink-500">{t("reservations.newest")}</p>}
        </div>

        {loading ? (
          <div className="space-y-4" role="status" aria-label={t("reservations.loading")}>
            <ReservationSkeleton />
            <ReservationSkeleton />
          </div>
        ) : error && reservations.length === 0 ? (
          <div className="state-panel" role="alert">
            <span className="icon-tile-neutral">
              <AlertCircle aria-hidden="true" size={21} />
            </span>
            <h2 className="mt-4 card-title">{t("reservations.unavailableTitle")}</h2>
            <p className="mt-2 max-w-md body-copy">{error}</p>
            <button type="button" className="btn-primary mt-5" onClick={() => setRequestVersion((version) => version + 1)}>
              <RotateCcw aria-hidden="true" size={16} />
              {t("actions.retry")}
            </button>
          </div>
        ) : reservations.length === 0 ? (
          <div className="state-panel">
            <span className="icon-tile">
              <CalendarClock aria-hidden="true" size={21} />
            </span>
            <h2 className="mt-4 card-title">{t("reservations.emptyTitle")}</h2>
            <p className="mt-2 max-w-md body-copy">{t("reservations.emptyCopy")}</p>
            <Link to="/servers" className="btn-primary mt-5">
              {t("reservations.browseAvailable")}
              <ArrowRight aria-hidden="true" className="directional-icon" size={16} />
            </Link>
          </div>
        ) : (
          <div className="content-swap-enter space-y-4">
            {reservations.map((reservation) => (
              <ReservationRecord key={reservation.reservationId} reservation={reservation} currentTime={currentTime} />
            ))}
          </div>
        )}
      </section>
    </div>
  );
}
