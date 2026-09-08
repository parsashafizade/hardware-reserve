import type { LucideIcon } from "lucide-react";
import type { ReactNode } from "react";
import { IconTile } from "./IconTile";

interface PageHeaderProps {
  title: ReactNode;
  description?: ReactNode;
  eyebrow?: string;
  icon?: LucideIcon;
  actions?: ReactNode;
  className?: string;
}

export function PageHeader({
  title,
  description,
  eyebrow,
  icon,
  actions,
  className = "",
}: PageHeaderProps) {
  return (
    <header className={`page-header ${className}`.trim()}>
      <div className="page-header-copy">
        <div className="flex items-center gap-3">
          {icon && <IconTile icon={icon} />}
          <div>
            {eyebrow && <p className="section-kicker">{eyebrow}</p>}
            <h1 className={eyebrow ? "mt-1 page-title" : "page-title"}>{title}</h1>
          </div>
        </div>
        {description && <div className="page-description">{description}</div>}
      </div>
      {actions && (
        <div className="flex w-full max-w-full flex-wrap items-center gap-3 sm:w-auto sm:shrink-0">
          {actions}
        </div>
      )}
    </header>
  );
}
