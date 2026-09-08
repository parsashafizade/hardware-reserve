import { useMemo } from "react";
import { useTranslation } from "react-i18next";
import { useLocale } from "../../i18n/useLocale";
import type { BusyReservationSlot } from "../../types/api";

interface AvailabilityTimelineProps {
  busySlots: BusyReservationSlot[];
  selectedStart: Date | null;
  selectedEnd: Date | null;
  selectionConflicts: boolean;
  loading?: boolean;
}

interface TimelineSegment {
  key: string;
  left: number;
  width: number;
}

function clampPercentage(value: number): number {
  return Math.min(100, Math.max(0, value));
}

function buildSegment(
  key: string,
  start: Date,
  end: Date,
  dayStart: Date,
  dayEnd: Date,
): TimelineSegment | null {
  const clippedStart = Math.max(start.getTime(), dayStart.getTime());
  const clippedEnd = Math.min(end.getTime(), dayEnd.getTime());

  if (clippedEnd <= clippedStart) {
    return null;
  }

  const dayDuration = dayEnd.getTime() - dayStart.getTime();
  const left = clampPercentage(((clippedStart - dayStart.getTime()) / dayDuration) * 100);
  const width = clampPercentage(((clippedEnd - clippedStart) / dayDuration) * 100);
  return { key, left, width: Math.max(width, 0.75) };
}

export function AvailabilityTimeline({
  busySlots,
  selectedStart,
  selectedEnd,
  selectionConflicts,
  loading = false,
}: AvailabilityTimelineProps) {
  const { t } = useTranslation();
  const { formatDate } = useLocale();

  const timeline = useMemo(() => {
    if (!selectedStart) {
      return null;
    }

    const dayStart = new Date(selectedStart);
    dayStart.setHours(0, 0, 0, 0);
    const dayEnd = new Date(dayStart);
    dayEnd.setDate(dayEnd.getDate() + 1);

    const busySegments = busySlots
      .map((slot) => buildSegment(
        `busy-${slot.source}-${slot.reservationId ?? slot.startTime}`,
        new Date(slot.startTime),
        new Date(slot.endTime),
        dayStart,
        dayEnd,
      ))
      .filter((segment): segment is TimelineSegment => segment !== null);

    const selection = selectedEnd
      ? buildSegment("selection", selectedStart, selectedEnd, dayStart, dayEnd)
      : null;

    const tickDates = [0, 6, 12, 18, 24].map((hour) => {
      const date = new Date(dayStart);
      date.setHours(hour, 0, 0, 0);
      return date;
    });

    return { dayStart, busySegments, selection, tickDates };
  }, [busySlots, selectedEnd, selectedStart]);

  if (!timeline) {
    return (
      <div className="surface-inset mt-5 p-4 text-sm text-ink-500">
        {t("reservation.timelineSelectStart")}
      </div>
    );
  }

  return (
    <div className="mt-5" aria-label={t("reservation.timelineAria")}>
      <div className="flex flex-col gap-2 sm:flex-row sm:items-end sm:justify-between">
        <div>
          <p className="text-sm font-semibold text-ink-900">{t("reservation.timelineTitle")}</p>
          <p className="mt-1 text-xs text-ink-500">
            {formatDate(timeline.dayStart, { weekday: "long", month: "short", day: "numeric" })}
          </p>
        </div>
        <div className="flex flex-wrap items-center gap-3 text-xs text-ink-500">
          <span className="inline-flex items-center gap-1.5"><span className="size-2 rounded-full bg-emerald-400" />{t("reservation.available")}</span>
          <span className="inline-flex items-center gap-1.5"><span className="size-2 rounded-full bg-amber-400" />{t("reservation.unavailable")}</span>
          <span className="inline-flex items-center gap-1.5"><span className="size-2 rounded-full bg-brand-600" />{t("reservation.selected")}</span>
        </div>
      </div>

      <div
        dir="ltr"
        className="relative mt-4 h-12 overflow-hidden rounded-control border border-border-subtle bg-emerald-50"
        role="img"
        aria-label={selectionConflicts ? t("reservation.timelineConflictAria") : t("reservation.timelineAvailableAria")}
        aria-busy={loading}
      >
        <div aria-hidden="true" className="absolute inset-0 grid grid-cols-4 divide-x divide-white/80">
          <span /><span /><span /><span />
        </div>
        {timeline.busySegments.map((segment) => (
          <span
            aria-hidden="true"
            key={segment.key}
            className="absolute inset-y-0 bg-amber-300/75"
            style={{ left: `${segment.left}%`, width: `${segment.width}%` }}
          />
        ))}
        {timeline.selection && (
          <span
            aria-hidden="true"
            className={`absolute inset-y-1 rounded-md border-2 shadow-control ${
              selectionConflicts
                ? "border-rose-600 bg-rose-400/65"
                : "border-brand-700 bg-brand-500/65"
            }`}
            style={{ left: `${timeline.selection.left}%`, width: `${timeline.selection.width}%` }}
          />
        )}
        {loading && <span aria-hidden="true" className="skeleton absolute inset-0 rounded-none opacity-40" />}
      </div>

      <div dir="ltr" className="mt-1.5 flex justify-between font-sans text-[0.68rem] tabular-nums text-ink-400">
        {timeline.tickDates.map((date, index) => (
          <span key={`${date.toISOString()}-${index}`}>
            {index === timeline.tickDates.length - 1
              ? "24:00"
              : new Intl.DateTimeFormat("en-GB", { hour: "2-digit", minute: "2-digit", hour12: false }).format(date)}
          </span>
        ))}
      </div>
    </div>
  );
}
