import {
  ArrowRight,
  CalendarPlus,
  CircuitBoard,
  Cpu,
  HardDrive,
  MemoryStick,
  MonitorCog,
  Sparkles,
  type LucideIcon,
} from "lucide-react";
import { useTranslation } from "react-i18next";
import type { Server } from "../types/api";
import { formatCurrency } from "../utils/format";
import { getComputeTypeLabel, hasDedicatedGpu } from "../utils/serverPresentation";

interface ServerCardProps {
  server: Server;
  onView: () => void;
  onReserve: () => void;
}

interface SpecItemProps {
  icon: LucideIcon;
  label: string;
  value: string;
  className?: string;
}

function SpecItem({ icon: Icon, label, value, className = "" }: SpecItemProps) {
  return (
    <div className={`flex min-w-0 items-start gap-2.5 ${className}`.trim()}>
      <Icon aria-hidden="true" className="mt-0.5 text-brand-600" size={16} strokeWidth={2} />
      <div className="min-w-0">
        <p className="meta-text">{label}</p>
        <p dir="auto" className="bidi-auto mt-0.5 truncate text-sm font-semibold text-ink-800" title={value}>
          {value}
        </p>
      </div>
    </div>
  );
}

export function ServerCard({ server, onView, onReserve }: ServerCardProps) {
  const { t } = useTranslation();
  const gpuAccelerated = hasDedicatedGpu(server);
  const primaryHardware = gpuAccelerated ? server.gpu : server.cpu;
  const supportingHardware = gpuAccelerated ? server.cpu : t("server.labels.dedicatedProcessor");
  const reservable = server.isActive && server.operationalStatus === "Available";
  const availabilityLabel = server.operationalStatus === "Maintenance"
    ? t("serverCard.maintenance")
    : server.operationalStatus === "TemporarilyUnavailable"
      ? t("serverCard.temporarilyUnavailable")
      : reservable ? t("serverCard.available") : t("serverCard.unavailable");

  return (
    <article className="group flex h-full transform-gpu flex-col overflow-hidden rounded-card border border-border-subtle/90 bg-surface-base shadow-card transition duration-base ease-standard hover:-translate-y-0.5 hover:border-brand-200 hover:shadow-lift focus-within:border-brand-300 focus-within:shadow-lift">
      <button
        type="button"
        onClick={onView}
        aria-label={t("serverCard.openConfiguration", { name: primaryHardware })}
        className={[
          "relative min-h-44 w-full overflow-hidden border-b p-5 text-start focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-inset focus-visible:ring-brand-300",
          gpuAccelerated
            ? "border-white/10 bg-gradient-to-br from-brand-950 via-brand-900 to-brand-700"
            : "border-brand-100 bg-gradient-to-br from-white via-brand-50/75 to-surface-muted",
        ].join(" ")}
      >
        <div
          aria-hidden="true"
          className={[
            "absolute -right-10 -top-12 size-44 rounded-full blur-3xl transition duration-slow group-focus-within:scale-105",
            gpuAccelerated ? "bg-brand-300/25" : "bg-brand-300/30",
          ].join(" ")}
        />
        <div
          aria-hidden="true"
          className={[
            "absolute -bottom-12 left-8 size-32 rounded-full blur-3xl",
            gpuAccelerated ? "bg-cyan-300/10" : "bg-white/80",
          ].join(" ")}
        />

        <div className="relative flex items-center justify-between gap-3">
          <span
            className={[
              "inline-flex items-center gap-2 rounded-pill border px-3 py-1.5 text-xs font-semibold",
              gpuAccelerated
                ? "border-white/15 bg-white/10 text-brand-100 backdrop-blur-md"
                : "border-brand-200 bg-white/80 text-brand-800 shadow-control",
            ].join(" ")}
          >
            {gpuAccelerated ? <Sparkles aria-hidden="true" size={14} /> : <Cpu aria-hidden="true" size={14} />}
            {getComputeTypeLabel(server)}
          </span>
          <span className={`inline-flex items-center gap-1.5 text-[11px] font-semibold ${reservable ? gpuAccelerated ? "text-emerald-200" : "text-emerald-700" : gpuAccelerated ? "text-amber-200" : "text-amber-700"}`}>
            <span className="size-1.5 rounded-full bg-current" />
            {availabilityLabel}
          </span>
        </div>

        <div className="relative mt-6 grid grid-cols-[1fr_auto] items-end gap-4">
          <div className="min-w-0">
            <p
              className={[
                "text-[0.68rem] font-bold uppercase tracking-[0.16em]",
                gpuAccelerated ? "text-brand-300" : "text-brand-700",
              ].join(" ")}
            >
              {t("server.labels.configuration")}
            </p>
            <h2
              dir="auto"
              className={[
                "bidi-auto mt-2 line-clamp-2 text-xl font-semibold leading-7 tracking-[-0.035em]",
                gpuAccelerated ? "text-white" : "text-ink-950",
              ].join(" ")}
              title={primaryHardware}
            >
              {primaryHardware}
            </h2>
            <p
              dir="auto"
              className={[
                "bidi-auto mt-2 truncate text-sm",
                gpuAccelerated ? "text-ink-300" : "text-ink-600",
              ].join(" ")}
              title={supportingHardware}
            >
              {supportingHardware}
            </p>
          </div>

          <span
            aria-hidden="true"
            className={[
              "inline-flex size-12 items-center justify-center rounded-2xl border transition duration-base group-focus-within:-translate-y-0.5",
              gpuAccelerated
                ? "border-white/15 bg-white/10 text-brand-200 shadow-dark backdrop-blur-md"
                : "border-brand-200 bg-white text-brand-700 shadow-lift",
            ].join(" ")}
          >
            {gpuAccelerated ? <CircuitBoard size={22} strokeWidth={1.8} /> : <Cpu size={22} strokeWidth={1.8} />}
          </span>
        </div>
      </button>

      <div className="grid grid-cols-2 gap-x-4 gap-y-4 p-5">
        <SpecItem icon={MemoryStick} label={t("server.specs.memory")} value={server.ram} />
        <SpecItem icon={HardDrive} label={t("server.specs.storage")} value={server.storage} />
        <SpecItem icon={MonitorCog} label={t("server.specs.operatingSystem")} value={server.os} className="col-span-2" />
      </div>

      <div className="mx-5 mt-auto overflow-hidden rounded-control border border-border-subtle bg-surface-muted/65">
        <div className="grid grid-cols-[1fr_auto] items-end gap-4 p-4">
          <div>
            <p className="meta-text">{t("server.labels.hourlyAccess")}</p>
            <p dir="auto" className="bidi-auto mt-1 inline-flex items-baseline gap-1 font-semibold text-ink-950">
              <span className="text-2xl tracking-[-0.04em]">{formatCurrency(server.pricePerHour)}</span>
              <span className="text-xs font-medium text-ink-500">{t("server.labels.perHour")}</span>
            </p>
          </div>
          <div className="text-end">
            <p className="meta-text">{t("server.labels.dailyRate")}</p>
            <p dir="auto" className="bidi-auto mt-1 text-sm font-semibold text-ink-800">{formatCurrency(server.pricePerDay)}</p>
          </div>
        </div>
      </div>

      <div className="grid grid-cols-2 gap-2 p-5 pt-4">
        <button onClick={onView} type="button" className="btn-secondary w-full">
          {t("serverCard.viewSpecs")}
          <ArrowRight aria-hidden="true" className="directional-icon" size={16} />
        </button>
        <button onClick={onReserve} type="button" className="btn-primary w-full" disabled={!reservable}>
          <CalendarPlus aria-hidden="true" size={17} />
          {t("actions.reserve")}
        </button>
      </div>
    </article>
  );
}
