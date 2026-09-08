import { CircuitBoard, Cpu, HardDrive, MemoryStick, MonitorCog, type LucideIcon } from "lucide-react";
import { useTranslation } from "react-i18next";
import type { Server } from "../../types/api";
import { hasDedicatedGpu } from "../../utils/serverPresentation";

type ServerSpecification = Pick<Server, "cpu" | "gpu" | "ram" | "storage" | "os">;

interface ServerSpecGridProps {
  server: ServerSpecification;
  compact?: boolean;
  inverse?: boolean;
  className?: string;
}

interface SpecificationItem {
  icon: LucideIcon;
  label: string;
  value: string;
}

export function ServerSpecGrid({
  server,
  compact = false,
  inverse = false,
  className = "",
}: ServerSpecGridProps) {
  const { t } = useTranslation();
  const specifications: SpecificationItem[] = [
    { icon: Cpu, label: t("server.specs.processor"), value: server.cpu },
    {
      icon: CircuitBoard,
      label: t("server.specs.graphics"),
      value: hasDedicatedGpu(server) ? server.gpu : t("server.specs.noDedicatedGpu"),
    },
    { icon: MemoryStick, label: t("server.specs.memory"), value: server.ram },
    { icon: HardDrive, label: t("server.specs.storage"), value: server.storage },
    { icon: MonitorCog, label: t("server.specs.operatingSystem"), value: server.os },
  ];

  return (
    <dl className={`grid gap-3 sm:grid-cols-2 ${className}`.trim()}>
      {specifications.map(({ icon: Icon, label, value }) => (
        <div
          key={label}
          className={[
            "flex min-w-0 items-start gap-3 rounded-control border",
            compact ? "p-3" : "p-4",
            inverse
              ? "border-white/10 bg-white/[0.055]"
              : "border-border-subtle/80 bg-surface-muted/55",
          ].join(" ")}
        >
          <span
            className={[
              "inline-flex size-9 shrink-0 items-center justify-center rounded-xl",
              inverse ? "bg-white/10 text-brand-200" : "bg-white text-brand-700 shadow-control",
            ].join(" ")}
          >
            <Icon aria-hidden="true" size={17} strokeWidth={2} />
          </span>
          <div className="min-w-0">
            <dt className={inverse ? "text-xs font-medium text-ink-400" : "meta-text"}>{label}</dt>
            <dd
              dir="auto"
              className={[
                "bidi-auto mt-1 break-words text-sm font-semibold leading-5",
                inverse ? "text-white" : "text-ink-900",
              ].join(" ")}
            >
              {value}
            </dd>
          </div>
        </div>
      ))}
    </dl>
  );
}
