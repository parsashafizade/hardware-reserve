import {
  Activity,
  Bell,
  CalendarDays,
  CircleDollarSign,
  Headphones,
  Home,
  LayoutDashboard,
  LoaderCircle,
  Mail,
  Search,
  Server as ServerIcon,
  Sparkles,
  UserRound,
  X,
  type LucideIcon,
} from "lucide-react";
import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { useTranslation } from "react-i18next";
import { useLocation, useNavigate } from "react-router-dom";
import { dashboardApi } from "../../api/dashboardApi";
import { useAuth } from "../../auth/useAuth";
import { useDashboard } from "../../dashboard/useDashboard";
import { useLocale } from "../../i18n/useLocale";
import { useNotifications } from "../../notifications/useNotifications";
import { useSupport } from "../../support/useSupport";
import type { CommandSearchResult } from "../../types/dashboard";
import { formatDateTime, isolateBidiText } from "../../utils/format";
import { rankPaletteCommands, type SearchablePaletteCommand } from "../../utils/commandPalette";

const openEventName = "hardwarereserve:open-command-palette";
const recentStorageKey = "hardwarereserve.command-palette.recent";

type CommandCategory = "actions" | "navigation" | "servers" | "reservations" | "account" | "support";

interface PaletteCommand extends SearchablePaletteCommand {
  category: CommandCategory;
  icon: LucideIcon;
  execute: () => void | Promise<void>;
  staticCommand?: boolean;
}

function getShortcutLabel(): string {
  return typeof navigator !== "undefined" && /Mac|iPhone|iPad/.test(navigator.platform)
    ? "⌘K"
    : "Ctrl K";
}

function readRecentCommands(): string[] {
  try {
    const value = JSON.parse(localStorage.getItem(recentStorageKey) ?? "[]");
    return Array.isArray(value) ? value.filter((item): item is string => typeof item === "string").slice(0, 5) : [];
  } catch {
    return [];
  }
}

function writeRecentCommand(commandId: string, current: string[]): string[] {
  const next = [commandId, ...current.filter((item) => item !== commandId)].slice(0, 5);
  try {
    localStorage.setItem(recentStorageKey, JSON.stringify(next));
  } catch {
    // Recent commands are an optional local convenience.
  }
  return next;
}

function getReservationStatusLabel(status: string, translate: (key: string) => string): string {
  switch (status.replace(/[\s_-]/g, "").toLowerCase()) {
    case "pendingpayment":
      return translate("status.reservation.pendingPayment");
    case "paid":
      return translate("status.reservation.paid");
    case "cancelled":
      return translate("status.reservation.cancelled");
    default:
      return status;
  }
}

export function CommandPaletteTrigger({ compact = false }: { compact?: boolean }) {
  const { t } = useTranslation();
  const shortcut = getShortcutLabel();
  return (
    <button
      type="button"
      className={compact ? "btn-icon" : "command-palette-trigger"}
      aria-label={t("commandPalette.open")}
      aria-haspopup="dialog"
      aria-keyshortcuts="Meta+K Control+K"
      onClick={() => window.dispatchEvent(new CustomEvent(openEventName))}
    >
      <Search aria-hidden="true" size={compact ? 19 : 16} />
      {!compact && <><span className="hidden 2xl:inline">{t("commandPalette.trigger")}</span><kbd>{shortcut}</kbd></>}
    </button>
  );
}

export function CommandPalette() {
  const { t } = useTranslation();
  const { formatNumber, formatCurrency } = useLocale();
  const { isAdmin } = useAuth();
  const { summary } = useDashboard();
  const { unreadCount } = useNotifications();
  const { openSupport } = useSupport();
  const navigate = useNavigate();
  const location = useLocation();
  const [open, setOpen] = useState(false);
  const [query, setQuery] = useState("");
  const [remoteResult, setRemoteResult] = useState<CommandSearchResult>({ servers: [], reservations: [] });
  const [remoteLoading, setRemoteLoading] = useState(false);
  const [remoteError, setRemoteError] = useState("");
  const [selectedIndex, setSelectedIndex] = useState(0);
  const [executingId, setExecutingId] = useState("");
  const [recentIds, setRecentIds] = useState<string[]>(readRecentCommands);
  const dialogRef = useRef<HTMLDivElement>(null);
  const inputRef = useRef<HTMLInputElement>(null);
  const restoreFocusRef = useRef<HTMLElement | null>(null);

  const close = useCallback((restoreFocus = true) => {
    setOpen(false);
    setQuery("");
    setRemoteResult({ servers: [], reservations: [] });
    setRemoteError("");
    setExecutingId("");
    if (restoreFocus) {
      window.setTimeout(() => restoreFocusRef.current?.focus(), 0);
    }
  }, []);

  const runNavigation = useCallback((to: string) => {
    close(false);
    navigate(to);
  }, [close, navigate]);

  const localCommands = useMemo<PaletteCommand[]>(() => {
    const commands: PaletteCommand[] = [
      { id: "home", category: "navigation", icon: Home, label: t("commandPalette.commands.home"), description: t("commandPalette.descriptions.home"), keywords: ["home", "خانه", "dashboard", "داشبورد"], execute: () => runNavigation("/"), staticCommand: true, priority: 20 },
      { id: "servers", category: "navigation", icon: ServerIcon, label: t("commandPalette.commands.servers"), description: t("commandPalette.descriptions.servers"), keywords: ["servers", "server", "سرور", "hardware", "سخت افزار"], execute: () => runNavigation("/servers"), staticCommand: true, priority: 18 },
      { id: "smart-finder", category: "actions", icon: Sparkles, label: t("commandPalette.commands.smartFinder"), description: t("commandPalette.descriptions.smartFinder"), keywords: ["find server", "finder", "recommend", "پیدا کردن سرور", "پیشنهاد سرور"], execute: () => runNavigation("/servers?finder=open"), staticCommand: true, priority: 24 },
      { id: "new-reservation", category: "actions", icon: CalendarDays, label: t("commandPalette.commands.newReservation"), description: t("commandPalette.descriptions.newReservation"), keywords: ["new reservation", "reserve", "رزرو جدید", "رزرو سرور"], execute: () => runNavigation("/servers"), staticCommand: true, priority: 15 },
      { id: "reservations", category: "navigation", icon: CalendarDays, label: t("commandPalette.commands.reservations"), description: t("commandPalette.descriptions.reservations"), keywords: ["reservations", "bookings", "رزرو", "رزروهای من"], execute: () => runNavigation("/my-reservations"), staticCommand: true, priority: 17 },
      { id: "activity", category: "navigation", icon: Bell, label: unreadCount > 0 ? t("commandPalette.commands.unreadNotifications", { count: unreadCount, formattedCount: formatNumber(unreadCount) }) : t("commandPalette.commands.activity"), description: t("commandPalette.descriptions.activity"), keywords: ["notifications", "activity", "اعلان", "اعلان ها", "فعالیت"], execute: () => runNavigation("/activity"), staticCommand: true, priority: unreadCount > 0 ? 28 : 12 },
      { id: "profile", category: "account", icon: UserRound, label: t("commandPalette.commands.profile"), description: t("commandPalette.descriptions.profile"), keywords: ["profile", "account", "پروفایل", "حساب"], execute: () => runNavigation("/profile"), staticCommand: true, priority: 10 },
      { id: "change-email", category: "account", icon: Mail, label: t("commandPalette.commands.changeEmail"), description: t("commandPalette.descriptions.changeEmail"), keywords: ["change email", "email", "تغییر ایمیل", "ایمیل"], execute: () => runNavigation("/profile?action=change-email#email-change"), staticCommand: true, priority: 8 },
      { id: "support", category: "support", icon: Headphones, label: t("commandPalette.commands.support"), description: t("commandPalette.descriptions.support"), keywords: ["support", "help", "contact", "پشتیبانی", "کمک"], execute: () => { close(false); openSupport(); }, staticCommand: true, priority: 16 },
    ];

    const primary = summary?.primaryReservation;
    if (primary) {
      if (summary.primaryState === "PENDING_PAYMENT") {
        commands.unshift({ id: "context-payment", category: "actions", icon: CircleDollarSign, label: t("commandPalette.commands.completePayment"), description: t("commandPalette.descriptions.contextReservation", { server: isolateBidiText(primary.server.gpu === "None" ? primary.server.cpu : primary.server.gpu) }), keywords: ["payment", "pay", "پرداخت"], execute: () => runNavigation(`/checkout/${primary.reservationId}`), priority: 45 });
      } else if (summary.primaryState === "ACTIVE") {
        commands.unshift({ id: "context-active", category: "actions", icon: Activity, label: t("commandPalette.commands.openActiveService"), description: t("commandPalette.descriptions.contextReservation", { server: isolateBidiText(primary.server.gpu === "None" ? primary.server.cpu : primary.server.gpu) }), keywords: ["active service", "open service", "سرویس فعال"], execute: () => runNavigation(`/my-reservations/${primary.reservationId}`), priority: 45 });
      } else if (summary.primaryState === "UPCOMING" || summary.primaryState === "STARTING_SOON") {
        commands.unshift({ id: "context-upcoming", category: "actions", icon: CalendarDays, label: t("commandPalette.commands.viewNextReservation"), description: t("commandPalette.descriptions.contextReservation", { server: isolateBidiText(primary.server.gpu === "None" ? primary.server.cpu : primary.server.gpu) }), keywords: ["next reservation", "upcoming", "رزرو بعدی", "رزرو پیش رو"], execute: () => runNavigation(`/my-reservations/${primary.reservationId}`), priority: 44 });
      }
    }

    if (isAdmin) {
      const sharedIds = new Set(["servers", "smart-finder", "activity", "profile", "change-email"]);
      const adminCommands = commands.filter((command) => sharedIds.has(command.id));
      adminCommands.unshift({ id: "admin", category: "navigation", icon: LayoutDashboard, label: t("commandPalette.commands.admin"), description: t("commandPalette.descriptions.admin"), keywords: ["admin", "management", "مدیریت"], execute: () => runNavigation("/admin"), staticCommand: true, priority: 30 });
      adminCommands.push({ id: "admin-support", category: "support", icon: Headphones, label: t("commandPalette.commands.support"), description: t("commandPalette.descriptions.support"), keywords: ["support", "help", "پشتیبانی"], execute: () => runNavigation("/admin/support"), staticCommand: true, priority: 16 });
      return adminCommands.map((command) => ({
        ...command,
        priority: (command.priority ?? 0) + (recentIds.includes(command.id) ? 4 - recentIds.indexOf(command.id) : 0),
      }));
    }

    return commands.map((command) => ({
      ...command,
      priority: (command.priority ?? 0) + (recentIds.includes(command.id) ? 4 - recentIds.indexOf(command.id) : 0),
    }));
  }, [close, formatNumber, isAdmin, openSupport, recentIds, runNavigation, summary, t, unreadCount]);

  const remoteCommands = useMemo<PaletteCommand[]>(() => [
    ...remoteResult.servers.map((server) => ({
      id: `server:${server.serverId}`,
      category: "servers" as const,
      icon: ServerIcon,
      label: server.label,
      description: t("commandPalette.serverDescription", { cpu: isolateBidiText(server.cpu), ram: isolateBidiText(server.ram), price: isolateBidiText(formatCurrency(server.pricePerHour)) }),
      keywords: [server.cpu, server.gpu, server.ram, String(server.serverId)],
      execute: () => runNavigation(`/server/${server.serverId}`),
      priority: 14,
    })),
    ...(isAdmin ? [] : remoteResult.reservations.map((reservation) => ({
      id: `reservation:${reservation.reservationId}`,
      category: "reservations" as const,
      icon: CalendarDays,
      label: t("commandPalette.reservationResult", { id: formatNumber(reservation.reservationId, { useGrouping: false }), server: isolateBidiText(reservation.serverLabel) }),
      description: t("commandPalette.reservationDescription", { date: formatDateTime(reservation.startTime), status: getReservationStatusLabel(reservation.status, t) }),
      keywords: [reservation.serverLabel, String(reservation.reservationId), `HR-${reservation.reservationId}`, reservation.status],
      execute: () => runNavigation(`/my-reservations/${reservation.reservationId}`),
      priority: 16,
    }))),
  ], [formatCurrency, formatNumber, isAdmin, remoteResult.reservations, remoteResult.servers, runNavigation, t]);

  const rankedResults = useMemo(
    () => rankPaletteCommands([...localCommands, ...remoteCommands], query).slice(0, 12),
    [localCommands, query, remoteCommands],
  );

  const groupedResults = useMemo(() => {
    const groups: Array<{ category: CommandCategory; commands: PaletteCommand[] }> = [];
    for (const command of rankedResults) {
      let group = groups.find((item) => item.category === command.category);
      if (!group) {
        group = { category: command.category, commands: [] };
        groups.push(group);
      }
      group.commands.push(command);
    }
    return groups;
  }, [rankedResults]);

  const results = useMemo(
    () => groupedResults.flatMap((group) => group.commands),
    [groupedResults],
  );

  useEffect(() => {
    const onOpen = () => {
      restoreFocusRef.current = document.activeElement instanceof HTMLElement ? document.activeElement : null;
      setOpen(true);
      setQuery("");
      setSelectedIndex(0);
    };
    const onShortcut = (event: KeyboardEvent) => {
      if ((event.metaKey || event.ctrlKey) && event.key.toLowerCase() === "k") {
        event.preventDefault();
        onOpen();
      }
    };
    window.addEventListener(openEventName, onOpen);
    window.addEventListener("keydown", onShortcut);
    return () => {
      window.removeEventListener(openEventName, onOpen);
      window.removeEventListener("keydown", onShortcut);
    };
  }, []);

  useEffect(() => {
    if (!open) {
      return;
    }
    const previousOverflow = document.body.style.overflow;
    document.body.style.overflow = "hidden";
    window.setTimeout(() => inputRef.current?.focus(), 0);
    return () => {
      document.body.style.overflow = previousOverflow;
    };
  }, [open]);

  useEffect(() => {
    close(false);
  }, [close, location.pathname, location.search]);

  useEffect(() => {
    if (!open || query.trim().length < 2) {
      setRemoteResult({ servers: [], reservations: [] });
      setRemoteLoading(false);
      setRemoteError("");
      return;
    }
    const controller = new AbortController();
    const timer = window.setTimeout(async () => {
      setRemoteLoading(true);
      setRemoteError("");
      try {
        const response = await dashboardApi.searchCommands(query.trim(), controller.signal);
        if (!controller.signal.aborted) {
          setRemoteResult(response);
        }
      } catch {
        if (!controller.signal.aborted) {
          setRemoteResult({ servers: [], reservations: [] });
          setRemoteError(t("commandPalette.searchError"));
        }
      } finally {
        if (!controller.signal.aborted) {
          setRemoteLoading(false);
        }
      }
    }, 180);
    return () => {
      window.clearTimeout(timer);
      controller.abort();
    };
  }, [open, query, t]);

  useEffect(() => {
    setSelectedIndex(0);
  }, [query]);

  useEffect(() => {
    if (selectedIndex >= results.length) {
      setSelectedIndex(Math.max(0, results.length - 1));
    }
  }, [results.length, selectedIndex]);

  const execute = async (command: PaletteCommand) => {
    if (executingId) {
      return;
    }
    setExecutingId(command.id);
    if (command.staticCommand) {
      setRecentIds((current) => writeRecentCommand(command.id, current));
    }
    try {
      await command.execute();
    } finally {
      setExecutingId("");
    }
  };

  const onKeyDown = (event: React.KeyboardEvent<HTMLInputElement>) => {
    if (event.key === "ArrowDown") {
      event.preventDefault();
      setSelectedIndex((index) => results.length ? (index + 1) % results.length : 0);
    } else if (event.key === "ArrowUp") {
      event.preventDefault();
      setSelectedIndex((index) => results.length ? (index - 1 + results.length) % results.length : 0);
    } else if (event.key === "Home") {
      event.preventDefault();
      setSelectedIndex(0);
    } else if (event.key === "End") {
      event.preventDefault();
      setSelectedIndex(Math.max(0, results.length - 1));
    } else if (event.key === "Enter" && results[selectedIndex]) {
      event.preventDefault();
      void execute(results[selectedIndex]);
    } else if (event.key === "Escape") {
      event.preventDefault();
      event.stopPropagation();
      close();
    }
  };

  const trapFocus = (event: React.KeyboardEvent<HTMLDivElement>) => {
    if (event.key === "Escape") {
      event.preventDefault();
      close();
      return;
    }
    if (event.key !== "Tab") {
      return;
    }
    const focusable = [...(dialogRef.current?.querySelectorAll<HTMLElement>("input, button, [href], [tabindex]:not([tabindex='-1'])") ?? [])]
      .filter((element) => !element.hasAttribute("disabled"));
    if (focusable.length === 0) {
      return;
    }
    const first = focusable[0];
    const last = focusable[focusable.length - 1];
    if (event.shiftKey && document.activeElement === first) {
      event.preventDefault();
      last.focus();
    } else if (!event.shiftKey && document.activeElement === last) {
      event.preventDefault();
      first.focus();
    }
  };

  if (!open) {
    return null;
  }

  let flatIndex = -1;
  return (
    <div className="command-palette-backdrop overlay-enter" onMouseDown={(event) => event.target === event.currentTarget && close()}>
      <div ref={dialogRef} className="command-palette-panel dialog-panel-enter" role="dialog" aria-modal="true" aria-labelledby="command-palette-title" onKeyDown={trapFocus}>
        <header className="flex items-center gap-3 border-b border-border-subtle px-4 py-3 sm:px-5">
          <Search aria-hidden="true" className="text-brand-700" size={20} />
          <label htmlFor="command-palette-search" className="sr-only">{t("commandPalette.searchLabel")}</label>
          <input
            ref={inputRef}
            id="command-palette-search"
            type="search"
            role="combobox"
            aria-expanded="true"
            aria-controls="command-palette-results"
            aria-activedescendant={results[selectedIndex] ? `command-option-${results[selectedIndex].id.replace(/[^a-zA-Z0-9_-]/g, "-")}` : undefined}
            aria-autocomplete="list"
            autoComplete="off"
            dir="auto"
            className="bidi-auto min-h-12 min-w-0 flex-1 bg-transparent text-base font-medium text-ink-950 outline-none placeholder:text-ink-400 sm:text-lg"
            placeholder={t("commandPalette.placeholder")}
            value={query}
            onChange={(event) => setQuery(event.target.value)}
            onKeyDown={onKeyDown}
          />
          {remoteLoading && <LoaderCircle aria-hidden="true" className="animate-spin text-brand-600" size={18} />}
          <button type="button" className="btn-icon size-9 min-h-9" aria-label={t("actions.close")} onClick={() => close()}><X aria-hidden="true" size={17} /></button>
        </header>

        <div className="sr-only"><h2 id="command-palette-title">{t("commandPalette.title")}</h2></div>
        <div id="command-palette-results" role="listbox" aria-label={t("commandPalette.results")} className="command-palette-results">
          {remoteError && <p role="status" className="border-b border-amber-200 bg-amber-50 px-4 py-2 text-xs text-amber-800">{remoteError}</p>}
          {groupedResults.length > 0 ? groupedResults.map((group) => (
            <section key={`${group.category}-${group.commands[0]?.id}`} role="group" aria-labelledby={`command-category-${group.category}-${group.commands[0]?.id}`}>
              <h3 id={`command-category-${group.category}-${group.commands[0]?.id}`} className="command-category-label">{t(`commandPalette.categories.${group.category}`)}</h3>
              <div className="px-2 pb-2">
                {group.commands.map((command) => {
                  flatIndex += 1;
                  const index = flatIndex;
                  const Icon = command.icon;
                  const selected = index === selectedIndex;
                  return (
                    <button
                      key={command.id}
                      id={`command-option-${command.id.replace(/[^a-zA-Z0-9_-]/g, "-")}`}
                      type="button"
                      role="option"
                      aria-selected={selected}
                      className={`command-result ${selected ? "command-result-selected" : ""}`}
                      onMouseEnter={() => setSelectedIndex(index)}
                      onClick={() => void execute(command)}
                      disabled={Boolean(executingId)}
                    >
                      <span className="icon-tile-neutral size-9"><Icon aria-hidden="true" size={16} /></span>
                      <span className="min-w-0 flex-1 text-start">
                        <span dir="auto" className="bidi-auto block truncate text-sm font-semibold text-ink-900">{command.label}</span>
                        {command.description && <span dir="auto" className="bidi-auto mt-0.5 block truncate font-reading text-xs text-ink-500">{command.description}</span>}
                      </span>
                      {executingId === command.id ? <LoaderCircle aria-hidden="true" className="animate-spin text-brand-600" size={16} /> : <span aria-hidden="true" className="hidden rounded-md border border-border-subtle bg-white px-1.5 py-0.5 font-latin text-[10px] text-ink-400 sm:inline">↵</span>}
                    </button>
                  );
                })}
              </div>
            </section>
          )) : (
            <div className="px-6 py-10 text-center">
              <span className="icon-tile-neutral mx-auto"><Search aria-hidden="true" size={18} /></span>
              <p className="mt-3 text-sm font-semibold text-ink-900">{t("commandPalette.emptyTitle")}</p>
              <p className="mt-1 font-reading text-xs leading-5 text-ink-500">{t("commandPalette.emptyCopy")}</p>
              <button type="button" className="btn-secondary mt-4 min-h-10 px-4 py-2" onClick={() => runNavigation("/servers?finder=open")}><Sparkles aria-hidden="true" size={15} />{t("commandPalette.commands.smartFinder")}</button>
            </div>
          )}
        </div>

        <footer className="hidden items-center justify-between gap-4 border-t border-border-subtle bg-surface-muted/55 px-4 py-2 text-[11px] text-ink-500 sm:flex">
          <span>{t("commandPalette.keyboardNavigate")}</span>
          <span>{t("commandPalette.keyboardClose")}</span>
        </footer>
      </div>
    </div>
  );
}
