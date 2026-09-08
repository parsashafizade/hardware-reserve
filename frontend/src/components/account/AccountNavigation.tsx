import { Bell, CalendarDays, KeyRound, UserRound, type LucideIcon } from "lucide-react";
import { useTranslation } from "react-i18next";
import { NavLink } from "react-router-dom";

interface AccountNavigationItem {
  to: string;
  label: string;
  icon: LucideIcon;
}

export function AccountNavigation() {
  const { t } = useTranslation();
  const items: AccountNavigationItem[] = [
    { to: "/my-reservations", label: t("accountNav.reservations"), icon: CalendarDays },
    { to: "/my-services", label: t("accountNav.services"), icon: KeyRound },
    { to: "/profile", label: t("accountNav.profile"), icon: UserRound },
    { to: "/activity", label: t("accountNav.activity"), icon: Bell },
  ];

  return (
    <nav
      aria-label={t("accountNav.aria")}
      className="flex flex-col gap-3 rounded-card border border-border-subtle/90 bg-white/80 p-2 shadow-control backdrop-blur-xl lg:flex-row lg:items-center lg:justify-between"
    >
      <div className="hidden px-3 lg:block">
        <p className="text-xs font-bold uppercase tracking-[0.16em] text-brand-700">{t("accountNav.eyebrow")}</p>
        <p className="mt-0.5 text-xs text-ink-500">{t("accountNav.description")}</p>
      </div>

      <div className="grid w-full grid-cols-4 gap-1 rounded-control bg-surface-muted/80 p-1 lg:w-auto lg:min-w-[31rem]">
        {items.map(({ to, label, icon: Icon }) => (
          <NavLink
            key={to}
            to={to}
            className={({ isActive }) =>
              [
                "inline-flex min-h-10 min-w-0 items-center justify-center gap-1.5 rounded-xl px-1.5 text-[11px] font-semibold transition duration-base min-[360px]:gap-2 min-[360px]:px-2 sm:text-sm",
                isActive
                  ? "bg-white text-brand-800 shadow-control"
                  : "text-ink-500 hover:bg-white/70 hover:text-ink-800",
              ].join(" ")
            }
          >
            <Icon aria-hidden="true" className="max-[359px]:hidden" size={16} strokeWidth={2} />
            <span className="truncate">{label}</span>
          </NavLink>
        ))}
      </div>
    </nav>
  );
}
