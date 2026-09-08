import type { LucideIcon } from "lucide-react";

interface AccountMetricCardProps {
  icon: LucideIcon;
  label: string;
  value: string;
  detail: string;
  tone?: "brand" | "success" | "neutral";
}

export function AccountMetricCard({
  icon: Icon,
  label,
  value,
  detail,
  tone = "neutral",
}: AccountMetricCardProps) {
  const toneClasses = {
    brand: "border-brand-200 bg-gradient-to-br from-brand-50 via-white to-white",
    success: "border-status-success/20 bg-gradient-to-br from-emerald-50/80 via-white to-white",
    neutral: "border-border-subtle bg-white",
  };

  return (
    <div className={`rounded-card border p-4 shadow-control sm:p-5 ${toneClasses[tone]}`}>
      <div className="flex items-start justify-between gap-4">
        <div>
          <p className="text-xs font-medium text-ink-500">{label}</p>
          <p className="mt-2 text-2xl font-semibold tracking-[-0.04em] text-ink-950">{value}</p>
          <p className="mt-1 font-reading text-xs leading-5 text-ink-500">{detail}</p>
        </div>
        <span className={tone === "success" ? "icon-tile-success size-10" : "icon-tile size-10"}>
          <Icon aria-hidden="true" size={18} />
        </span>
      </div>
    </div>
  );
}
