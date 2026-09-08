import { Suspense, useEffect, useRef, useState } from "react";
import {
  ArrowRight,
  CalendarDays,
  Home,
  KeyRound,
  LayoutDashboard,
  LoaderCircle,
  LogOut,
  Menu,
  Server as ServerIcon,
  UserRound,
  X,
  type LucideIcon,
} from "lucide-react";
import { Link, NavLink, Outlet, useLocation, useNavigate } from "react-router-dom";
import { useTranslation } from "react-i18next";
import { useAuth } from "../auth/useAuth";
import { useLocale } from "../i18n/useLocale";
import { BrandMark } from "./BrandMark";
import { LanguageSwitcher } from "./LanguageSwitcher";
import { SupportWidget } from "./support/SupportWidget";
import { NotificationBell } from "./notifications/NotificationBell";
import { CommandPalette, CommandPaletteTrigger } from "./command/CommandPalette";
import { useCurrentTime } from "../hooks/useCurrentTime";

interface NavigationItem {
  to: string;
  label: string;
  visible: boolean;
  icon: LucideIcon;
}

function NavItem({
  to,
  label,
  icon: Icon,
  onNavigate,
}: {
  to: string;
  label: string;
  icon: LucideIcon;
  onNavigate?: () => void;
}) {
  return (
    <NavLink
      to={to}
      end={to === "/"}
      onClick={onNavigate}
      className={({ isActive }) => `nav-link ${isActive ? "nav-link-active" : ""}`}
    >
      <Icon aria-hidden="true" size={17} strokeWidth={2} />
      {label}
    </NavLink>
  );
}

function FooterLink({ to, children }: { to: string; children: string }) {
  return (
    <Link to={to} className="footer-link">
      {children}
    </Link>
  );
}

export function AppLayout() {
  const { t, i18n } = useTranslation();
  const { formatDate } = useLocale();
  const { isAuthenticated, isAdmin, logout } = useAuth();
  const navigate = useNavigate();
  const location = useLocation();
  const [mobileMenuOpen, setMobileMenuOpen] = useState(false);
  const mainRef = useRef<HTMLElement>(null);
  const previousPath = useRef(location.pathname);
  const isHomePage = location.pathname === "/" || location.pathname === "/home";
  const currentTime = useCurrentTime(60_000);

  useEffect(() => {
    const path = location.pathname;
    const knownTitles: Record<string, string> = {
      "/": "HardwareReserve",
      "/home": "HardwareReserve",
      "/servers": t("document.servers"),
      "/login": t("document.login"),
      "/register": t("document.register"),
      "/verify-email": t("document.verifyEmail"),
      "/forgot-password": t("document.forgotPassword"),
      "/reset-password": t("document.resetPassword"),
      "/profile": t("document.profile"),
      "/my-reservations": t("document.reservations"),
      "/my-services": t("document.services"),
      "/activity": t("notifications.title"),
      "/admin": t("document.admin"),
    };
    const pageName = knownTitles[path]
      ?? (path.startsWith("/admin/support")
        ? t("document.supportInbox")
        : path.startsWith("/my-reservations/")
          ? t("cockpit.eyebrow")
          : path.startsWith("/server/")
            ? t("document.serverDetails")
            : path.startsWith("/reserve/")
              ? t("document.reserveHardware")
              : path.startsWith("/checkout/")
                ? t("document.checkout")
                : path.startsWith("/admin/")
                  ? t("document.admin")
                  : t("document.notFound"));

    document.title = pageName === "HardwareReserve" ? pageName : `${pageName} | HardwareReserve`;

    if (previousPath.current !== path) {
      window.scrollTo({ top: 0, left: 0, behavior: "auto" });
      mainRef.current?.focus({ preventScroll: true });
      previousPath.current = path;
    }
  }, [i18n.resolvedLanguage, location.pathname, t]);

  const navigationItems: NavigationItem[] = [
    { to: "/", label: t("navigation.home"), visible: !isAdmin, icon: Home },
    { to: "/servers", label: t("navigation.servers"), visible: true, icon: ServerIcon },
    { to: "/my-reservations", label: t("navigation.reservations"), visible: isAuthenticated && !isAdmin, icon: CalendarDays },
    { to: "/my-services", label: t("navigation.services"), visible: isAuthenticated && !isAdmin, icon: KeyRound },
    { to: "/admin", label: t("navigation.admin"), visible: isAdmin, icon: LayoutDashboard },
  ];

  const handleLogout = async () => {
    setMobileMenuOpen(false);
    await logout();
    navigate("/");
  };

  return (
    <div className="app-shell text-ink-900">
      <a href="#main-content" className="skip-link">{t("accessibility.skipToMain")}</a>
      <header className="sticky top-0 z-50 border-b border-border-subtle/80 bg-white/[0.9] backdrop-blur-xl">
        <div className="container-shell flex min-h-[4.25rem] items-center justify-between gap-5">
          <Link to="/" aria-label={t("accessibility.homeLabel")} className="shrink-0 rounded-control">
            <BrandMark />
          </Link>

          <nav aria-label={t("accessibility.primaryNavigation")} className="nav-shell hidden xl:flex">
            {navigationItems
              .filter((item) => item.visible)
              .map((item) => (
                <NavItem key={item.to} to={item.to} label={item.label} icon={item.icon} />
              ))}
          </nav>

          <div className="hidden shrink-0 items-center gap-2 xl:flex">
            {isAuthenticated && <CommandPaletteTrigger />}
            {isAuthenticated && <NotificationBell />}
            <LanguageSwitcher />
            {!isAuthenticated ? (
              <>
                <Link to="/login" className="btn-secondary">
                  {t("actions.login")}
                </Link>
                <Link to="/register" className="btn-primary">
                  {t("actions.createAccount")}
                  <ArrowRight aria-hidden="true" className="directional-icon" size={16} />
                </Link>
              </>
            ) : (
              <>
                <Link to="/profile" className="btn-secondary">
                  <UserRound aria-hidden="true" size={17} />
                  {t("navigation.profile")}
                </Link>
                <button
                  onClick={handleLogout}
                  className="btn-ghost text-ink-500 hover:bg-red-50 hover:text-status-danger"
                  type="button"
                >
                  <LogOut aria-hidden="true" className="directional-icon" size={17} />
                  {t("actions.logout")}
                </button>
              </>
            )}
          </div>

          <div className="flex items-center gap-1.5 xl:hidden">
            {isAuthenticated && <CommandPaletteTrigger compact />}
            {isAuthenticated && <NotificationBell />}
            <button
              type="button"
              className="btn-icon"
              aria-label={mobileMenuOpen ? t("accessibility.closeMenu") : t("accessibility.openMenu")}
              aria-expanded={mobileMenuOpen}
              aria-controls="mobile-navigation"
              onClick={() => setMobileMenuOpen((open) => !open)}
            >
              {mobileMenuOpen
                ? <X aria-hidden="true" className="motion-icon-enter" size={21} />
                : <Menu aria-hidden="true" className="motion-icon-enter" size={21} />}
            </button>
          </div>
        </div>

        {mobileMenuOpen && (
          <div id="mobile-navigation" className="container-shell pb-4 xl:hidden">
            <nav aria-label={t("accessibility.mobileNavigation")} className="mobile-nav-panel">
              {navigationItems
                .filter((item) => item.visible)
                .map((item) => (
                  <NavItem
                    key={item.to}
                    to={item.to}
                    label={item.label}
                    icon={item.icon}
                    onNavigate={() => setMobileMenuOpen(false)}
                  />
                ))}
              <div className="my-2 h-px bg-border-subtle" />
              <div className="flex min-h-12 items-center justify-between gap-4 px-2">
                <span className="text-sm font-semibold text-ink-600">{t("language.label")}</span>
                <LanguageSwitcher />
              </div>
              <div className="my-2 h-px bg-border-subtle" />
              {!isAuthenticated ? (
                <div className="grid grid-cols-2 gap-2">
                  <Link to="/login" className="btn-secondary" onClick={() => setMobileMenuOpen(false)}>
                    {t("actions.login")}
                  </Link>
                  <Link to="/register" className="btn-primary" onClick={() => setMobileMenuOpen(false)}>
                    {t("actions.createAccount")}
                  </Link>
                </div>
              ) : (
                <div className="grid grid-cols-2 gap-2">
                  <Link to="/profile" className="btn-secondary" onClick={() => setMobileMenuOpen(false)}>
                    <UserRound aria-hidden="true" size={17} />
                    {t("navigation.profile")}
                  </Link>
                  <button
                    onClick={handleLogout}
                    className="btn-ghost text-ink-500 hover:bg-red-50 hover:text-status-danger"
                    type="button"
                  >
                    <LogOut aria-hidden="true" className="directional-icon" size={17} />
                    {t("actions.logout")}
                  </button>
                </div>
              )}
            </nav>
          </div>
        )}
      </header>

      <main
        id="main-content"
        ref={mainRef}
        tabIndex={-1}
        className={`${isHomePage ? "w-full flex-1" : "page-container"} scroll-mt-24 focus:outline-none`}
      >
        <Suspense
          fallback={(
            <div className="flex min-h-[45vh] flex-col items-center justify-center gap-3 text-sm font-medium text-ink-500" role="status" aria-live="polite">
              <span className="icon-tile-neutral"><LoaderCircle aria-hidden="true" className="animate-spin" size={19} /></span>
              <p>{t("accessibility.loading")}</p>
            </div>
          )}
        >
          <div key={location.pathname} className="route-reveal min-w-0">
            <Outlet />
          </div>
        </Suspense>
      </main>

      <footer className="dark-section-raised relative overflow-hidden border-t border-white/10 text-white">
        <div
          aria-hidden="true"
          className="pointer-events-none absolute -right-28 -top-28 size-80 rounded-full bg-brand-500/10 blur-3xl"
        />
        <div className="container-shell grid gap-10 py-12 md:grid-cols-[1.5fr_1fr_1fr] md:py-16">
          <div className="max-w-md">
            <Link to="/" aria-label={t("accessibility.homeLabel")} className="inline-flex rounded-control">
              <BrandMark inverse />
            </Link>
            <p className="mt-4 font-reading text-sm leading-6 text-ink-400">
              {t("footer.description")}
            </p>
          </div>

          <div>
            <p className="text-sm font-semibold text-white">{t("footer.explore")}</p>
            <div className="mt-4 flex flex-col items-start gap-3">
              <FooterLink to="/">{t("navigation.home")}</FooterLink>
              <FooterLink to="/servers">{t("navigation.servers")}</FooterLink>
              {isAuthenticated && !isAdmin && <FooterLink to="/my-reservations">{t("navigation.reservations")}</FooterLink>}
              {isAdmin && <FooterLink to="/admin">{t("navigation.admin")}</FooterLink>}
            </div>
          </div>

          <div>
            <p className="text-sm font-semibold text-white">{t("footer.account")}</p>
            <div className="mt-4 flex flex-col items-start gap-3">
              {isAuthenticated ? (
                <>
                  <FooterLink to="/profile">{t("navigation.profile")}</FooterLink>
                  {!isAdmin && <FooterLink to="/my-services">{t("navigation.services")}</FooterLink>}
                </>
              ) : (
                <>
                  <FooterLink to="/login">{t("actions.login")}</FooterLink>
                  <FooterLink to="/register">{t("actions.createAccount")}</FooterLink>
                </>
              )}
            </div>
          </div>
        </div>

        <div className="border-t border-white/10">
          <div className="container-shell flex flex-col gap-2 py-5 text-xs text-ink-400 sm:flex-row sm:items-center sm:justify-between">
            <p>© {formatDate(currentTime, { year: "numeric" })} HardwareReserve. {t("footer.rights")}</p>
            <p>{t("footer.tagline")}</p>
          </div>
        </div>
      </footer>

      <SupportWidget />
      {isAuthenticated && <CommandPalette />}
    </div>
  );
}
