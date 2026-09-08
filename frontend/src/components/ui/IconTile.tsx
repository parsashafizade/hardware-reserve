import type { LucideIcon } from "lucide-react";

type IconTileTone = "brand" | "neutral" | "success" | "inverse";

interface IconTileProps {
  icon: LucideIcon;
  tone?: IconTileTone;
  size?: number;
  className?: string;
}

const toneClasses: Record<IconTileTone, string> = {
  brand: "icon-tile",
  neutral: "icon-tile-neutral",
  success: "icon-tile-success",
  inverse: "icon-tile-inverse",
};

export function IconTile({ icon: Icon, tone = "brand", size = 20, className = "" }: IconTileProps) {
  return (
    <span aria-hidden="true" className={`${toneClasses[tone]} ${className}`.trim()}>
      <Icon size={size} strokeWidth={2} />
    </span>
  );
}
