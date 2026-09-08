import { useEffect, useRef, useState, type ReactNode } from "react";
import {
  ArrowRight,
  ArrowUpRight,
  CalendarCheck2,
  Check,
  CheckCircle2,
  Cpu,
  CreditCard,
  Globe2,
  HardDrive,
  KeyRound,
  MemoryStick,
  Network,
  ReceiptText,
  Search,
  Server as ServerIcon,
  ShieldCheck,
  Sparkles,
  Waypoints,
  Zap,
  type LucideIcon,
} from "lucide-react";
import { Link, useNavigate } from "react-router-dom";
import { useTranslation } from "react-i18next";
import { serversApi } from "../api/serversApi";
import { useAuth } from "../auth/useAuth";
import { PersonalizedHome } from "../components/dashboard/PersonalizedHome";
import { useLocale } from "../i18n/useLocale";
import type { Server } from "../types/api";
import { formatCurrency } from "../utils/format";

type FeaturedStatus = "loading" | "ready" | "error";

interface SectionHeadingProps {
  eyebrow: string;
  title: string;
  copy: string;
  centered?: boolean;
  inverse?: boolean;
}

interface MarketingRevealProps {
  children: ReactNode;
  className?: string;
}

function MarketingReveal({ children, className = "" }: MarketingRevealProps) {
  const elementRef = useRef<HTMLDivElement>(null);
  const [visible, setVisible] = useState(false);

  useEffect(() => {
    const element = elementRef.current;
    if (!element) {
      return;
    }

    const observer = new IntersectionObserver(
      ([entry]) => {
        if (entry.isIntersecting) {
          setVisible(true);
          observer.unobserve(element);
        }
      },
      { rootMargin: "0px 0px -8% 0px", threshold: 0.1 },
    );

    observer.observe(element);
    return () => observer.disconnect();
  }, []);

  return (
    <div
      ref={elementRef}
      className={["marketing-reveal", visible && "is-visible", className].filter(Boolean).join(" ")}
    >
      {children}
    </div>
  );
}

function CountUpMetric({ value, label }: { value: number; label: string }) {
  const { formatNumber } = useLocale();
  const elementRef = useRef<HTMLDivElement>(null);
  const [prefersReducedMotion] = useState(() => window.matchMedia("(prefers-reduced-motion: reduce)").matches);
  const [displayValue, setDisplayValue] = useState(0);

  useEffect(() => {
    const element = elementRef.current;
    if (!element) {
      return;
    }

    if (prefersReducedMotion) {
      return;
    }

    let animationFrame = 0;
    const observer = new IntersectionObserver(
      ([entry]) => {
        if (!entry.isIntersecting) {
          return;
        }

        const startedAt = performance.now();
        const duration = 650;
        const update = (now: number) => {
          const progress = Math.min((now - startedAt) / duration, 1);
          const easedProgress = 1 - Math.pow(1 - progress, 3);
          setDisplayValue(Math.round(value * easedProgress));
          if (progress < 1) {
            animationFrame = requestAnimationFrame(update);
          }
        };

        animationFrame = requestAnimationFrame(update);
        observer.disconnect();
      },
      { threshold: 0.45 },
    );

    observer.observe(element);
    return () => {
      observer.disconnect();
      cancelAnimationFrame(animationFrame);
    };
  }, [prefersReducedMotion, value]);

  return (
    <div
      ref={elementRef}
      className="flex w-fit items-center gap-3 rounded-control border border-border-subtle bg-surface-muted/65 px-4 py-3"
      aria-label={`${formatNumber(value)} ${label}`}
    >
      <span aria-hidden="true" className="text-2xl font-bold tracking-[-0.04em] text-brand-700">
        {formatNumber(prefersReducedMotion ? value : displayValue)}
      </span>
      <span aria-hidden="true" className="max-w-32 text-xs font-semibold leading-5 text-ink-600">
        {label}
      </span>
    </div>
  );
}

function SectionHeading({ eyebrow, title, copy, centered = false, inverse = false }: SectionHeadingProps) {
  return (
    <div className={centered ? "mx-auto max-w-3xl text-center" : "max-w-2xl"}>
      <p className={inverse ? "text-xs font-bold uppercase tracking-[0.18em] text-brand-300" : "section-kicker"}>
        {eyebrow}
      </p>
      <h2
        className={[
          "mt-3 text-3xl font-semibold tracking-[-0.04em] [text-wrap:balance] sm:text-4xl lg:text-[2.75rem] lg:leading-[1.08]",
          inverse ? "text-white" : "text-ink-950",
        ].join(" ")}
      >
        {title}
      </h2>
      <p className={["mt-4 font-reading text-base leading-7 sm:text-lg", inverse ? "text-ink-300" : "text-ink-600"].join(" ")}>
        {copy}
      </p>
    </div>
  );
}

function HeroBookingPreview() {
  const { t } = useTranslation();
  return (
    <div className="relative mx-auto w-full max-w-[25rem]" aria-label={t("home.preview.eyebrow")}>
      <div className="absolute -inset-10 rounded-full bg-brand-500/20 blur-3xl" aria-hidden="true" />
      <div className="relative overflow-hidden rounded-[1.75rem] border border-white/15 bg-white/[0.09] p-3 shadow-dark backdrop-blur-xl">
        <div className="rounded-[1.3rem] border border-white/10 bg-surface-inverse/90 p-4 sm:p-5">
          <div className="flex items-center justify-between gap-4 border-b border-white/10 pb-4">
            <div className="flex items-center gap-3">
              <span className="icon-tile-inverse size-10">
                <Network aria-hidden="true" size={18} />
              </span>
              <div>
                <p className="text-sm font-semibold text-white">{t("home.preview.title")}</p>
                <p className="mt-0.5 text-xs text-ink-400">{t("home.preview.description")}</p>
              </div>
            </div>
            <span className="inline-flex items-center gap-2 rounded-pill border border-emerald-300/15 bg-emerald-400/10 px-2.5 py-1 text-[11px] font-semibold text-emerald-300">
              <span className="size-1.5 rounded-full bg-emerald-300 shadow-[0_0_12px_rgba(110,231,183,0.85)]" />
              {t("home.preview.ready")}
            </span>
          </div>

          <div className="mt-5 rounded-2xl border border-white/10 bg-white/[0.045] p-4">
            <div className="flex items-start justify-between gap-4">
              <div>
                <p className="text-xs font-semibold uppercase tracking-[0.14em] text-brand-300">{t("home.preview.selectedHardware")}</p>
                <p className="mt-2 text-base font-semibold text-white">{t("home.preview.gpuInstance")}</p>
                <p className="mt-1 text-xs text-ink-400">{t("home.preview.highMemory")}</p>
              </div>
              <span className="inline-flex size-10 items-center justify-center rounded-xl bg-brand-400/10 text-brand-200">
                <Cpu aria-hidden="true" size={19} />
              </span>
            </div>

            <div className="mt-5 grid grid-cols-[1fr_auto_1fr] items-center gap-3">
              <div className="rounded-xl bg-white/[0.05] p-3">
                <p className="text-[10px] font-bold uppercase tracking-[0.14em] text-ink-400">{t("home.preview.starts")}</p>
                <p dir="ltr" className="technical-value mt-1 text-sm font-semibold text-white">10:00 UTC</p>
              </div>
              <ArrowRight aria-hidden="true" className="directional-icon text-brand-300" size={16} />
              <div className="rounded-xl bg-white/[0.05] p-3">
                <p className="text-[10px] font-bold uppercase tracking-[0.14em] text-ink-400">{t("home.preview.ends")}</p>
                <p dir="ltr" className="technical-value mt-1 text-sm font-semibold text-white">16:00 UTC</p>
              </div>
            </div>
          </div>

          <div className="mt-4 hidden grid-cols-2 gap-2 sm:grid">
            <div className="rounded-xl border border-white/10 bg-white/[0.035] px-3 py-3">
              <p className="text-[10px] font-bold uppercase tracking-[0.14em] text-ink-400">{t("home.preview.pricing")}</p>
              <p className="mt-1 text-xs font-medium text-ink-200">{t("home.preview.pricingValue")}</p>
            </div>
            <div className="rounded-xl border border-white/10 bg-white/[0.035] px-3 py-3">
              <p className="text-[10px] font-bold uppercase tracking-[0.14em] text-ink-400">{t("home.preview.conflict")}</p>
              <p className="mt-1 text-xs font-medium text-ink-200">{t("home.preview.conflictValue")}</p>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}

function TrustItem({
  icon: Icon,
  title,
  copy,
}: {
  icon: LucideIcon;
  title: string;
  copy: string;
}) {
  return (
    <div className="flex items-start gap-3 py-2 sm:px-3">
      <span className="icon-tile size-10">
        <Icon aria-hidden="true" size={18} />
      </span>
      <div>
        <p className="text-sm font-semibold text-ink-950">{title}</p>
        <p className="mt-1 font-reading text-xs leading-5 text-ink-500">{copy}</p>
      </div>
    </div>
  );
}

function ReservationWorkflowPreview() {
  const { t } = useTranslation();
  return (
    <div className="h-full bg-gradient-to-br from-white via-white to-brand-50 p-5 sm:p-8 lg:p-10">
      <div className="mx-auto max-w-lg rounded-[1.6rem] border border-border-subtle bg-white p-4 shadow-lift sm:p-5">
        <div className="flex items-start justify-between gap-4 border-b border-border-subtle pb-4">
          <div className="flex items-center gap-3">
            <span className="icon-tile">
              <CalendarCheck2 aria-hidden="true" size={19} />
            </span>
            <div>
              <p className="text-sm font-semibold text-ink-950">{t("home.workflow.previewEyebrow")}</p>
              <p className="mt-0.5 text-xs text-ink-500">{t("home.workflow.previewTitle")}</p>
            </div>
          </div>
          <span className="badge-success">
            <span className="size-1.5 rounded-full bg-current" />
            {t("common.available")}
          </span>
        </div>

        <div className="mt-5 rounded-2xl bg-surface-muted/80 p-4">
          <div className="flex items-center gap-3">
            <span className="icon-tile-neutral size-10">
              <Cpu aria-hidden="true" size={18} />
            </span>
            <div className="min-w-0">
              <p className="truncate text-sm font-semibold text-ink-950">{t("home.workflow.highPerformance")}</p>
              <p className="mt-0.5 text-xs text-ink-500">{t("home.workflow.specsConfirmed")}</p>
            </div>
          </div>
        </div>

        <div className="mt-4 grid grid-cols-2 gap-3">
          <div className="rounded-control border border-border-subtle p-3">
            <p className="text-xs text-ink-500">{t("home.workflow.startTime")}</p>
            <p className="mt-1 text-sm font-semibold text-ink-900">{t("home.workflow.futureSlot")}</p>
          </div>
          <div className="rounded-control border border-border-subtle p-3">
            <p className="text-xs text-ink-500">{t("home.workflow.endTime")}</p>
            <p className="mt-1 text-sm font-semibold text-ink-900">{t("home.workflow.selectedWindow")}</p>
          </div>
        </div>

        <div className="mt-4 flex items-center gap-3 rounded-control border border-brand-200 bg-brand-50 p-3.5">
          <span className="inline-flex size-9 items-center justify-center rounded-xl bg-white text-brand-700 shadow-control">
            <ReceiptText aria-hidden="true" size={17} />
          </span>
          <div>
            <p className="text-xs font-semibold text-brand-900">{t("home.workflow.totalBeforeConfirmation")}</p>
            <p className="mt-0.5 text-[11px] text-brand-700">{t("home.workflow.pricingRules")}</p>
          </div>
        </div>

      </div>
    </div>
  );
}

function FeaturedHardwareRow({ server, onReserve }: { server: Server; onReserve: () => void }) {
  const { t } = useTranslation();
  return (
    <article className="group grid gap-5 px-5 py-6 transition duration-base hover:bg-brand-50/60 sm:px-7 md:grid-cols-[auto_minmax(0,1.25fr)_minmax(0,0.85fr)_auto] md:items-center lg:px-8">
      <span className="inline-flex size-12 items-center justify-center rounded-2xl border border-brand-200 bg-gradient-to-br from-brand-50 to-white text-brand-700 shadow-control transition duration-base group-hover:-translate-y-0.5 group-hover:shadow-glow">
        <Cpu aria-hidden="true" size={21} />
      </span>

      <div className="min-w-0">
        <div className="flex flex-wrap items-center gap-2">
          <span className="badge-success">
            <span className="size-1.5 rounded-full bg-current" />
            {t("home.featured.active")}
          </span>
          <span dir="auto" className="bidi-auto text-xs font-medium text-ink-500">{server.os}</span>
        </div>
        <h3 dir="auto" className="bidi-auto mt-3 truncate text-lg font-semibold tracking-[-0.025em] text-ink-950" title={server.gpu}>
          {server.gpu === "None" ? t("home.featured.cpuInstance") : server.gpu}
        </h3>
        <p dir="auto" className="bidi-auto mt-1 truncate text-sm text-ink-600" title={server.cpu}>
          {server.cpu}
        </p>
      </div>

      <dl className="grid grid-cols-2 gap-3 text-sm">
        <div>
          <dt className="flex items-center gap-1.5 text-xs text-ink-500">
            <MemoryStick aria-hidden="true" size={14} />
            {t("server.specs.memory")}
          </dt>
          <dd dir="auto" className="bidi-auto mt-1 font-semibold text-ink-900">{server.ram}</dd>
        </div>
        <div>
          <dt className="flex items-center gap-1.5 text-xs text-ink-500">
            <HardDrive aria-hidden="true" size={14} />
            {t("server.specs.storage")}
          </dt>
          <dd dir="auto" className="bidi-auto mt-1 truncate font-semibold text-ink-900">{server.storage}</dd>
        </div>
      </dl>

      <div className="flex flex-col gap-3 md:items-end">
        <p className="text-start md:text-end">
          <span className="block text-xs text-ink-500">{t("home.featured.from")}</span>
          <span dir="auto" className="bidi-auto mt-1 inline-flex items-baseline gap-1 text-lg font-bold tracking-tight text-ink-950">
            {formatCurrency(server.pricePerHour)}
            <span className="text-xs font-medium text-ink-500">{t("server.labels.perHour")}</span>
          </span>
        </p>
        <div className="flex gap-2">
          <Link to={"/server/" + server.id} className="btn-secondary min-h-10 px-3.5 py-2">
            {t("home.featured.details")}
          </Link>
          <button type="button" className="btn-primary min-h-10 px-3.5 py-2" onClick={onReserve}>
            {t("actions.reserve")}
            <ArrowUpRight aria-hidden="true" className="directional-icon" size={15} />
          </button>
        </div>
      </div>
    </article>
  );
}

function FeaturedHardwareSkeleton() {
  return (
    <div className="grid gap-5 px-5 py-6 sm:px-7 md:grid-cols-[3rem_minmax(0,1.25fr)_minmax(0,0.85fr)_10rem] md:items-center lg:px-8" aria-hidden="true">
      <div className="skeleton size-12" />
      <div className="space-y-3">
        <div className="skeleton h-4 w-20" />
        <div className="skeleton h-5 w-3/4" />
        <div className="skeleton h-4 w-1/2" />
      </div>
      <div className="grid grid-cols-2 gap-3">
        <div className="skeleton h-11" />
        <div className="skeleton h-11" />
      </div>
      <div className="skeleton h-16" />
    </div>
  );
}

export function HomePage() {
  const { t } = useTranslation();
  const { formatNumber } = useLocale();
  const [featuredServers, setFeaturedServers] = useState<Server[]>([]);
  const [activeServerCount, setActiveServerCount] = useState(0);
  const [featuredStatus, setFeaturedStatus] = useState<FeaturedStatus>("loading");
  const navigate = useNavigate();
  const { isAuthenticated } = useAuth();

  useEffect(() => {
    let active = true;

    const loadFeatured = async () => {
      try {
        const servers = await serversApi.getServers();
        if (!active) {
          return;
        }

        const activeServers = servers.filter((server) => server.isActive);
        setFeaturedServers(activeServers.slice(0, 3));
        setActiveServerCount(activeServers.length);
        setFeaturedStatus("ready");
      } catch {
        if (active) {
          setFeaturedStatus("error");
        }
      }
    };

    void loadFeatured();
    return () => {
      active = false;
    };
  }, []);

  const goToReserve = (serverId: number) => {
    if (!isAuthenticated) {
      navigate("/login?returnUrl=" + encodeURIComponent("/reserve/" + serverId));
      return;
    }

    navigate("/reserve/" + serverId);
  };

  return (
    <div className="overflow-hidden bg-surface-base">
      {isAuthenticated ? (
        <PersonalizedHome />
      ) : (
        <>
      <section className="relative isolate min-h-[36rem] overflow-hidden bg-surface-inverse text-white lg:min-h-[39rem]">
        {/* Photo by panumas nikhomkhai via Pexels, used under the Pexels license. */}
        <img
          src="/assets/server-rack-blue.webp"
          alt={t("home.hero.imageAlt")}
          width={1800}
          height={1198}
          loading="eager"
          decoding="async"
          fetchPriority="high"
          className="home-hero-media absolute inset-0 -z-30 h-full w-full object-cover"
        />
        <div className="home-hero-horizontal-overlay absolute inset-0 -z-20" />
        <div className="absolute inset-0 -z-20 bg-[linear-gradient(180deg,rgba(7,17,31,0.12)_0%,rgba(7,17,31,0.05)_55%,rgba(7,17,31,0.92)_100%)]" />
        <div className="absolute inset-0 -z-10 opacity-[0.15] [background-image:linear-gradient(rgba(148,163,184,0.2)_1px,transparent_1px),linear-gradient(90deg,rgba(148,163,184,0.2)_1px,transparent_1px)] [background-size:72px_72px] [mask-image:linear-gradient(to_bottom,black,transparent_92%)]" />
        <div className="absolute -left-40 top-24 -z-10 size-96 rounded-full border border-brand-300/10" aria-hidden="true" />

        <div className="container-shell relative grid min-h-[36rem] items-center gap-8 py-10 sm:py-12 lg:min-h-[39rem] lg:grid-cols-[1.02fr_0.98fr] lg:gap-12 lg:py-12">
          <div className="reveal max-w-3xl">
            <div className="inline-flex items-center gap-2 rounded-pill border border-brand-300/20 bg-brand-400/10 px-3 py-1.5 text-xs font-semibold text-brand-100 backdrop-blur-md">
              <Sparkles aria-hidden="true" size={14} />
              {t("home.hero.eyebrow")}
            </div>

            <h1 className="mt-6 max-w-[16ch] text-[clamp(2.4rem,4.8vw,4.35rem)] font-semibold leading-[1.08] tracking-[-0.05em] text-white [text-wrap:balance]">
              {t("home.hero.titleStart")}
              <span className="mt-2 block bg-gradient-to-r from-brand-200 via-white to-brand-300 bg-clip-text text-transparent">
                {t("home.hero.titleAccent")}
              </span>
            </h1>

            <p className="mt-5 max-w-xl font-reading text-base leading-7 text-ink-300 sm:text-lg sm:leading-8">
              {t("home.hero.description")}
            </p>

            <div className="mt-7 flex flex-col gap-3 sm:flex-row">
              <Link to="/servers" className="btn-light px-6">
                {t("home.hero.primaryCta")}
                <ArrowRight aria-hidden="true" className="directional-icon" size={17} />
              </Link>
              <a href="#how-it-works" className="btn-outline-light px-6">
                {t("home.hero.secondaryCta")}
              </a>
            </div>

            <div className="mt-7 flex flex-col gap-3 text-sm text-ink-300 sm:flex-row sm:flex-wrap sm:gap-x-6">
              {[
                t("home.hero.hourlyPricing"),
                t("home.hero.safeWindows"),
                t("home.hero.accountHandoff"),
              ].map((item) => (
                <span key={item} className="inline-flex items-center gap-2">
                  <CheckCircle2 aria-hidden="true" className="text-emerald-300" size={16} />
                  {item}
                </span>
              ))}
            </div>
          </div>

          <div className="reveal reveal-delay-2 flex min-h-[18rem] items-end justify-center sm:min-h-[20rem] lg:min-h-[27rem] lg:justify-end">
            <HeroBookingPreview />
          </div>
        </div>
      </section>

      <div className="relative z-10 -mt-10">
        <div className="container-shell">
          <div className="surface-panel grid gap-3 p-4 sm:grid-cols-3 sm:p-5 sm:[&>*+*]:border-s sm:[&>*+*]:border-border-subtle">
            <TrustItem
              icon={ReceiptText}
              title={t("home.trust.costTitle")}
              copy={t("home.trust.costCopy")}
            />
            <TrustItem
              icon={ShieldCheck}
              title={t("home.trust.windowTitle")}
              copy={t("home.trust.windowCopy")}
            />
            <TrustItem
              icon={KeyRound}
              title={t("home.trust.accessTitle")}
              copy={t("home.trust.accessCopy")}
            />
          </div>
        </div>
      </div>
        </>
      )}

      <section id="how-it-works" className="scroll-mt-24 bg-surface-canvas py-16 sm:py-20">
        <MarketingReveal className="container-shell">
          <SectionHeading
            eyebrow={t("home.workflow.eyebrow")}
            title={t("home.workflow.title")}
            copy={t("home.workflow.copy")}
          />

          <div className="dark-section-raised mt-8 overflow-hidden rounded-[2rem] border border-white/10 shadow-dark sm:mt-10">
            <div className="grid lg:grid-cols-[0.88fr_1.12fr]">
              <ol className="marketing-stagger divide-y divide-white/10 px-6 py-4 sm:px-9 sm:py-6 lg:px-10 lg:py-8">
                {[
                  {
                    step: "01",
                    icon: Search,
                    title: t("home.workflow.chooseTitle"),
                    copy: t("home.workflow.chooseCopy"),
                  },
                  {
                    step: "02",
                    icon: CalendarCheck2,
                    title: t("home.workflow.reserveTitle"),
                    copy: t("home.workflow.reserveCopy"),
                  },
                  {
                    step: "03",
                    icon: CreditCard,
                    title: t("home.workflow.accessTitle"),
                    copy: t("home.workflow.accessCopy"),
                  },
                ].map(({ step, icon: Icon, title, copy }) => (
                  <li key={step} className="group grid gap-4 py-7 sm:grid-cols-[3rem_1fr] sm:gap-5">
                    <span className="inline-flex size-11 items-center justify-center rounded-xl border border-white/10 bg-white/[0.06] text-brand-200 transition duration-base group-hover:border-brand-300/25 group-hover:bg-brand-400/10">
                      <Icon aria-hidden="true" size={19} />
                    </span>
                    <div>
                      <p className="text-[10px] font-bold uppercase tracking-[0.18em] text-brand-300">{t("home.workflow.step", { number: formatNumber(Number(step), { minimumIntegerDigits: 2, useGrouping: false }) })}</p>
                      <h3 className="mt-2 text-lg font-semibold tracking-[-0.02em] text-white">{title}</h3>
                      <p className="mt-2 font-reading text-sm leading-6 text-ink-400">{copy}</p>
                    </div>
                  </li>
                ))}
              </ol>

              <ReservationWorkflowPreview />
            </div>
          </div>
        </MarketingReveal>
      </section>

      <section id="featured-hardware" className="scroll-mt-24 bg-surface-base py-16 sm:py-20">
        <MarketingReveal className="container-shell">
          <div className="flex flex-col gap-5 sm:flex-row sm:items-end sm:justify-between">
            <SectionHeading
              eyebrow={t("home.featured.eyebrow")}
              title={t("home.featured.title")}
              copy={t("home.featured.copy")}
            />
            <div className="flex shrink-0 flex-col items-start gap-3 sm:items-end">
              {featuredStatus === "ready" && activeServerCount > 0 && (
                <CountUpMetric value={activeServerCount} label={t("home.featured.metricLabel")} />
              )}
              <Link to="/servers" className="inline-flex items-center gap-2 text-sm font-semibold text-brand-700 transition hover:text-brand-900">
                {t("home.featured.fullCatalog")}
                <ArrowRight aria-hidden="true" className="directional-icon" size={16} />
              </Link>
            </div>
          </div>

          <div className="mt-8 divide-y divide-border-subtle overflow-hidden rounded-[1.75rem] border border-border-subtle bg-white shadow-lift sm:mt-10" aria-live="polite">
            {featuredStatus === "loading" && [0, 1, 2].map((index) => <FeaturedHardwareSkeleton key={index} />)}

            {featuredStatus === "ready" &&
              featuredServers.map((server) => (
                <FeaturedHardwareRow key={server.id} server={server} onReserve={() => goToReserve(server.id)} />
              ))}

            {featuredStatus === "ready" && featuredServers.length === 0 && (
              <div className="px-6 py-12 text-center">
                <ServerIcon aria-hidden="true" className="mx-auto text-ink-400" size={28} />
                <h3 className="mt-4 text-lg font-semibold text-ink-950">{t("home.featured.emptyTitle")}</h3>
                <p className="mt-2 font-reading text-sm text-ink-600">{t("home.featured.emptyCopy")}</p>
              </div>
            )}

            {featuredStatus === "error" && (
              <div className="flex flex-col items-center justify-between gap-5 px-6 py-9 text-center sm:flex-row sm:text-start">
                <div>
                  <h3 className="font-semibold text-ink-950">{t("home.featured.errorTitle")}</h3>
                  <p className="mt-1 font-reading text-sm text-ink-600">{t("home.featured.errorCopy")}</p>
                </div>
                <Link to="/servers" className="btn-secondary shrink-0">
                  {t("home.featured.openCatalog")}
                </Link>
              </div>
            )}
          </div>
        </MarketingReveal>
      </section>

      <section id="infrastructure" className="relative isolate scroll-mt-24 overflow-hidden bg-surface-inverse py-16 text-white sm:py-20">
        <div className="absolute inset-0 -z-20 bg-[radial-gradient(circle_at_76%_54%,rgba(59,130,246,0.22),transparent_40%),radial-gradient(circle_at_4%_10%,rgba(37,99,235,0.12),transparent_28%)]" />
        <div className="absolute inset-0 -z-10 opacity-[0.12] [background-image:linear-gradient(rgba(148,163,184,0.18)_1px,transparent_1px),linear-gradient(90deg,rgba(148,163,184,0.18)_1px,transparent_1px)] [background-size:64px_64px]" />

        <MarketingReveal className="container-shell">
          <div className="grid items-center gap-10 lg:grid-cols-[0.72fr_1.28fr] lg:gap-10">
            <div>
              <span className="icon-tile-inverse size-12">
                <Globe2 aria-hidden="true" size={22} />
              </span>
              <div className="mt-7">
                <SectionHeading
                  eyebrow={t("home.infrastructure.eyebrow")}
                  title={t("home.infrastructure.title")}
                  copy={t("home.infrastructure.copy")}
                  inverse
                />
              </div>

              <ul className="mt-7 space-y-3 text-sm text-ink-300">
                {[
                  t("home.infrastructure.catalog"),
                  t("home.infrastructure.validation"),
                  t("home.infrastructure.workflow"),
                ].map((item) => (
                  <li key={item} className="flex items-center gap-3">
                    <span className="inline-flex size-6 items-center justify-center rounded-full bg-brand-400/15 text-brand-200">
                      <Check aria-hidden="true" size={14} strokeWidth={2.5} />
                    </span>
                    {item}
                  </li>
                ))}
              </ul>

              <div className="mt-8 inline-flex items-center gap-2 rounded-pill border border-white/10 bg-white/[0.05] px-3 py-2 text-xs font-medium text-ink-300">
                <Waypoints aria-hidden="true" className="text-brand-300" size={15} />
                {t("home.infrastructure.availability")}
              </div>
            </div>

            <figure className="relative" aria-describedby="infrastructure-map-caption">
              <div className="absolute inset-x-12 bottom-2 h-28 rounded-full bg-brand-500/20 blur-3xl" aria-hidden="true" />
              <div className="relative overflow-hidden rounded-[1.75rem] border border-white/10 bg-white/[0.035] px-3 pb-2 pt-5 shadow-dark backdrop-blur-sm sm:px-6 sm:pt-7">
                <div className="flex items-center gap-2 px-2">
                  <div className="flex items-center gap-2 text-xs font-semibold text-ink-300">
                    <Network aria-hidden="true" className="text-brand-300" size={16} />
                    {t("home.infrastructure.footprint")}
                  </div>
                </div>
                <img
                  src="/assets/datacenters.webp"
                  alt={t("home.infrastructure.imageAlt")}
                  width={1826}
                  height={614}
                  loading="lazy"
                  decoding="async"
                  className="mt-5 h-auto w-full object-contain opacity-85 saturate-[0.85]"
                />
              </div>
              <figcaption id="infrastructure-map-caption" className="mt-3 text-center font-reading text-xs leading-5 text-ink-400">
                {t("home.infrastructure.caption")}
              </figcaption>
            </figure>
          </div>
        </MarketingReveal>
      </section>

      <section className="bg-surface-canvas pb-16 pt-2 sm:pb-20">
        <MarketingReveal className="container-shell">
          <div className="relative overflow-hidden rounded-[2rem] bg-gradient-to-br from-brand-700 via-brand-800 to-surface-inverse px-6 py-14 text-white shadow-glow sm:px-12 sm:py-16 lg:px-16">
            <div className="absolute inset-0 opacity-[0.16] [background-image:linear-gradient(rgba(255,255,255,0.16)_1px,transparent_1px),linear-gradient(90deg,rgba(255,255,255,0.16)_1px,transparent_1px)] [background-size:56px_56px] [mask-image:linear-gradient(to_right,transparent,black,transparent)]" />
            <div className="absolute -left-24 -top-28 size-72 rounded-full border border-white/10" aria-hidden="true" />
            <div className="absolute -bottom-40 -right-20 size-80 rounded-full border border-white/10" aria-hidden="true" />

            <div className="relative grid items-end gap-10 lg:grid-cols-[1fr_auto]">
              <div className="max-w-3xl">
                <span className="inline-flex size-12 items-center justify-center rounded-2xl border border-white/15 bg-white/10 text-brand-200 backdrop-blur">
                  <Zap aria-hidden="true" size={22} />
                </span>
                <h2 className="mt-6 text-3xl font-semibold tracking-[-0.045em] sm:text-5xl">
                  {t("home.closing.title")}
                </h2>
                <p className="mt-5 max-w-2xl font-reading text-base leading-7 text-brand-100/80 sm:text-lg">
                  {t("home.closing.copy")}
                </p>
              </div>

              <div className="flex flex-col gap-3 sm:flex-row lg:flex-col">
                <Link to="/servers" className="btn-light min-w-48 px-6">
                  {t("actions.browseServers")}
                  <ArrowRight aria-hidden="true" className="directional-icon" size={17} />
                </Link>
                {isAuthenticated ? (
                  <Link to="/my-reservations" className="btn-outline-light min-w-48 px-6">
                    {t("home.closing.reservations")}
                  </Link>
                ) : (
                  <Link to="/register" className="btn-outline-light min-w-48 px-6">
                    {t("home.closing.createAccount")}
                  </Link>
                )}
              </div>
            </div>
          </div>
        </MarketingReveal>
      </section>
    </div>
  );
}
