import { Boxes, Headphones, LayoutDashboard, Megaphone, ReceiptText, Users } from "lucide-react";
import { useTranslation } from "react-i18next";
import { NavLink } from "react-router-dom";

export function AdminNavigation() {
  const { t } = useTranslation();
  const items = [
    { to: "/admin", label: t("admin.nav.overview"), icon: LayoutDashboard, end: true },
    { to: "/admin/servers", label: t("admin.nav.servers"), icon: Boxes, end: false },
    { to: "/admin/orders", label: t("admin.nav.orders"), icon: ReceiptText, end: false },
    { to: "/admin/users", label: t("admin.nav.users"), icon: Users, end: false },
    { to: "/admin/notifications", label: t("admin.nav.notifications"), icon: Megaphone, end: false },
    { to: "/admin/support", label: t("admin.nav.support"), icon: Headphones, end: false },
  ];

  return (
    <nav aria-label={t("admin.nav.aria")} className="overflow-x-auto rounded-card border border-border-subtle/90 bg-white/80 p-2 shadow-control backdrop-blur-xl">
      <div className="flex min-w-max gap-1 lg:grid lg:min-w-0 lg:grid-cols-6">
        {items.map(({ to, label, icon: Icon, end }) => (
          <NavLink
            key={to}
            to={to}
            end={end}
            className={({ isActive }) => [
              "inline-flex min-h-11 min-w-28 items-center justify-center gap-2 rounded-xl px-3 text-sm font-semibold transition duration-base",
              isActive ? "bg-brand-600 text-white shadow-control" : "text-ink-500 hover:bg-brand-50 hover:text-brand-800",
            ].join(" ")}
          >
            <Icon aria-hidden="true" size={16} />
            {label}
          </NavLink>
        ))}
      </div>
    </nav>
  );
}
