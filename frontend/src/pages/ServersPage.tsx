import { useEffect, useMemo, useState } from "react";
import {
  AlertTriangle,
  ArrowUpDown,
  ChevronDown,
  CircuitBoard,
  Cpu,
  HardDrive,
  MemoryStick,
  MonitorCog,
  RotateCcw,
  Search,
  Server as ServerIcon,
  SlidersHorizontal,
  Sparkles,
  X,
  type LucideIcon,
} from "lucide-react";
import { useNavigate, useSearchParams } from "react-router-dom";
import { useTranslation } from "react-i18next";
import { serversApi } from "../api/serversApi";
import { useAuth } from "../auth/useAuth";
import { ServerCard } from "../components/ServerCard";
import { SmartServerFinder } from "../components/server/SmartServerFinder";
import { PageHeader } from "../components/ui/PageHeader";
import { useLocale } from "../i18n/useLocale";
import type { Server, ServerFilters } from "../types/api";
import { getApiErrorMessage } from "../utils/errors";
import {
  filterAndSortServers,
  type CatalogSort,
  type ComputeFilter,
} from "../utils/serverDiscovery";

const ramOptions = ["", "16GB", "32GB", "64GB", "128GB", "256GB"];
const storageOptions = ["", "512GB SSD", "1TB SSD", "1TB NVMe", "2TB NVMe", "4TB NVMe"];
const osOptions = ["", "Ubuntu 22.04", "Ubuntu 24.04", "Windows Server 2022"];

type ServerFilterKey = keyof ServerFilters;
type ActiveFilterKey = ServerFilterKey | "search" | "compute";

interface ActiveFilter {
  key: ActiveFilterKey;
  label: string;
  value: string;
}

interface FilterFieldLabelProps {
  icon: LucideIcon;
  children: string;
}

function FilterFieldLabel({ icon: Icon, children }: FilterFieldLabelProps) {
  return (
    <span className="flex items-center gap-2">
      <Icon aria-hidden="true" className="text-brand-600" size={15} strokeWidth={2} />
      {children}
    </span>
  );
}

function ServerCardSkeleton() {
  return (
    <div
      className="flex min-h-[33rem] flex-col overflow-hidden rounded-card border border-border-subtle bg-white shadow-card"
      aria-hidden="true"
    >
      <div className="space-y-6 bg-surface-inset/70 p-6">
        <div className="flex justify-between gap-4">
          <div className="skeleton h-7 w-32" />
          <div className="skeleton h-7 w-24" />
        </div>
        <div className="space-y-3">
          <div className="skeleton h-6 w-4/5" />
          <div className="skeleton h-4 w-3/5" />
        </div>
      </div>
      <div className="grid grid-cols-2 gap-5 p-6">
        <div className="skeleton h-12" />
        <div className="skeleton h-12" />
        <div className="skeleton col-span-2 h-12" />
      </div>
      <div className="skeleton mx-6 mt-auto h-20" />
      <div className="grid grid-cols-2 gap-2 p-6">
        <div className="skeleton h-11" />
        <div className="skeleton h-11" />
      </div>
    </div>
  );
}

export function ServersPage() {
  const { t } = useTranslation();
  const { formatNumber } = useLocale();
  const navigate = useNavigate();
  const [searchParams, setSearchParams] = useSearchParams();
  const { isAuthenticated } = useAuth();

  const [servers, setServers] = useState<Server[]>([]);
  const [loading, setLoading] = useState(true);
  const [loadError, setLoadError] = useState("");
  const [filters, setFilters] = useState<ServerFilters>({});
  const [compute, setCompute] = useState<ComputeFilter>("all");
  const [sort, setSort] = useState<CatalogSort>("priceAsc");
  const [search, setSearch] = useState("");
  const [filtersOpen, setFiltersOpen] = useState(() => window.matchMedia("(min-width: 1024px)").matches);
  const [advancedFiltersOpen, setAdvancedFiltersOpen] = useState(false);
  const finderOpen = searchParams.get("finder") === "open";
  const [requestVersion, setRequestVersion] = useState(0);

  useEffect(() => {
    let cancelled = false;

    const loadServers = async () => {
      setLoading(true);
      setLoadError("");

      try {
        const data = await serversApi.getServers();
        if (!cancelled) {
          setServers(data);
        }
      } catch (error) {
        if (!cancelled) {
          setServers([]);
          setLoadError(getApiErrorMessage(error, t("catalog.loadError")));
        }
      } finally {
        if (!cancelled) {
          setLoading(false);
        }
      }
    };

    void loadServers();
    return () => {
      cancelled = true;
    };
  }, [requestVersion, t]);

  const visibleServers = useMemo(
    () => filterAndSortServers(servers, { search, filters, compute, sort }),
    [compute, filters, search, servers, sort],
  );

  const activeFilters = useMemo<ActiveFilter[]>(() => {
    const items: ActiveFilter[] = [];

    if (search.trim()) {
      items.push({ key: "search", label: t("catalog.searchTitle"), value: search.trim() });
    }
    if (compute !== "all") {
      items.push({ key: "compute", label: t("catalog.computeType"), value: t(`catalog.compute.${compute}`) });
    }

    const filterLabels: Record<ServerFilterKey, string> = {
      cpu: "CPU",
      gpu: "GPU",
      ram: t("server.specs.memory"),
      storage: t("server.specs.storage"),
      os: t("server.specs.operatingSystem"),
    };

    (Object.keys(filterLabels) as ServerFilterKey[]).forEach((key) => {
      const value = filters[key];
      if (value) {
        items.push({ key, label: filterLabels[key], value });
      }
    });

    return items;
  }, [compute, filters, search, t]);

  const advancedFilterCount = [filters.cpu, filters.gpu, filters.storage].filter(Boolean).length;

  const updateFilter = (key: ServerFilterKey, value: string) => {
    setFilters((previous) => ({ ...previous, [key]: value || undefined }));
  };

  const removeFilter = (key: ActiveFilterKey) => {
    if (key === "search") {
      setSearch("");
      return;
    }
    if (key === "compute") {
      setCompute("all");
      return;
    }

    setFilters((previous) => ({ ...previous, [key]: undefined }));
  };

  const resetFilters = () => {
    setFilters({});
    setCompute("all");
    setSearch("");
    setAdvancedFiltersOpen(false);
  };

  const reserve = (serverId: number) => {
    if (!isAuthenticated) {
      navigate(`/login?returnUrl=${encodeURIComponent(`/reserve/${serverId}`)}`);
      return;
    }

    navigate(`/reserve/${serverId}`);
  };

  const setFinderOpen = (open: boolean) => {
    const next = new URLSearchParams(searchParams);
    if (open) {
      next.set("finder", "open");
    } else {
      next.delete("finder");
    }
    setSearchParams(next, { replace: true });
  };

  return (
    <div className="page-stack">
      <PageHeader
        eyebrow={t("catalog.eyebrow")}
        title={t("catalog.title")}
        description={t("catalog.description")}
        icon={ServerIcon}
        actions={(
          <div className="badge-success px-4 py-2">
            <span className="size-1.5 rounded-full bg-current" />
            {t("catalog.activeInventory")}
          </div>
        )}
      />

      <section className="finder-entry" aria-labelledby="finder-entry-title">
        <div className="relative flex min-w-0 items-start gap-3 sm:items-center">
          <span className="icon-tile-inverse size-10">
            <Sparkles aria-hidden="true" size={17} />
          </span>
          <div className="min-w-0">
            <p className="text-[0.68rem] font-bold uppercase tracking-[0.14em] text-brand-300">
              {t("catalog.finder.entryEyebrow")}
            </p>
            <h2 id="finder-entry-title" className="mt-1 text-base font-semibold text-white sm:text-lg">
              {t("catalog.finder.entryTitle")}
            </h2>
            <p className="mt-1 max-w-2xl font-reading text-xs leading-5 text-ink-300 sm:text-sm">
              {t("catalog.finder.entryCopy")}
            </p>
          </div>
        </div>
        <button type="button" className="btn-outline-light relative shrink-0" onClick={() => setFinderOpen(true)}>
          <Sparkles aria-hidden="true" size={16} />
          {t("catalog.finder.open")}
        </button>
      </section>

      <section
        className="surface-panel overflow-hidden"
        aria-labelledby="server-filters-heading"
      >
        <div className="border-b border-border-subtle bg-gradient-to-r from-white via-brand-50/50 to-white p-4 sm:p-5">
          <div className="flex items-center justify-between gap-3">
            <div className="flex items-center gap-2.5">
              <span className="icon-tile size-9"><Search aria-hidden="true" size={17} /></span>
              <div>
                <h2 id="server-filters-heading" className="card-title">{t("catalog.searchTitle")}</h2>
                <p className="mt-0.5 hidden text-xs text-ink-500 sm:block">{t("catalog.searchDescription")}</p>
              </div>
            </div>
            <button
              type="button"
              className="btn-secondary shrink-0"
              aria-expanded={filtersOpen}
              aria-controls="catalog-filters"
              onClick={() => setFiltersOpen((open) => !open)}
            >
              <SlidersHorizontal aria-hidden="true" size={17} />
              {t("catalog.filters")}{activeFilters.length > 0 ? ` (${formatNumber(activeFilters.length)})` : ""}
              <ChevronDown aria-hidden="true" className={`transition duration-base ${filtersOpen ? "rotate-180" : ""}`} size={16} />
            </button>
          </div>

          <div className="mt-4 grid gap-3 md:grid-cols-[minmax(0,1fr)_15rem]">
            <div className="relative">
              <Search aria-hidden="true" className="pointer-events-none absolute start-4 top-1/2 -translate-y-1/2 text-ink-400" size={18} />
              <input
                className="input min-h-12 bg-white ps-12"
                type="search"
                placeholder={t("catalog.searchPlaceholder")}
                value={search}
                onChange={(event) => setSearch(event.target.value)}
                aria-label={t("catalog.searchAria")}
                dir="auto"
              />
            </div>
            <label className="relative">
              <span className="sr-only">{t("catalog.sortLabel")}</span>
              <ArrowUpDown aria-hidden="true" className="pointer-events-none absolute start-4 top-1/2 z-10 -translate-y-1/2 text-ink-400" size={17} />
              <select
                className="input min-h-12 bg-white ps-11"
                value={sort}
                onChange={(event) => setSort(event.target.value as CatalogSort)}
                aria-label={t("catalog.sortLabel")}
              >
                <option value="priceAsc">{t("catalog.sort.priceAsc")}</option>
                <option value="priceDesc">{t("catalog.sort.priceDesc")}</option>
                <option value="ramDesc">{t("catalog.sort.ramDesc")}</option>
              </select>
            </label>
          </div>
        </div>

        {filtersOpen && (
          <div id="catalog-filters" className="filter-panel-enter p-4 sm:p-5">
            <div className="grid gap-4 lg:grid-cols-[1.25fr_1fr_1fr]">
              <fieldset className="field">
                <legend><FilterFieldLabel icon={Cpu}>{t("catalog.computeType")}</FilterFieldLabel></legend>
                <div className="grid grid-cols-3 gap-1 rounded-control border border-border-subtle bg-surface-muted/70 p-1">
                  {(["all", "gpu", "cpu"] as ComputeFilter[]).map((value) => (
                    <button
                      key={value}
                      type="button"
                      className={`catalog-segment ${compute === value ? "catalog-segment-active" : ""}`}
                      aria-pressed={compute === value}
                      onClick={() => setCompute(value)}
                    >
                      {t(`catalog.compute.${value}`)}
                    </button>
                  ))}
                </div>
              </fieldset>
              <label className="field">
                <FilterFieldLabel icon={MemoryStick}>{t("server.specs.memory")}</FilterFieldLabel>
                <select className="input" value={filters.ram ?? ""} onChange={(event) => updateFilter("ram", event.target.value)}>
                  {ramOptions.map((option) => <option key={option || "all"} value={option}>{option || t("catalog.allMemory")}</option>)}
                </select>
              </label>
              <label className="field">
                <FilterFieldLabel icon={MonitorCog}>{t("server.specs.operatingSystem")}</FilterFieldLabel>
                <select className="input" value={filters.os ?? ""} onChange={(event) => updateFilter("os", event.target.value)}>
                  {osOptions.map((option) => <option key={option || "all"} value={option}>{option || t("catalog.allSystems")}</option>)}
                </select>
              </label>
            </div>

            <button
              type="button"
              className="mt-4 inline-flex min-h-10 items-center gap-2 rounded-control px-2 text-sm font-semibold text-brand-700 transition hover:bg-brand-50 hover:text-brand-900"
              aria-expanded={advancedFiltersOpen}
              aria-controls="catalog-advanced-filters"
              onClick={() => setAdvancedFiltersOpen((open) => !open)}
            >
              <SlidersHorizontal aria-hidden="true" size={15} />
              {t("catalog.advancedFilters")}{advancedFilterCount > 0 ? ` (${formatNumber(advancedFilterCount)})` : ""}
              <ChevronDown aria-hidden="true" className={`transition duration-base ${advancedFiltersOpen ? "rotate-180" : ""}`} size={15} />
            </button>

            {advancedFiltersOpen && (
              <div id="catalog-advanced-filters" className="filter-panel-enter mt-3 grid gap-3 rounded-card border border-border-subtle bg-surface-muted/45 p-4 md:grid-cols-3">
                <label className="field">
                  <FilterFieldLabel icon={Cpu}>CPU</FilterFieldLabel>
                  <input className="input bg-white" placeholder={t("catalog.cpuPlaceholder")} dir="auto" value={filters.cpu ?? ""} onChange={(event) => updateFilter("cpu", event.target.value)} />
                </label>
                <label className="field">
                  <FilterFieldLabel icon={CircuitBoard}>GPU</FilterFieldLabel>
                  <input className="input bg-white" placeholder={t("catalog.gpuPlaceholder")} dir="auto" value={filters.gpu ?? ""} onChange={(event) => updateFilter("gpu", event.target.value)} />
                </label>
                <label className="field">
                  <FilterFieldLabel icon={HardDrive}>{t("server.specs.storage")}</FilterFieldLabel>
                  <select className="input bg-white" value={filters.storage ?? ""} onChange={(event) => updateFilter("storage", event.target.value)}>
                    {storageOptions.map((option) => <option key={option || "all"} value={option}>{option || t("catalog.allStorage")}</option>)}
                  </select>
                </label>
              </div>
            )}

            <div className="mt-4 flex min-h-12 flex-col gap-3 border-t border-border-subtle pt-4 sm:flex-row sm:items-center sm:justify-between">
              <div className="flex flex-wrap items-center gap-2" aria-label={t("catalog.activeFilters")}>
                {activeFilters.length > 0 ? activeFilters.map((filter) => (
                  <button
                    key={filter.key}
                    type="button"
                    className="control-press feedback-chip-enter inline-flex min-h-9 items-center gap-2 rounded-pill border border-brand-200 bg-white px-3 text-xs font-semibold text-brand-800 shadow-control transition hover:border-brand-300 hover:bg-brand-50"
                    onClick={() => removeFilter(filter.key)}
                    aria-label={t("catalog.removeFilter", { label: filter.label, value: filter.value })}
                  >
                    <span className="text-ink-500">{filter.label}</span>
                    <span dir="auto" className="bidi-auto max-w-40 truncate">{filter.value}</span>
                    <X aria-hidden="true" size={13} />
                  </button>
                )) : <p className="text-sm text-ink-500">{t("catalog.noFilters")}</p>}
              </div>

              <button type="button" className="btn-ghost min-h-9 shrink-0 px-3 py-1.5" disabled={activeFilters.length === 0} onClick={resetFilters}>
                <RotateCcw aria-hidden="true" size={15} />
                {t("catalog.resetAll")}
              </button>
            </div>
          </div>
        )}
      </section>

      <section aria-labelledby="catalog-results-heading">
        <div className="mb-5 flex flex-col gap-2 sm:flex-row sm:items-end sm:justify-between">
          <div>
            <p className="section-kicker">{t("catalog.resultsEyebrow")}</p>
            <h2 id="catalog-results-heading" className="mt-1 text-2xl font-semibold tracking-[-0.03em] text-ink-950">{t("catalog.resultsTitle")}</h2>
          </div>
          <p className="text-sm font-medium text-ink-500" aria-live="polite">
            {loading ? t("catalog.refreshing") : t("catalog.resultCount", { count: visibleServers.length, formattedCount: formatNumber(visibleServers.length) })}
          </p>
        </div>

        {loading ? (
          <div className="grid gap-5 md:grid-cols-2 xl:grid-cols-3" role="status" aria-label={t("catalog.loading")}>
            {Array.from({ length: 6 }, (_, index) => <ServerCardSkeleton key={index} />)}
          </div>
        ) : loadError ? (
          <div className="state-panel" role="alert">
            <span className="icon-tile-neutral"><AlertTriangle aria-hidden="true" size={21} /></span>
            <h2 className="mt-4 card-title">{t("catalog.unavailableTitle")}</h2>
            <p className="mt-2 max-w-md body-copy">{loadError}</p>
            <button type="button" className="btn-primary mt-5" onClick={() => setRequestVersion((version) => version + 1)}>
              <RotateCcw aria-hidden="true" size={16} />
              {t("actions.retry")}
            </button>
          </div>
        ) : visibleServers.length > 0 ? (
          <div key={`${search}-${compute}-${sort}-${Object.values(filters).join("-")}`} className="content-swap-enter grid gap-5 md:grid-cols-2 xl:grid-cols-3">
            {visibleServers.map((server) => (
              <ServerCard key={server.id} server={server} onView={() => navigate(`/server/${server.id}`)} onReserve={() => reserve(server.id)} />
            ))}
          </div>
        ) : (
          <div className="state-panel">
            <span className="icon-tile-neutral"><ServerIcon aria-hidden="true" size={21} /></span>
            <h2 className="mt-4 card-title">{t("catalog.noResultsTitle")}</h2>
            <p className="mt-2 max-w-md body-copy">{t("catalog.noResultsCopy")}</p>
            <button type="button" className="btn-primary mt-5" onClick={resetFilters}>
              <RotateCcw aria-hidden="true" size={16} />
              {t("actions.clearFilters")}
            </button>
          </div>
        )}
      </section>

      <SmartServerFinder
        open={finderOpen}
        servers={servers}
        onClose={() => setFinderOpen(false)}
        onView={(serverId) => navigate(`/server/${serverId}`)}
        onReserve={reserve}
      />
    </div>
  );
}
