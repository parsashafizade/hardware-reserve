import type { ReactNode } from "react";

type StatusBadgeTone = "neutral" | "brand" | "success" | "warning" | "danger" | "info";

interface StatusBadgeProps {
  children: ReactNode;
  tone?: StatusBadgeTone;
  showDot?: boolean;
  className?: string;
}

const toneClasses: Record<StatusBadgeTone, string> = {
  neutral: "badge",
  brand: "badge-brand",
  success: "badge-success",
  warning: "badge-warning",
  danger: "badge-danger",
  info: "badge-info",
};

export function StatusBadge({
  children,
  tone = "neutral",
  showDot = false,
  className = "",
}: StatusBadgeProps) {
  return (
    <span className={`${toneClasses[tone]} ${className}`.trim()}>
      {showDot && <span aria-hidden="true" className="size-1.5 rounded-full bg-current" />}
      {children}
    </span>
  );
}
