import {
  ArrowLeft,
  ArrowRight,
  Bot,
  BrainCircuit,
  CalendarPlus,
  Check,
  Code2,
  Cpu,
  Database,
  Gauge,
  Globe2,
  Layers3,
  MemoryStick,
  PencilLine,
  RotateCcw,
  Server as ServerIcon,
  Sparkles,
  X,
  type LucideIcon,
} from "lucide-react";
import { useEffect, useMemo, useRef, useState } from "react";
import { createPortal } from "react-dom";
import { useTranslation } from "react-i18next";
import { useLocale } from "../../i18n/useLocale";
import type { Server } from "../../types/api";
import {
  hasDedicatedGpu,
  recommendServers,
  type FinderGpuPreference,
  type FinderIntensity,
  type FinderPreferences,
  type FinderPriority,
  type FinderWorkload,
  type ServerRecommendation,
} from "../../utils/serverDiscovery";

interface SmartServerFinderProps {
  open: boolean;
  servers: Server[];
  onClose: () => void;
  onView: (serverId: number) => void;
  onReserve: (serverId: number) => void;
}

interface ChoiceOption<T extends string | number> {
  value: T;
  label: string;
  description?: string;
  icon?: LucideIcon;
}

interface ChoiceGroupProps<T extends string | number> {
  legend: string;
  options: Array<ChoiceOption<T>>;
  value: T;
  onChange: (value: T) => void;
  compact?: boolean;
}

const defaultPreferences: FinderPreferences = {
  workload: "general",
  customWorkload: "",
  intensity: "moderate",
  gpuPreference: "automatic",
  minimumRamGb: 32,
  durationHours: 24,
  priority: "balanced",
};

const workloadIcons: Record<FinderWorkload, LucideIcon> = {
  aiTraining: BrainCircuit,
  aiInference: Bot,
  rendering: Layers3,
  development: Code2,
  dataProcessing: Database,
  hosting: Globe2,
  general: Cpu,
  custom: PencilLine,
};

function ChoiceGroup<T extends string | number>({
  legend,
  options,
  value,
  onChange,
  compact = false,
}: ChoiceGroupProps<T>) {
  return (
    <fieldset>
      <legend className="text-sm font-semibold text-ink-900">{legend}</legend>
      <div className={`mt-3 grid gap-2 ${compact ? "sm:grid-cols-3" : "sm:grid-cols-2"}`}>
        {options.map((option) => {
          const selected = option.value === value;
          const Icon = option.icon;

          return (
            <label
              key={option.value}
              className={[
                "finder-choice control-press",
                selected && "finder-choice-selected",
                compact && "finder-choice-compact",
              ]
                .filter(Boolean)
                .join(" ")}
            >
              <input
                className="sr-only"
                type="radio"
                name={legend}
                value={option.value}
                checked={selected}
                onChange={() => onChange(option.value)}
              />
              {Icon && (
                <span className={selected ? "icon-tile size-9" : "icon-tile-neutral size-9"}>
                  <Icon aria-hidden="true" size={16} />
                </span>
              )}
              <span className="min-w-0 flex-1">
                <span className="block text-sm font-semibold text-ink-900">{option.label}</span>
                {option.description && (
                  <span className="mt-0.5 block font-reading text-xs leading-5 text-ink-500">
                    {option.description}
                  </span>
                )}
              </span>
              <span className="finder-choice-check" aria-hidden="true">
                {selected && <Check size={12} strokeWidth={3} />}
              </span>
            </label>
          );
        })}
      </div>
    </fieldset>
  );
}

function RecommendationCard({
  recommendation,
  durationHours,
  onView,
  onReserve,
}: {
  recommendation: ServerRecommendation;
  durationHours: number;
  onView: () => void;
  onReserve: () => void;
}) {
  const { t } = useTranslation();
  const { formatCurrency, formatNumber } = useLocale();
  const { server } = recommendation;
  const primaryHardware = hasDedicatedGpu(server) ? server.gpu : server.cpu;

  return (
    <article className="finder-result-card content-swap-enter">
      <div className="flex flex-wrap items-start justify-between gap-3">
        <div className="min-w-0">
          <span className={`finder-tradeoff finder-tradeoff-${recommendation.tradeoff}`}>
            {t(`catalog.finder.tradeoffs.${recommendation.tradeoff}`)}
          </span>
          <h3 dir="auto" className="bidi-auto mt-3 text-lg font-semibold text-ink-950">
            {primaryHardware}
          </h3>
          <p dir="auto" className="bidi-auto mt-1 truncate text-xs text-ink-500" title={server.cpu}>
            {server.cpu}
          </p>
        </div>
        <div className="finder-fit-score" aria-label={t("catalog.finder.fitScoreAria", { score: recommendation.fitScore })}>
          <span dir="ltr" className="text-lg font-bold text-brand-800">
            {formatNumber(recommendation.fitScore)}%
          </span>
          <span>{t("catalog.finder.fit")}</span>
        </div>
      </div>

      <div className="mt-4 grid grid-cols-3 gap-2">
        <div className="finder-spec">
          <MemoryStick aria-hidden="true" size={14} />
          <span dir="ltr">{server.ram}</span>
        </div>
        <div className="finder-spec">
          <ServerIcon aria-hidden="true" size={14} />
          <span dir="ltr">{server.storage}</span>
        </div>
        <div className="finder-spec">
          <Gauge aria-hidden="true" size={14} />
          <span dir="auto" className="truncate" title={server.os}>{server.os}</span>
        </div>
      </div>

      <ul className="mt-4 space-y-2">
        {recommendation.reasons.map((reason) => (
          <li key={reason} className="flex items-start gap-2 text-xs leading-5 text-ink-600">
            <Check aria-hidden="true" className="mt-0.5 text-status-success" size={14} strokeWidth={2.5} />
            <span>{t(`catalog.finder.reasons.${reason}`)}</span>
          </li>
        ))}
      </ul>

      <div className="mt-4 rounded-control border border-border-subtle bg-surface-muted/65 p-3">
        <p className="meta-text">{t("catalog.finder.estimatedFor", { hours: formatNumber(durationHours) })}</p>
        <p dir="auto" className="bidi-auto mt-1 text-base font-semibold text-ink-950">
          {formatCurrency(recommendation.estimatedCost)}
        </p>
      </div>

      <div className="mt-4 grid grid-cols-2 gap-2">
        <button type="button" className="btn-secondary w-full" onClick={onView}>
          {t("serverCard.viewSpecs")}
        </button>
        <button type="button" className="btn-primary w-full" onClick={onReserve}>
          <CalendarPlus aria-hidden="true" size={16} />
          {t("actions.reserve")}
        </button>
      </div>
    </article>
  );
}

export function SmartServerFinder({
  open,
  servers,
  onClose,
  onView,
  onReserve,
}: SmartServerFinderProps) {
  const { t } = useTranslation();
  const { formatNumber } = useLocale();
  const closeRef = useRef<HTMLButtonElement>(null);
  const dialogRef = useRef<HTMLElement>(null);
  const onCloseRef = useRef(onClose);
  const returnFocusRef = useRef<HTMLElement | null>(null);
  const [step, setStep] = useState(0);
  const [preferences, setPreferences] = useState<FinderPreferences>(defaultPreferences);

  useEffect(() => {
    onCloseRef.current = onClose;
  }, [onClose]);

  useEffect(() => {
    if (!open) {
      return;
    }

    returnFocusRef.current = document.activeElement instanceof HTMLElement ? document.activeElement : null;
    requestAnimationFrame(() => closeRef.current?.focus());
    const previousOverflow = document.body.style.overflow;
    document.body.style.overflow = "hidden";

    const handleKeyDown = (event: KeyboardEvent) => {
      if (event.key === "Escape") {
        onCloseRef.current();
        return;
      }
      if (event.key === "Tab" && dialogRef.current) {
        const focusable = [...dialogRef.current.querySelectorAll<HTMLElement>(
          'button:not([disabled]), textarea:not([disabled]), input:not([disabled]), select:not([disabled]), [tabindex]:not([tabindex="-1"])',
        )].filter((element) => !element.hasAttribute("hidden"));
        const first = focusable[0];
        const last = focusable.at(-1);

        if (first && last && event.shiftKey && document.activeElement === first) {
          event.preventDefault();
          last.focus();
        } else if (first && last && !event.shiftKey && document.activeElement === last) {
          event.preventDefault();
          first.focus();
        }
      }
    };

    window.addEventListener("keydown", handleKeyDown);
    return () => {
      document.body.style.overflow = previousOverflow;
      window.removeEventListener("keydown", handleKeyDown);
      returnFocusRef.current?.focus({ preventScroll: true });
    };
  }, [open]);

  const recommendations = useMemo(
    () => recommendServers(servers, preferences),
    [preferences, servers],
  );

  if (!open) {
    return null;
  }

  const workloadOptions: Array<ChoiceOption<FinderWorkload>> = (
    [
      "aiTraining",
      "aiInference",
      "rendering",
      "development",
      "dataProcessing",
      "hosting",
      "general",
      "custom",
    ] as FinderWorkload[]
  ).map((workload) => ({
    value: workload,
    label: t(`catalog.finder.workloads.${workload}.label`),
    description: t(`catalog.finder.workloads.${workload}.description`),
    icon: workloadIcons[workload],
  }));
  const intensityOptions: Array<ChoiceOption<FinderIntensity>> = (["light", "moderate", "heavy"] as FinderIntensity[])
    .map((value) => ({ value, label: t(`catalog.finder.intensity.${value}`) }));
  const gpuOptions: Array<ChoiceOption<FinderGpuPreference>> = (["automatic", "required", "notNeeded"] as FinderGpuPreference[])
    .map((value) => ({ value, label: t(`catalog.finder.gpu.${value}`) }));
  const priorityOptions: Array<ChoiceOption<FinderPriority>> = (["value", "balanced", "performance"] as FinderPriority[])
    .map((value) => ({ value, label: t(`catalog.finder.priority.${value}`) }));

  const updatePreferences = <Key extends keyof FinderPreferences>(key: Key, value: FinderPreferences[Key]) => {
    setPreferences((current) => ({ ...current, [key]: value }));
  };
  const reset = () => {
    setPreferences(defaultPreferences);
    setStep(0);
  };

  return createPortal(
    <div
      className="overlay-enter fixed inset-0 z-[110] flex items-end justify-center bg-ink-950/50 p-0 backdrop-blur-sm sm:items-center sm:p-6"
      role="presentation"
      onMouseDown={(event) => {
        if (event.currentTarget === event.target) {
          onClose();
        }
      }}
    >
      <section
        ref={dialogRef}
        role="dialog"
        aria-modal="true"
        aria-labelledby="smart-finder-title"
        aria-describedby="smart-finder-description"
        className="dialog-panel-enter flex max-h-[100dvh] w-full max-w-5xl flex-col overflow-hidden rounded-t-panel border border-white/70 bg-surface-raised shadow-floating sm:max-h-[92dvh] sm:rounded-panel"
      >
        <header className="relative overflow-hidden border-b border-white/10 bg-surface-inverse px-5 py-4 text-white sm:px-6 sm:py-5">
          <div aria-hidden="true" className="absolute -end-20 -top-24 size-56 rounded-full bg-brand-400/20 blur-3xl" />
          <div className="relative flex items-start justify-between gap-4">
            <div className="flex min-w-0 items-start gap-3">
              <span className="icon-tile-inverse size-10">
                <Sparkles aria-hidden="true" size={18} />
              </span>
              <div className="min-w-0">
                <p className="text-[0.68rem] font-bold uppercase tracking-[0.14em] text-brand-300">
                  {t("catalog.finder.eyebrow")}
                </p>
                <h2 id="smart-finder-title" className="mt-1 text-xl font-semibold text-white sm:text-2xl">
                  {t("catalog.finder.title")}
                </h2>
                <p id="smart-finder-description" className="mt-1 max-w-2xl font-reading text-xs leading-5 text-ink-300 sm:text-sm">
                  {t("catalog.finder.description")}
                </p>
              </div>
            </div>
            <button
              ref={closeRef}
              type="button"
              className="support-header-icon size-10"
              onClick={onClose}
              aria-label={t("catalog.finder.closeAria")}
            >
              <X aria-hidden="true" size={18} />
            </button>
          </div>
        </header>

        <div className="border-b border-border-subtle bg-white px-5 py-3 sm:px-6">
          <ol className="grid grid-cols-3 gap-2" aria-label={t("catalog.finder.progressLabel")}>
            {[t("catalog.finder.steps.workload"), t("catalog.finder.steps.needs"), t("catalog.finder.steps.results")].map((label, index) => (
              <li
                key={label}
                className={`finder-step ${index === step ? "finder-step-active" : ""} ${index < step ? "finder-step-complete" : ""}`}
                aria-current={index === step ? "step" : undefined}
              >
                <span className="finder-step-marker">{index < step ? <Check size={11} strokeWidth={3} /> : index + 1}</span>
                <span className="truncate">{label}</span>
              </li>
            ))}
          </ol>
        </div>

        <div className="min-h-0 flex-1 overflow-y-auto px-5 py-5 sm:px-6 sm:py-6">
          <div key={step} className="content-swap-enter">
            {step === 0 && (
              <div>
                <div>
                  <p className="section-kicker">{t("catalog.finder.workloadEyebrow")}</p>
                  <h3 className="mt-1 text-xl font-semibold text-ink-950">{t("catalog.finder.workloadTitle")}</h3>
                  <p className="mt-1 font-reading text-sm leading-6 text-ink-600">{t("catalog.finder.workloadCopy")}</p>
                </div>

                <div className="mt-5">
                  <ChoiceGroup
                    legend={t("catalog.finder.workloadLegend")}
                    options={workloadOptions}
                    value={preferences.workload}
                    onChange={(value) => updatePreferences("workload", value)}
                  />
                </div>

                {preferences.workload === "custom" && (
                  <label className="field mt-5">
                    <span>{t("catalog.finder.customLabel")}</span>
                    <textarea
                      dir="auto"
                      className="input min-h-28 resize-y font-reading"
                      value={preferences.customWorkload}
                      onChange={(event) => updatePreferences("customWorkload", event.target.value)}
                      maxLength={240}
                      placeholder={t("catalog.finder.customPlaceholder")}
                      autoFocus
                    />
                    <span className="field-hint flex justify-between gap-3">
                      <span>{t("catalog.finder.customHint")}</span>
                      <span>{formatNumber(preferences.customWorkload.length)}/{formatNumber(240)}</span>
                    </span>
                  </label>
                )}
              </div>
            )}

            {step === 1 && (
              <div>
                <div>
                  <p className="section-kicker">{t("catalog.finder.requirementsEyebrow")}</p>
                  <h3 className="mt-1 text-xl font-semibold text-ink-950">{t("catalog.finder.requirementsTitle")}</h3>
                  <p className="mt-1 font-reading text-sm leading-6 text-ink-600">{t("catalog.finder.requirementsCopy")}</p>
                </div>

                <div className="mt-6 grid gap-6 lg:grid-cols-2">
                  <ChoiceGroup
                    compact
                    legend={t("catalog.finder.intensityLabel")}
                    options={intensityOptions}
                    value={preferences.intensity}
                    onChange={(value) => updatePreferences("intensity", value)}
                  />
                  <ChoiceGroup
                    compact
                    legend={t("catalog.finder.gpuLabel")}
                    options={gpuOptions}
                    value={preferences.gpuPreference}
                    onChange={(value) => updatePreferences("gpuPreference", value)}
                  />

                  <label className="field">
                    <span>{t("catalog.finder.ramLabel")}</span>
                    <select
                      className="input"
                      value={preferences.minimumRamGb}
                      onChange={(event) => updatePreferences("minimumRamGb", Number(event.target.value))}
                    >
                      {[16, 32, 64, 128, 256].map((ram) => (
                        <option key={ram} value={ram}>{t("catalog.finder.ramOption", { value: formatNumber(ram) })}</option>
                      ))}
                    </select>
                  </label>

                  <label className="field">
                    <span>{t("catalog.finder.durationLabel")}</span>
                    <select
                      className="input"
                      value={preferences.durationHours}
                      onChange={(event) => updatePreferences("durationHours", Number(event.target.value))}
                    >
                      <option value={4}>{t("catalog.finder.duration.short")}</option>
                      <option value={24}>{t("catalog.finder.duration.day")}</option>
                      <option value={120}>{t("catalog.finder.duration.fiveDays")}</option>
                    </select>
                  </label>

                  <div className="lg:col-span-2">
                    <ChoiceGroup
                      compact
                      legend={t("catalog.finder.priorityLabel")}
                      options={priorityOptions}
                      value={preferences.priority}
                      onChange={(value) => updatePreferences("priority", value)}
                    />
                  </div>
                </div>
              </div>
            )}

            {step === 2 && (
              <div>
                <div className="flex flex-col gap-3 sm:flex-row sm:items-end sm:justify-between">
                  <div>
                    <p className="section-kicker">{t("catalog.finder.resultsEyebrow")}</p>
                    <h3 className="mt-1 text-xl font-semibold text-ink-950">{t("catalog.finder.resultsTitle")}</h3>
                    <p className="mt-1 font-reading text-sm leading-6 text-ink-600">
                      {t("catalog.finder.resultsCopy", { count: recommendations.length, formattedCount: formatNumber(recommendations.length) })}
                    </p>
                  </div>
                  <button type="button" className="btn-secondary shrink-0" onClick={() => setStep(1)}>
                    <PencilLine aria-hidden="true" size={15} />
                    {t("catalog.finder.refine")}
                  </button>
                </div>

                {preferences.workload === "custom" && recommendations[0] && (
                  <div className="mt-4 rounded-control border border-brand-200 bg-brand-50/60 px-4 py-3 text-sm text-brand-900">
                    {t("catalog.finder.interpretedAs", {
                      workload: t(`catalog.finder.workloads.${recommendations[0].resolvedWorkload}.label`),
                    })}
                  </div>
                )}

                {recommendations.length > 0 ? (
                  <div className="mt-5 grid gap-4 lg:grid-cols-3">
                    {recommendations.map((recommendation) => (
                      <RecommendationCard
                        key={recommendation.server.id}
                        recommendation={recommendation}
                        durationHours={preferences.durationHours}
                        onView={() => onView(recommendation.server.id)}
                        onReserve={() => onReserve(recommendation.server.id)}
                      />
                    ))}
                  </div>
                ) : (
                  <div className="state-panel mt-5">
                    <span className="icon-tile-neutral"><ServerIcon aria-hidden="true" size={20} /></span>
                    <h4 className="mt-4 card-title">{t("catalog.finder.noMatchTitle")}</h4>
                    <p className="mt-2 max-w-md body-copy">{t("catalog.finder.noMatchCopy")}</p>
                    <button type="button" className="btn-secondary mt-5" onClick={() => setStep(1)}>
                      {t("catalog.finder.adjust")}
                    </button>
                  </div>
                )}

                <p className="mt-4 font-reading text-xs leading-5 text-ink-500">
                  {t("catalog.finder.availabilityNote")}
                </p>
              </div>
            )}
          </div>
        </div>

        <footer className="flex items-center justify-between gap-3 border-t border-border-subtle bg-white px-5 py-4 sm:px-6">
          <button type="button" className="btn-ghost" onClick={reset} disabled={step === 0 && preferences === defaultPreferences}>
            <RotateCcw aria-hidden="true" size={15} />
            {t("catalog.finder.startOver")}
          </button>
          <div className="flex items-center gap-2">
            {step > 0 && (
              <button type="button" className="btn-secondary" onClick={() => setStep((current) => Math.max(0, current - 1))}>
                <ArrowLeft aria-hidden="true" className="directional-icon" size={16} />
                {t("actions.back")}
              </button>
            )}
            {step < 2 && (
              <button
                type="button"
                className="btn-primary"
                onClick={() => setStep((current) => Math.min(2, current + 1))}
                disabled={step === 0 && preferences.workload === "custom" && !preferences.customWorkload.trim()}
              >
                {step === 0 ? t("catalog.finder.continue") : t("catalog.finder.showMatches")}
                <ArrowRight aria-hidden="true" className="directional-icon" size={16} />
              </button>
            )}
          </div>
        </footer>
      </section>
    </div>,
    document.body,
  );
}
