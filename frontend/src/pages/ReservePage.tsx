import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import {
  AlertCircle,
  AlertTriangle,
  ArrowLeft,
  ArrowRight,
  CalendarCheck2,
  CalendarDays,
  Check,
  CheckCircle2,
  CircuitBoard,
  Clock3,
  Cpu,
  HardDrive,
  Lightbulb,
  LoaderCircle,
  MemoryStick,
  Minus,
  MonitorCog,
  Plus,
  ReceiptText,
  RefreshCw,
  ShieldCheck,
  Sparkles,
  TimerReset,
} from "lucide-react";
import { Link, useNavigate, useParams } from "react-router-dom";
import { useTranslation } from "react-i18next";
import { reservationsApi } from "../api/reservationsApi";
import { serversApi } from "../api/serversApi";
import { AvailabilityTimeline } from "../components/reservation/AvailabilityTimeline";
import { IRAN_TIME_ZONE } from "../i18n/dateTime";
import { useLocale } from "../i18n/useLocale";
import type { BusyReservationSlot, CreateReservationResult, ReservationQuote, Server, SuggestReservationResult } from "../types/api";
import { getApiErrorMessage, isApiCode } from "../utils/errors";
import { formatCurrency } from "../utils/format";
import { getComputeTypeLabel, hasDedicatedGpu } from "../utils/serverPresentation";
import { useCurrentTime } from "../hooks/useCurrentTime";

type BookingMode = "hourly" | "daily";

interface ReservationWindowPreview {
  start: Date | null;
  end: Date | null;
  durationHours: number;
  isValid: boolean;
  validationMessage: string | null;
}

const HOUR_MS = 60 * 60 * 1000;
const DAY_MS = 24 * HOUR_MS;

function roundToNextHour(date: Date): Date {
  const next = new Date(date);
  next.setMinutes(0, 0, 0);

  if (next <= date) {
    next.setHours(next.getHours() + 1);
  }

  return next;
}

function toLocalDateTimeInputValue(date: Date): string {
  const year = date.getFullYear();
  const month = String(date.getMonth() + 1).padStart(2, "0");
  const day = String(date.getDate()).padStart(2, "0");
  const hours = String(date.getHours()).padStart(2, "0");
  const minutes = String(date.getMinutes()).padStart(2, "0");
  return `${year}-${month}-${day}T${hours}:${minutes}`;
}

function toDateInputValue(date: Date): string {
  const year = date.getFullYear();
  const month = String(date.getMonth() + 1).padStart(2, "0");
  const day = String(date.getDate()).padStart(2, "0");
  return `${year}-${month}-${day}`;
}

function parseLocalDateAtMidnight(value: string): Date | null {
  if (!value) {
    return null;
  }

  const parsed = new Date(`${value}T00:00`);
  if (Number.isNaN(parsed.getTime())) {
    return null;
  }

  return parsed;
}

function overlaps(startA: Date, endA: Date, startB: Date, endB: Date): boolean {
  return startA < endB && endA > startB;
}

function ReservationPageSkeleton({ label }: { label: string }) {
  return (
    <div className="page-stack" role="status" aria-label={label}>
      <div className="space-y-3">
        <div className="skeleton h-4 w-36" />
        <div className="skeleton h-11 w-full max-w-xl" />
        <div className="skeleton h-5 w-full max-w-2xl" />
      </div>
      <div className="skeleton h-56 rounded-panel" />
      <div className="grid gap-6 xl:grid-cols-[minmax(0,1fr)_23rem]">
        <div className="skeleton h-[42rem] rounded-card" />
        <div className="skeleton h-[32rem] rounded-card" />
      </div>
    </div>
  );
}

export function ReservePage() {
  const { t } = useTranslation();
  const { formatDate, formatNumber } = useLocale();
  const { serverId } = useParams();
  const navigate = useNavigate();
  const currentTime = useCurrentTime(60_000);
  const formatReservationDateTime = useCallback(
    (value: string | number | Date) => formatDate(value, {
      dateStyle: "short",
      timeStyle: "short",
      timeZone: IRAN_TIME_ZONE,
    }),
    [formatDate],
  );
  const formatReservationDate = useCallback(
    (value: string | number | Date, options?: Intl.DateTimeFormatOptions) => formatDate(value, {
      ...options,
      timeZone: IRAN_TIME_ZONE,
    }),
    [formatDate],
  );

  const [server, setServer] = useState<Server | null>(null);
  const [busySlots, setBusySlots] = useState<BusyReservationSlot[]>([]);
  const [loading, setLoading] = useState(true);
  const [availabilityLoading, setAvailabilityLoading] = useState(false);

  const [bookingMode, setBookingMode] = useState<BookingMode>("hourly");
  const [hourlyStart, setHourlyStart] = useState("");
  const [hourlyDurationHours, setHourlyDurationHours] = useState("4");
  const [dailyStartDate, setDailyStartDate] = useState("");
  const [dailyDurationDays, setDailyDurationDays] = useState("1");

  const [result, setResult] = useState<CreateReservationResult | null>(null);
  const [suggestion, setSuggestion] = useState<SuggestReservationResult | null>(null);
  const [error, setError] = useState("");
  const [submitting, setSubmitting] = useState(false);
  const [suggesting, setSuggesting] = useState(false);
  const [quote, setQuote] = useState<ReservationQuote | null>(null);
  const [quoteLoading, setQuoteLoading] = useState(false);
  const [quoteError, setQuoteError] = useState("");
  const [quoteVersion, setQuoteVersion] = useState(0);
  const quoteRequestId = useRef(0);

  const reservationIntervals = useMemo(
    () =>
      busySlots.map((slot) => ({
        reservationId: slot.reservationId,
        start: new Date(slot.startTime),
        end: new Date(slot.endTime),
      })),
    [busySlots],
  );

  const isRangeAvailable = useCallback(
    (start: Date, end: Date) => reservationIntervals.every((slot) => !overlaps(start, end, slot.start, slot.end)),
    [reservationIntervals],
  );

  const reservationPreview = useMemo<ReservationWindowPreview>(() => {
    const now = new Date(currentTime);

    if (bookingMode === "hourly") {
      const start = new Date(hourlyStart);
      const duration = Number(hourlyDurationHours);

      if (!hourlyStart || Number.isNaN(start.getTime())) {
        return { start: null, end: null, durationHours: 0, isValid: false, validationMessage: t("reservation.validation.selectStart") };
      }

      if (!Number.isFinite(duration) || duration <= 0) {
        return {
          start: null,
          end: null,
          durationHours: 0,
          isValid: false,
          validationMessage: t("reservation.validation.hourlyPositive"),
        };
      }

      if (start <= now) {
        return {
          start,
          end: null,
          durationHours: duration,
          isValid: false,
          validationMessage: t("reservation.validation.startFuture"),
        };
      }

      const end = new Date(start.getTime() + duration * HOUR_MS);
      if (!isRangeAvailable(start, end)) {
        return {
          start,
          end,
          durationHours: duration,
          isValid: false,
          validationMessage: t("reservation.validation.hourlyOverlap"),
        };
      }

      return { start, end, durationHours: duration, isValid: true, validationMessage: null };
    }

    const start = parseLocalDateAtMidnight(dailyStartDate);
    const days = Number(dailyDurationDays);

    if (!start) {
      return { start: null, end: null, durationHours: 0, isValid: false, validationMessage: t("reservation.validation.selectDate") };
    }

    if (!Number.isFinite(days) || days <= 0) {
      return {
        start: null,
        end: null,
        durationHours: 0,
        isValid: false,
        validationMessage: t("reservation.validation.dailyPositive"),
      };
    }

    if (start <= now) {
      return {
        start,
        end: null,
        durationHours: days * 24,
        isValid: false,
        validationMessage: t("reservation.validation.dateFuture"),
      };
    }

    const end = new Date(start.getTime() + days * DAY_MS);
    if (!isRangeAvailable(start, end)) {
      return {
        start,
        end,
        durationHours: days * 24,
        isValid: false,
        validationMessage: t("reservation.validation.dailyOverlap"),
      };
    }

    return { start, end, durationHours: days * 24, isValid: true, validationMessage: null };
  }, [bookingMode, currentTime, dailyDurationDays, dailyStartDate, hourlyDurationHours, hourlyStart, isRangeAvailable, t]);

  const hourlyCandidates = useMemo(() => {
    const duration = Math.max(0.5, Number(hourlyDurationHours) || 0.5);
    const now = new Date(currentTime);
    const firstSlot = roundToNextHour(now);
    const slots: { key: string; label: string; timeValue: string; isDisabled: boolean }[] = [];

    for (let index = 0; index < 72; index += 1) {
      const start = new Date(firstSlot.getTime() + (index * HOUR_MS));
      const end = new Date(start.getTime() + duration * HOUR_MS);
      const isDisabled = start <= now || !isRangeAvailable(start, end);
      const localValue = toLocalDateTimeInputValue(start);

      slots.push({
        key: start.toISOString(),
        label: formatReservationDateTime(start),
        timeValue: localValue,
        isDisabled,
      });
    }

    return slots;
  }, [currentTime, formatReservationDateTime, hourlyDurationHours, isRangeAvailable]);

  const dailyCandidates = useMemo(() => {
    const days = Math.max(1, Math.floor(Number(dailyDurationDays) || 1));
    const now = new Date(currentTime);
    const items: { key: string; value: string; label: string; isDisabled: boolean }[] = [];

    for (let offset = 1; offset <= 21; offset += 1) {
      const candidateStart = new Date(now.getFullYear(), now.getMonth(), now.getDate() + offset, 0, 0, 0, 0);
      const candidateEnd = new Date(candidateStart.getTime() + (days * DAY_MS));
      const isDisabled = !isRangeAvailable(candidateStart, candidateEnd);

      items.push({
        key: candidateStart.toISOString(),
        value: toDateInputValue(candidateStart),
        label: formatReservationDate(candidateStart, { weekday: "short", month: "short", day: "numeric" }),
        isDisabled,
      });
    }

    return items;
  }, [currentTime, dailyDurationDays, formatReservationDate, isRangeAvailable]);

  const selectionConflicts = useMemo(
    () => Boolean(
      reservationPreview.start
      && reservationPreview.end
      && !isRangeAvailable(reservationPreview.start, reservationPreview.end)
    ),
    [isRangeAvailable, reservationPreview.end, reservationPreview.start],
  );

  const quoteWindow = useMemo(() => {
    if (!reservationPreview.start || !reservationPreview.end) {
      return null;
    }

    return {
      startTime: reservationPreview.start.toISOString(),
      endTime: reservationPreview.end.toISOString(),
    };
  }, [reservationPreview.end, reservationPreview.start]);

  const activeQuote = useMemo(() => {
    if (!quote || !quoteWindow) {
      return null;
    }

    return new Date(quote.startTime).getTime() === new Date(quoteWindow.startTime).getTime()
      && new Date(quote.endTime).getTime() === new Date(quoteWindow.endTime).getTime()
      ? quote
      : null;
  }, [quote, quoteWindow]);

  useEffect(() => {
    const loadData = async () => {
      if (!serverId) {
        setError(t("reservation.missingServerId"));
        setLoading(false);
        return;
      }

      setLoading(true);
      setError("");

      try {
        const parsedServerId = Number(serverId);
        const [serverData, slotsData] = await Promise.all([
          serversApi.getServerById(parsedServerId),
          reservationsApi.getBusySlots(
            parsedServerId,
            new Date().toISOString(),
            new Date(Date.now() + (30 * DAY_MS)).toISOString(),
          ),
        ]);

        const defaultHourlyStart = toLocalDateTimeInputValue(roundToNextHour(new Date()));
        const tomorrow = new Date();
        tomorrow.setDate(tomorrow.getDate() + 1);

        setServer(serverData);
        setBusySlots(slotsData);
        setHourlyStart(defaultHourlyStart);
        setDailyStartDate(toDateInputValue(tomorrow));
      } catch (loadError) {
        setError(getApiErrorMessage(loadError, t("reservation.loadError")));
      } finally {
        setLoading(false);
      }
    };

    void loadData();
  }, [serverId, t]);

  useEffect(() => {
    const requestId = ++quoteRequestId.current;

    if (!server || !quoteWindow || result) {
      setQuote(null);
      setQuoteLoading(false);
      setQuoteError("");
      return;
    }

    setQuote(null);
    setQuoteError("");
    setQuoteLoading(true);

    const timeoutId = window.setTimeout(async () => {
      try {
        const response = await reservationsApi.quoteReservation({
          serverId: server.id,
          startTime: quoteWindow.startTime,
          endTime: quoteWindow.endTime,
        });

        if (quoteRequestId.current === requestId) {
          setQuote(response);
        }
      } catch (requestError) {
        if (quoteRequestId.current === requestId) {
          setQuoteError(getApiErrorMessage(requestError, t("reservation.quoteError")));
        }
      } finally {
        if (quoteRequestId.current === requestId) {
          setQuoteLoading(false);
        }
      }
    }, 280);

    return () => {
      window.clearTimeout(timeoutId);
    };
  }, [quoteVersion, quoteWindow, result, server, t]);

  const refreshBusySlots = useCallback(async () => {
    if (!serverId) {
      return;
    }

    setAvailabilityLoading(true);
    try {
      const refreshedSlots = await reservationsApi.getBusySlots(
        Number(serverId),
        new Date().toISOString(),
        new Date(Date.now() + (30 * DAY_MS)).toISOString(),
      );
      setBusySlots(refreshedSlots);
    } catch {
      // The persisted quote and final create validation remain authoritative.
    } finally {
      setAvailabilityLoading(false);
    }
  }, [serverId]);

  const submitReservation = async () => {
    setError("");
    setResult(null);

    if (!reservationPreview.isValid || !reservationPreview.start || !reservationPreview.end || !activeQuote?.isAvailable) {
      setError(reservationPreview.validationMessage ?? t("reservation.validation.invalid"));
      return;
    }

    setSubmitting(true);

    try {
      const created = await reservationsApi.createReservation({
        serverId: Number(serverId),
        startTime: reservationPreview.start.toISOString(),
        endTime: reservationPreview.end.toISOString(),
        quotedTotalPrice: activeQuote.totalPrice,
      });

      setResult(created);
      await refreshBusySlots();
    } catch (submitError) {
      setError(getApiErrorMessage(submitError));

      if (isApiCode(submitError, "RESERVATION_TIME_CONFLICT")) {
        await refreshBusySlots();
      }

      if (
        isApiCode(submitError, "RESERVATION_TIME_CONFLICT")
        || isApiCode(submitError, "RESERVATION_QUOTE_CHANGED")
      ) {
        setQuoteVersion((version) => version + 1);
      }
    } finally {
      setSubmitting(false);
    }
  };

  const suggestReservation = async () => {
    setError("");
    setSuggestion(null);
    setSuggesting(true);

    try {
      const desiredDurationHours =
        bookingMode === "hourly"
          ? Math.max(0.5, Number(hourlyDurationHours) || 0.5)
          : Math.max(1, Number(dailyDurationDays) || 1) * 24;

      const response = await reservationsApi.suggestReservation({
        serverId: Number(serverId),
        desiredDurationHours,
      });

      setSuggestion(response);
    } catch (suggestError) {
      setError(getApiErrorMessage(suggestError));
    } finally {
      setSuggesting(false);
    }
  };

  const applySuggestion = () => {
    if (!suggestion?.suggestedStart || !suggestion.suggestedEnd) {
      return;
    }

    const suggestedStart = new Date(suggestion.suggestedStart);
    const suggestedEnd = new Date(suggestion.suggestedEnd);
    const durationHours = (suggestedEnd.getTime() - suggestedStart.getTime()) / HOUR_MS;

    setBookingMode("hourly");
    setHourlyStart(toLocalDateTimeInputValue(suggestedStart));
    setHourlyDurationHours(String(Math.max(0.5, Math.round(durationHours * 100) / 100)));
  };

  if (loading) {
    return <ReservationPageSkeleton label={t("reservation.loading")} />;
  }

  if (!server) {
    return (
      <div className="state-panel" role="alert">
        <span className="icon-tile-neutral">
          <AlertTriangle aria-hidden="true" size={21} />
        </span>
        <h1 className="mt-4 card-title">{t("reservation.unavailableTitle")}</h1>
        <p className="mt-2 max-w-md body-copy">{error || t("reservation.serverNotFound")}</p>
        <Link to="/servers" className="btn-primary mt-5">
          <ArrowLeft aria-hidden="true" className="directional-icon" size={16} />
          {t("reservation.backToCatalog")}
        </Link>
      </div>
    );
  }

  const gpuAccelerated = hasDedicatedGpu(server);
  const primaryHardware = gpuAccelerated ? server.gpu : server.cpu;
  const supportingHardware = gpuAccelerated ? server.cpu : t("server.labels.dedicatedProcessor");
  const durationLabel =
    bookingMode === "hourly"
      ? t("format.duration.hours", {
          count: Number(hourlyDurationHours) || 0,
          formattedCount: formatNumber(Number(hourlyDurationHours) || 0, { maximumFractionDigits: 2 }),
        })
      : t("format.duration.days", {
          count: Number(dailyDurationDays) || 0,
          formattedCount: formatNumber(Number(dailyDurationDays) || 0),
        });
  const minimumHourlyStart = toLocalDateTimeInputValue(roundToNextHour(new Date(currentTime)));
  const minimumDailyStart = (() => {
    const tomorrow = new Date(currentTime);
    tomorrow.setDate(tomorrow.getDate() + 1);
    return toDateInputValue(tomorrow);
  })();
  const selectedHourlyStart = hourlyStart
    ? formatReservationDateTime(new Date(hourlyStart))
    : t("reservation.notSelected");
  const selectedDailyStart = dailyStartDate
    ? formatReservationDate(new Date(`${dailyStartDate}T00:00`), {
        weekday: "short",
        year: "numeric",
        month: "short",
        day: "numeric",
      })
    : t("reservation.notSelected");
  const currentIranDate = formatReservationDate(currentTime, {
    weekday: "long",
    year: "numeric",
    month: "long",
    day: "numeric",
  });
  const currentIranTime = formatReservationDate(currentTime, {
    hour: "2-digit",
    minute: "2-digit",
  });

  return (
    <div className="page-stack">
      <header className="page-header">
        <div className="page-header-copy">
          <div className="flex items-center gap-3">
            <span className="icon-tile">
              <CalendarCheck2 aria-hidden="true" size={20} />
            </span>
            <div>
              <p className="section-kicker">{t("reservation.eyebrow")}</p>
              <h1 className="mt-1 page-title">{t("reservation.title")}</h1>
            </div>
          </div>
          <p className="page-description">
            {t("reservation.description")}
          </p>
        </div>
        <Link to={`/server/${server.id}`} className="btn-secondary">
          <ArrowLeft aria-hidden="true" className="directional-icon" size={16} />
          {t("reservation.backToSpecs")}
        </Link>
      </header>

      <section className="card-inverse p-0" aria-labelledby="selected-hardware-title">
        <div aria-hidden="true" className="absolute -right-20 -top-24 size-72 rounded-full bg-brand-400/15 blur-3xl" />
        <div className="relative grid gap-5 p-5 sm:p-6 lg:grid-cols-[minmax(0,1fr)_auto] lg:items-center">
          <div className="min-w-0">
            <div className="flex flex-wrap items-center gap-2">
              <span className="inline-flex items-center gap-2 rounded-pill border border-white/15 bg-white/10 px-3 py-1.5 text-xs font-semibold text-brand-100">
                {gpuAccelerated ? <Sparkles aria-hidden="true" size={14} /> : <Cpu aria-hidden="true" size={14} />}
                {getComputeTypeLabel(server)}
              </span>
              <span className="inline-flex items-center gap-2 rounded-pill border border-emerald-300/20 bg-emerald-300/10 px-3 py-1.5 text-xs font-semibold text-emerald-200">
                <span className="size-1.5 rounded-full bg-current" />
                {t("reservation.activeConfiguration")}
              </span>
            </div>
            <h2 id="selected-hardware-title" dir="auto" className="bidi-auto mt-4 truncate text-2xl font-semibold tracking-[-0.04em] text-white sm:text-3xl" title={primaryHardware}>
              {primaryHardware}
            </h2>
            <p dir="auto" className="bidi-auto mt-2 truncate text-sm text-ink-300" title={supportingHardware}>{supportingHardware}</p>

            <div className="mt-4 flex flex-wrap gap-2">
              <span className="inline-flex items-center gap-2 rounded-pill border border-white/10 bg-white/[0.055] px-3 py-1.5 text-xs text-ink-300">
                <MemoryStick aria-hidden="true" size={14} className="text-brand-200" />
                <bdi dir="auto" className="bidi-auto">{server.ram}</bdi>
              </span>
              <span className="inline-flex items-center gap-2 rounded-pill border border-white/10 bg-white/[0.055] px-3 py-1.5 text-xs text-ink-300">
                <HardDrive aria-hidden="true" size={14} className="text-brand-200" />
                <bdi dir="auto" className="bidi-auto">{server.storage}</bdi>
              </span>
              <span className="inline-flex items-center gap-2 rounded-pill border border-white/10 bg-white/[0.055] px-3 py-1.5 text-xs text-ink-300">
                <MonitorCog aria-hidden="true" size={14} className="text-brand-200" />
                <bdi dir="auto" className="bidi-auto">{server.os}</bdi>
              </span>
            </div>
          </div>

          <div className="grid grid-cols-2 gap-3 lg:min-w-72">
            <div className="rounded-control border border-white/10 bg-white/[0.06] p-3.5">
              <p className="text-xs text-ink-400">{t("reservation.hourly")}</p>
              <p dir="auto" className="bidi-auto mt-1 text-lg font-semibold text-white">{formatCurrency(server.pricePerHour)}</p>
            </div>
            <div className="rounded-control border border-white/10 bg-white/[0.06] p-3.5">
              <p className="text-xs text-ink-400">{t("reservation.daily")}</p>
              <p dir="auto" className="bidi-auto mt-1 text-lg font-semibold text-white">{formatCurrency(server.pricePerDay)}</p>
            </div>
          </div>
        </div>
      </section>

      <div className="grid gap-5 xl:grid-cols-[minmax(0,1fr)_23rem] xl:items-start">
        <div className="contents xl:block xl:space-y-5">
          <section className="overflow-hidden rounded-card border border-border-subtle bg-white shadow-card" aria-labelledby="booking-window-title">
            <div className="flex flex-col gap-4 border-b border-border-subtle bg-gradient-to-r from-white via-brand-50/45 to-white p-5 sm:flex-row sm:items-center sm:justify-between">
              <div className="flex items-start gap-3">
                <span className="icon-tile">
                  <Clock3 aria-hidden="true" size={19} />
                </span>
                <div>
                  <p className="section-kicker">{t("reservation.stepOne")}</p>
                  <h2 id="booking-window-title" className="mt-1 card-title">{t("reservation.selectWindow")}</h2>
                  <p className="mt-1 text-sm text-ink-500">{t("reservation.disabledStarts")}</p>
                </div>
              </div>

              <button
                className="btn-secondary shrink-0"
                type="button"
                onClick={() => void suggestReservation()}
                disabled={suggesting || submitting || Boolean(result)}
              >
                {suggesting ? (
                  <LoaderCircle aria-hidden="true" className="animate-spin" size={17} />
                ) : (
                  <Lightbulb aria-hidden="true" size={17} />
                )}
                {suggesting ? t("reservation.findingSlot") : t("reservation.findSlot")}
              </button>
            </div>

            <div className="p-5">
              <div className="grid grid-cols-2 rounded-control border border-border-subtle bg-surface-muted/70 p-1" role="tablist" aria-label={t("reservation.bookingMode")}>
                <button
                  className={[
                    "inline-flex min-h-11 items-center justify-center gap-2 rounded-xl px-4 text-sm font-semibold transition duration-base",
                    bookingMode === "hourly" ? "bg-white text-brand-800 shadow-control" : "text-ink-500 hover:text-ink-800",
                  ].join(" ")}
                  type="button"
                  role="tab"
                  aria-selected={bookingMode === "hourly"}
                  onClick={() => setBookingMode("hourly")}
                >
                  <Clock3 aria-hidden="true" size={17} />
                  {t("reservation.hourly")}
                </button>
                <button
                  className={[
                    "inline-flex min-h-11 items-center justify-center gap-2 rounded-xl px-4 text-sm font-semibold transition duration-base",
                    bookingMode === "daily" ? "bg-white text-brand-800 shadow-control" : "text-ink-500 hover:text-ink-800",
                  ].join(" ")}
                  type="button"
                  role="tab"
                  aria-selected={bookingMode === "daily"}
                  onClick={() => setBookingMode("daily")}
                >
                  <CalendarDays aria-hidden="true" size={17} />
                  {t("reservation.daily")}
                </button>
              </div>

              {bookingMode === "hourly" ? (
                <div className="mt-6" role="tabpanel">
                  <div className="grid gap-4 sm:grid-cols-2">
                    <div className="field">
                      <label htmlFor="hourly-duration">{t("reservation.durationHours")}</label>
                      <div dir="ltr" className="grid grid-cols-[2.75rem_minmax(0,1fr)_2.75rem] overflow-hidden rounded-control border border-border-strong bg-white focus-within:border-brand-500 focus-within:shadow-focus">
                        <button
                          type="button"
                          className="control-press inline-flex min-h-11 items-center justify-center border-r border-border-subtle text-ink-500 hover:bg-brand-50 hover:text-brand-700"
                          aria-label={t("reservation.decreaseDuration")}
                          onClick={() => setHourlyDurationHours((value) => String(Math.max(0.5, (Number(value) || 0.5) - 0.5)))}
                        >
                          <Minus aria-hidden="true" size={16} />
                        </button>
                        <input
                          id="hourly-duration"
                          className="min-w-0 border-0 bg-transparent px-3 text-center font-semibold text-ink-900 outline-none"
                          type="number"
                          min="0.5"
                          step="0.5"
                          value={hourlyDurationHours}
                          onChange={(event) => setHourlyDurationHours(event.target.value)}
                          aria-describedby="hourly-duration-hint"
                        />
                        <button
                          type="button"
                          className="control-press inline-flex min-h-11 items-center justify-center border-l border-border-subtle text-ink-500 hover:bg-brand-50 hover:text-brand-700"
                          aria-label={t("reservation.increaseDuration")}
                          onClick={() => setHourlyDurationHours((value) => String((Number(value) || 0) + 0.5))}
                        >
                          <Plus aria-hidden="true" size={16} />
                        </button>
                      </div>
                      <span id="hourly-duration-hint" className="field-hint">{t("reservation.hourlyHint")}</span>
                    </div>

                    <label className="field">
                      <span>{t("reservation.selectedStart")}</span>
                      <span className="relative block">
                        <input
                          className="peer absolute inset-0 z-10 h-full w-full cursor-pointer opacity-0"
                          type="datetime-local"
                          min={minimumHourlyStart}
                          value={hourlyStart}
                          onChange={(event) => setHourlyStart(event.target.value)}
                        />
                        <span aria-hidden="true" className="input pointer-events-none flex items-center justify-between gap-3 peer-focus:border-brand-500 peer-focus:shadow-focus">
                          <bdi dir="auto" className="bidi-auto font-semibold">{selectedHourlyStart}</bdi>
                          <CalendarDays className="shrink-0 text-brand-600" size={17} />
                        </span>
                      </span>
                      <span className="field-hint">{t("reservation.iranTimezone")} · <bdi dir="ltr">{IRAN_TIME_ZONE}</bdi></span>
                    </label>
                  </div>

                  <aside className="mt-4 flex flex-col gap-3 rounded-control border border-brand-200 bg-brand-50/60 p-3.5 sm:flex-row sm:items-center sm:justify-between" aria-label={t("reservation.iranNowDescription")}>
                    <div className="flex min-w-0 items-center gap-3">
                      <span className="icon-tile shrink-0 bg-white">
                        <Clock3 aria-hidden="true" size={17} />
                      </span>
                      <div className="min-w-0">
                        <p className="section-kicker">{t("reservation.iranNow")}</p>
                        <time dateTime={new Date(currentTime).toISOString()} className="mt-1 block text-sm font-semibold text-ink-900">
                          {currentIranDate}
                        </time>
                      </div>
                    </div>
                    <div className="flex items-center gap-2 sm:shrink-0">
                      <time dateTime={new Date(currentTime).toISOString()} className="text-lg font-semibold tabular-nums text-brand-900">
                        {currentIranTime}
                      </time>
                      <span className="badge-brand">{t("reservation.iranTimezone")} · <bdi dir="ltr">{IRAN_TIME_ZONE}</bdi></span>
                    </div>
                  </aside>

                  <div className="mt-4 flex flex-wrap items-center gap-2" aria-label={t("reservation.durationPresets")}>
                    {[1, 4, 8, 12, 24].map((hours) => (
                      <button
                        key={hours}
                        type="button"
                        className={`min-h-9 rounded-pill border px-3 text-xs font-semibold transition duration-fast ${
                          Number(hourlyDurationHours) === hours
                            ? "border-brand-400 bg-brand-50 text-brand-800"
                            : "border-border-subtle bg-white text-ink-600 hover:border-brand-200 hover:text-brand-800"
                        }`}
                        aria-pressed={Number(hourlyDurationHours) === hours}
                        onClick={() => setHourlyDurationHours(String(hours))}
                      >
                        {t("format.duration.hours", { count: hours, formattedCount: formatNumber(hours) })}
                      </button>
                    ))}
                  </div>

                  <div className="mt-7">
                    <div className="flex flex-col gap-3 sm:flex-row sm:items-end sm:justify-between">
                      <div>
                        <p className="text-sm font-semibold text-ink-900">{t("reservation.quickStarts")}</p>
                        <p className="mt-1 text-xs text-ink-500">{t("reservation.next72Hours")}</p>
                      </div>
                      <div className="flex items-center gap-4 text-xs text-ink-500">
                        <span className="inline-flex items-center gap-2"><span className="size-2 rounded-full bg-brand-500" />{t("reservation.selected")}</span>
                        <span className="inline-flex items-center gap-2"><span className="size-2 rounded-full bg-surface-inset" />{t("reservation.unavailable")}</span>
                      </div>
                    </div>

                    <div className="mt-4 grid max-h-80 gap-2 overflow-y-auto pe-1 sm:grid-cols-2 lg:grid-cols-3">
                      {hourlyCandidates.map((candidate) => {
                        const selected = hourlyStart === candidate.timeValue;
                        return (
                          <button
                            key={candidate.key}
                            type="button"
                            disabled={candidate.isDisabled}
                            onClick={() => setHourlyStart(candidate.timeValue)}
                            aria-pressed={selected}
                            title={candidate.isDisabled ? t("reservation.unavailableForDuration") : undefined}
                            className={[
                              "flex min-h-14 items-center justify-between gap-3 rounded-control border px-3.5 py-2.5 text-start text-xs font-semibold transition duration-fast",
                              candidate.isDisabled
                                ? "border-border-subtle bg-surface-muted text-ink-400"
                                : selected
                                  ? "border-brand-500 bg-brand-50 text-brand-800 shadow-focus"
                                  : "border-border-subtle bg-white text-ink-700 hover:border-brand-300 hover:bg-brand-50/60",
                            ].join(" ")}
                          >
                            <span>{candidate.label}</span>
                            {selected && <Check aria-hidden="true" className="text-brand-700" size={15} />}
                          </button>
                        );
                      })}
                    </div>
                  </div>
                </div>
              ) : (
                <div className="mt-6" role="tabpanel">
                  <div className="grid gap-4 sm:grid-cols-2">
                    <div className="field">
                      <label htmlFor="daily-duration">{t("reservation.durationDays")}</label>
                      <div dir="ltr" className="grid grid-cols-[2.75rem_minmax(0,1fr)_2.75rem] overflow-hidden rounded-control border border-border-strong bg-white focus-within:border-brand-500 focus-within:shadow-focus">
                        <button
                          type="button"
                          className="control-press inline-flex min-h-11 items-center justify-center border-r border-border-subtle text-ink-500 hover:bg-brand-50 hover:text-brand-700"
                          aria-label={t("reservation.decreaseDuration")}
                          onClick={() => setDailyDurationDays((value) => String(Math.max(1, Math.floor(Number(value) || 1) - 1)))}
                        >
                          <Minus aria-hidden="true" size={16} />
                        </button>
                        <input
                          id="daily-duration"
                          className="min-w-0 border-0 bg-transparent px-3 text-center font-semibold text-ink-900 outline-none"
                          type="number"
                          min="1"
                          step="1"
                          value={dailyDurationDays}
                          onChange={(event) => setDailyDurationDays(event.target.value)}
                        />
                        <button
                          type="button"
                          className="control-press inline-flex min-h-11 items-center justify-center border-l border-border-subtle text-ink-500 hover:bg-brand-50 hover:text-brand-700"
                          aria-label={t("reservation.increaseDuration")}
                          onClick={() => setDailyDurationDays((value) => String(Math.floor(Number(value) || 0) + 1))}
                        >
                          <Plus aria-hidden="true" size={16} />
                        </button>
                      </div>
                      <span className="field-hint">{t("reservation.dailyHint")}</span>
                    </div>

                    <label className="field">
                      <span>{t("reservation.selectedStartDate")}</span>
                      <span className="relative block">
                        <input
                          className="peer absolute inset-0 z-10 h-full w-full cursor-pointer opacity-0"
                          type="date"
                          min={minimumDailyStart}
                          value={dailyStartDate}
                          onChange={(event) => setDailyStartDate(event.target.value)}
                        />
                        <span aria-hidden="true" className="input pointer-events-none flex items-center justify-between gap-3 peer-focus:border-brand-500 peer-focus:shadow-focus">
                          <bdi dir="auto" className="bidi-auto font-semibold">{selectedDailyStart}</bdi>
                          <CalendarDays className="shrink-0 text-brand-600" size={17} />
                        </span>
                      </span>
                      <span className="field-hint">{t("reservation.iranTimezone")} · <bdi dir="ltr">{IRAN_TIME_ZONE}</bdi></span>
                    </label>
                  </div>

                  <aside className="mt-4 flex flex-col gap-3 rounded-control border border-brand-200 bg-brand-50/60 p-3.5 sm:flex-row sm:items-center sm:justify-between" aria-label={t("reservation.iranNowDescription")}>
                    <div className="flex min-w-0 items-center gap-3">
                      <span className="icon-tile shrink-0 bg-white">
                        <Clock3 aria-hidden="true" size={17} />
                      </span>
                      <div className="min-w-0">
                        <p className="section-kicker">{t("reservation.iranNow")}</p>
                        <time dateTime={new Date(currentTime).toISOString()} className="mt-1 block text-sm font-semibold text-ink-900">
                          {currentIranDate}
                        </time>
                      </div>
                    </div>
                    <div className="flex items-center gap-2 sm:shrink-0">
                      <time dateTime={new Date(currentTime).toISOString()} className="text-lg font-semibold tabular-nums text-brand-900">
                        {currentIranTime}
                      </time>
                      <span className="badge-brand">{t("reservation.iranTimezone")} · <bdi dir="ltr">{IRAN_TIME_ZONE}</bdi></span>
                    </div>
                  </aside>

                  <div className="mt-4 flex flex-wrap items-center gap-2" aria-label={t("reservation.durationPresets")}>
                    {[1, 2, 5].map((days) => (
                      <button
                        key={days}
                        type="button"
                        className={`min-h-9 rounded-pill border px-3 text-xs font-semibold transition duration-fast ${
                          Number(dailyDurationDays) === days
                            ? "border-brand-400 bg-brand-50 text-brand-800"
                            : "border-border-subtle bg-white text-ink-600 hover:border-brand-200 hover:text-brand-800"
                        }`}
                        aria-pressed={Number(dailyDurationDays) === days}
                        onClick={() => setDailyDurationDays(String(days))}
                      >
                        {t("format.duration.days", { count: days, formattedCount: formatNumber(days) })}
                      </button>
                    ))}
                  </div>

                  <div className="mt-7">
                    <div className="flex flex-col gap-3 sm:flex-row sm:items-end sm:justify-between">
                      <div>
                        <p className="text-sm font-semibold text-ink-900">{t("reservation.availableDates")}</p>
                        <p className="mt-1 text-xs text-ink-500">{t("reservation.next21Days")}</p>
                      </div>
                      <div className="flex items-center gap-4 text-xs text-ink-500">
                        <span className="inline-flex items-center gap-2"><span className="size-2 rounded-full bg-brand-500" />{t("reservation.selected")}</span>
                        <span className="inline-flex items-center gap-2"><span className="size-2 rounded-full bg-surface-inset" />{t("reservation.unavailable")}</span>
                      </div>
                    </div>

                    <div className="mt-4 grid gap-2 sm:grid-cols-2 lg:grid-cols-3">
                      {dailyCandidates.map((candidate) => {
                        const selected = dailyStartDate === candidate.value;
                        return (
                          <button
                            key={candidate.key}
                            type="button"
                            disabled={candidate.isDisabled}
                            onClick={() => setDailyStartDate(candidate.value)}
                            aria-pressed={selected}
                            title={candidate.isDisabled ? t("reservation.unavailableForDuration") : undefined}
                            className={[
                              "flex min-h-14 items-center justify-between gap-3 rounded-control border px-3.5 py-2.5 text-start text-sm font-semibold transition duration-fast",
                              candidate.isDisabled
                                ? "border-border-subtle bg-surface-muted text-ink-400"
                                : selected
                                  ? "border-brand-500 bg-brand-50 text-brand-800 shadow-focus"
                                  : "border-border-subtle bg-white text-ink-700 hover:border-brand-300 hover:bg-brand-50/60",
                            ].join(" ")}
                          >
                            <span>{candidate.label}</span>
                            {selected && <Check aria-hidden="true" className="text-brand-700" size={15} />}
                          </button>
                        );
                      })}
                    </div>
                  </div>
                </div>
              )}

              <AvailabilityTimeline
                busySlots={busySlots}
                selectedStart={reservationPreview.start}
                selectedEnd={reservationPreview.end}
                selectionConflicts={selectionConflicts || activeQuote?.isAvailable === false}
                loading={availabilityLoading}
              />
            </div>
          </section>

          {suggestion && (
            <section className="overflow-hidden rounded-card border border-brand-200 bg-brand-50/65 shadow-control" aria-live="polite">
              <div className="flex flex-col gap-4 p-5 sm:flex-row sm:items-center sm:justify-between">
                <div className="flex items-start gap-3">
                  <span className="icon-tile bg-white">
                    <Lightbulb aria-hidden="true" size={19} />
                  </span>
                  <div>
                    <p className="text-sm font-semibold text-brand-950">{t("reservation.suggestionTitle")}</p>
                    <p className="mt-1 text-sm leading-6 text-ink-600">
                      {suggestion.suggestedStart && suggestion.suggestedEnd
                        ? t("reservation.suggestionFound")
                        : t("reservation.suggestionFull")}
                    </p>
                    {suggestion.suggestedStart && suggestion.suggestedEnd && (
                      <div className="mt-3 flex flex-wrap items-center gap-2 text-xs font-semibold text-ink-700">
                        <span className="rounded-pill border border-brand-200 bg-white px-3 py-1.5">{formatReservationDateTime(suggestion.suggestedStart)}</span>
                        <ArrowRight aria-hidden="true" className="directional-icon text-brand-600" size={14} />
                        <span className="rounded-pill border border-brand-200 bg-white px-3 py-1.5">{formatReservationDateTime(suggestion.suggestedEnd)}</span>
                      </div>
                    )}
                  </div>
                </div>
                {suggestion.suggestedStart && suggestion.suggestedEnd && (
                  <button className="btn-primary shrink-0" type="button" onClick={applySuggestion}>
                    <CalendarCheck2 aria-hidden="true" size={17} />
                    {t("reservation.useSlot")}
                  </button>
                )}
              </div>
            </section>
          )}

          <section className="order-3 card xl:order-none" aria-labelledby="existing-reservations-title">
            <div className="flex flex-col gap-3 border-b border-border-subtle pb-5 sm:flex-row sm:items-start sm:justify-between">
              <div className="flex items-start gap-3">
                <span className="icon-tile-neutral">
                  <CalendarDays aria-hidden="true" size={19} />
                </span>
                <div>
                  <p className="section-kicker">{t("reservation.availabilityContext")}</p>
                  <h2 id="existing-reservations-title" className="mt-1 card-title">{t("reservation.upcomingWindows")}</h2>
                  <p className="mt-1 text-sm text-ink-500">{t("reservation.upcomingCopy")}</p>
                </div>
              </div>
              <div className="flex items-center gap-2">
                <span className="badge">{t("reservation.upcomingCount", { count: busySlots.length, formattedCount: formatNumber(busySlots.length) })}</span>
                <button
                  type="button"
                  className="control-press inline-flex size-9 items-center justify-center rounded-control text-ink-500 transition duration-fast hover:bg-brand-50 hover:text-brand-700"
                  aria-label={t("reservation.refreshAvailability")}
                  onClick={() => void refreshBusySlots()}
                  disabled={availabilityLoading}
                >
                  <RefreshCw aria-hidden="true" className={availabilityLoading ? "animate-spin" : ""} size={15} />
                </button>
              </div>
            </div>

            {busySlots.length === 0 ? (
              <div className="mt-5 flex items-center gap-3 rounded-control border border-status-success/20 bg-status-success/10 p-4">
                <CheckCircle2 aria-hidden="true" className="text-status-success" size={19} />
                <p className="text-sm font-medium text-emerald-800">{t("reservation.noUpcoming")}</p>
              </div>
            ) : (
              <div className="mt-5 grid max-h-96 gap-2 overflow-y-auto pe-1 sm:grid-cols-2">
                {busySlots.slice(0, 20).map((slot) => (
                  <div key={`${slot.source}-${slot.reservationId ?? slot.startTime}`} className="rounded-control border border-border-subtle bg-surface-muted/60 p-3.5">
                    <div className="flex items-center justify-between gap-3">
                      <p className="text-xs font-semibold text-ink-700">{slot.source === "Maintenance" ? t("reservation.maintenanceBlock") : t("reservation.reservationNumber", { id: formatNumber(slot.reservationId ?? 0, { useGrouping: false }) })}</p>
                      <span className="badge-warning px-2 py-0.5">{t("reservation.reserved")}</span>
                    </div>
                    <div className="mt-3 grid grid-cols-[1fr_auto_1fr] items-center gap-2 text-xs text-ink-500">
                      <span>{formatReservationDateTime(slot.startTime)}</span>
                      <ArrowRight aria-hidden="true" className="directional-icon" size={13} />
                      <span>{formatReservationDateTime(slot.endTime)}</span>
                    </div>
                  </div>
                ))}
              </div>
            )}
          </section>
        </div>

        <aside className="order-2 xl:order-none xl:sticky xl:top-28" aria-labelledby="reservation-summary-title">
          <div className="overflow-hidden rounded-card border border-border-subtle bg-white shadow-lift">
            <div className="border-b border-border-subtle bg-gradient-to-br from-brand-50 via-white to-white p-5">
              <div className="flex items-start justify-between gap-3">
                <div>
                  <p className="section-kicker">{t("reservation.stepTwo")}</p>
                  <h2 id="reservation-summary-title" className="mt-1 card-title">{t("reservation.reviewConfirm")}</h2>
                </div>
                {result ? (
                  <span className="badge-success"><CheckCircle2 aria-hidden="true" size={13} />{t("common.created")}</span>
                ) : quoteLoading ? (
                  <span className="badge-info"><LoaderCircle aria-hidden="true" className="animate-spin" size={13} />{t("reservation.checkingQuote")}</span>
                ) : activeQuote?.isAvailable ? (
                  <span className="badge-success"><span className="size-1.5 rounded-full bg-current" />{t("reservation.quoteConfirmed")}</span>
                ) : activeQuote?.isAvailable === false ? (
                  <span className="badge-warning"><AlertCircle aria-hidden="true" size={13} />{t("reservation.slotUnavailable")}</span>
                ) : (
                  <span className="badge-warning"><AlertCircle aria-hidden="true" size={13} />{t("reservation.checkSelection")}</span>
                )}
              </div>
            </div>

            <div className="p-5">
              <div className="flex items-start gap-3 rounded-control border border-border-subtle bg-surface-muted/60 p-3.5">
                <span className="icon-tile size-10">
                  {gpuAccelerated ? <CircuitBoard aria-hidden="true" size={18} /> : <Cpu aria-hidden="true" size={18} />}
                </span>
                <div className="min-w-0">
                  <p dir="auto" className="bidi-auto truncate text-sm font-semibold text-ink-950" title={primaryHardware}>{primaryHardware}</p>
                  <p dir="auto" className="bidi-auto mt-1 truncate text-xs text-ink-500" title={supportingHardware}>{supportingHardware}</p>
                </div>
              </div>

              <div className="mt-5">
                <div className="grid grid-cols-[1.5rem_1fr] gap-x-3">
                  <div className="flex flex-col items-center">
                    <span className="mt-1 size-2.5 rounded-full border-2 border-brand-600 bg-white" />
                    <span className="my-1 h-full min-h-10 w-px bg-border-strong" />
                    <span className="size-2.5 rounded-full bg-brand-600" />
                  </div>
                  <dl className="space-y-5">
                    <div>
                      <dt className="text-xs font-medium text-ink-500">{t("reservation.starts")}</dt>
                      <dd className="mt-1 text-sm font-semibold text-ink-900">
                        {reservationPreview.start ? formatReservationDateTime(reservationPreview.start) : t("reservation.notSelected")}
                      </dd>
                    </div>
                    <div>
                      <dt className="text-xs font-medium text-ink-500">{t("reservation.ends")}</dt>
                      <dd className="mt-1 text-sm font-semibold text-ink-900">
                        {reservationPreview.end ? formatReservationDateTime(reservationPreview.end) : t("reservation.notAvailableYet")}
                      </dd>
                    </div>
                  </dl>
                </div>
              </div>

              <dl className="mt-5 space-y-3 border-y border-border-subtle py-4 text-sm">
                <div className="flex items-center justify-between gap-4">
                  <dt className="flex items-center gap-2 text-ink-500"><TimerReset aria-hidden="true" size={15} />{t("reservation.duration")}</dt>
                  <dd className="font-semibold text-ink-900">{durationLabel}</dd>
                </div>
                <div className="flex items-center justify-between gap-4">
                  <dt className="flex items-center gap-2 text-ink-500"><ReceiptText aria-hidden="true" size={15} />{t("reservation.billing")}</dt>
                  <dd className="font-semibold text-ink-900">
                    {activeQuote
                      ? t(`reservation.pricingMode.${activeQuote.pricingMode}`)
                      : t(`reservation.${bookingMode}`)}
                  </dd>
                </div>
              </dl>

              <div className="mt-5 rounded-control bg-surface-inverse p-4 text-white">
                <div className="flex items-center justify-between gap-3">
                  <p className="text-xs font-medium text-ink-400">{t("reservation.estimatedTotal")}</p>
                  {quoteLoading && <LoaderCircle aria-hidden="true" className="animate-spin text-brand-200" size={15} />}
                </div>
                <p key={activeQuote?.totalPrice ?? "empty"} dir="auto" className="bidi-auto content-swap-enter mt-2 text-3xl font-semibold tracking-[-0.045em]" aria-live="polite">
                  {activeQuote === null ? "-" : formatCurrency(activeQuote.totalPrice)}
                </p>
                <p className="mt-2 text-xs leading-5 text-ink-400">
                  {activeQuote ? t("reservation.backendConfirmed") : t("reservation.backendConfirms")}
                </p>
              </div>

              {!result && reservationPreview.validationMessage && (
                <div className="alert-info mt-4 flex items-start gap-2.5" aria-live="polite">
                  <AlertCircle aria-hidden="true" className="mt-0.5" size={16} />
                  <p>{reservationPreview.validationMessage}</p>
                </div>
              )}

              {!result && activeQuote?.isAvailable === false && !reservationPreview.validationMessage && (
                <div className="alert-warning mt-4 flex items-start gap-2.5" role="status">
                  <AlertCircle aria-hidden="true" className="mt-0.5" size={16} />
                  <p>{t("reservation.conflictCopy")}</p>
                </div>
              )}

              {quoteError && (
                <div className="alert-error mt-4 flex items-start gap-2.5" role="alert">
                  <AlertCircle aria-hidden="true" className="mt-0.5" size={16} />
                  <div className="min-w-0 flex-1">
                    <p>{quoteError}</p>
                    <button type="button" className="mt-2 text-xs font-semibold underline underline-offset-4" onClick={() => setQuoteVersion((version) => version + 1)}>
                      {t("actions.retry")}
                    </button>
                  </div>
                </div>
              )}

              {error && (
                <div className="alert-error mt-4 flex items-start gap-2.5" role="alert">
                  <AlertCircle aria-hidden="true" className="mt-0.5" size={16} />
                  <p>{error}</p>
                </div>
              )}

              {result && (
                <div className="mt-4 rounded-control border border-status-success/20 bg-status-success/10 p-4" role="status">
                  <div className="flex items-start gap-3">
                    <CheckCircle2 aria-hidden="true" className="mt-0.5 text-status-success" size={19} />
                    <div>
                      <p className="text-sm font-semibold text-emerald-900">{t("reservation.created", { id: formatNumber(result.reservationId, { useGrouping: false }) })}</p>
                      <p className="mt-1 text-xs leading-5 text-emerald-800">{durationLabel}</p>
                      <p className="mt-1 text-xs font-semibold text-emerald-900">{t("reservation.total", { value: formatCurrency(result.totalPrice) })}</p>
                    </div>
                  </div>
                  <div className="mt-4 grid gap-2">
                    <button
                      className="btn-primary w-full"
                      onClick={() => navigate(`/checkout/${result.reservationId}`)}
                      type="button"
                    >
                      {t("reservation.checkout")}
                      <ArrowRight aria-hidden="true" className="directional-icon" size={16} />
                    </button>
                    <Link to="/my-reservations" className="btn-secondary w-full">
                      {t("reservation.viewReservations")}
                    </Link>
                  </div>
                </div>
              )}

              {!result && (
                <button
                  className="btn-primary mt-5 w-full"
                  type="button"
                  onClick={() => void submitReservation()}
                  disabled={!reservationPreview.isValid || !activeQuote?.isAvailable || quoteLoading || submitting || !server.isActive || server.operationalStatus !== "Available"}
                >
                  {submitting ? (
                    <LoaderCircle aria-hidden="true" className="animate-spin" size={17} />
                  ) : (
                    <ShieldCheck aria-hidden="true" size={17} />
                  )}
                  {submitting ? t("reservation.creating") : t("reservation.confirm")}
                </button>
              )}

              <p className="mt-3 text-center text-xs leading-5 text-ink-500">
                {t("reservation.confirmationPending")}
              </p>
            </div>
          </div>
        </aside>
      </div>
    </div>
  );
}
