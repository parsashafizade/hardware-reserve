import {
  CalendarCheck2,
  CheckCircle2,
  KeyRound,
  Network,
  ShieldCheck,
  type LucideIcon,
} from "lucide-react";
import type { ReactNode } from "react";
import { useTranslation } from "react-i18next";
import { IconTile } from "../ui/IconTile";

interface AuthShellProps {
  icon: LucideIcon;
  eyebrow: string;
  title: string;
  description: string;
  visualTitle: string;
  visualCopy: string;
  children: ReactNode;
}

export function AuthShell({
  icon,
  eyebrow,
  title,
  description,
  visualTitle,
  visualCopy,
  children,
}: AuthShellProps) {
  const { t } = useTranslation();
  const workflowPoints = [
    { icon: CalendarCheck2, label: t("auth.common.workflowPoints.conflictAware") },
    { icon: ShieldCheck, label: t("auth.common.workflowPoints.transparent") },
    { icon: KeyRound, label: t("auth.common.workflowPoints.linkedAccess") },
  ];

  return (
    <section className="mx-auto grid w-full max-w-[75rem] overflow-hidden rounded-[2rem] border border-border-subtle bg-white shadow-lift lg:grid-cols-[minmax(0,1.06fr)_minmax(28rem,0.94fr)]">
      <aside className="relative hidden min-h-[46rem] overflow-hidden bg-surface-inverse text-white lg:flex">
        {/* Photo by Brett Sayles via Pexels, used under the Pexels license. */}
        <img
          src="/assets/auth-datacenter.webp"
          alt={t("auth.common.visualAlt")}
          width={1200}
          height={800}
          loading="eager"
          decoding="async"
          className="auth-visual-media absolute inset-0 h-full w-full object-cover"
        />
        <div className="absolute inset-0 bg-[linear-gradient(180deg,rgba(7,17,31,0.26)_0%,rgba(7,17,31,0.58)_42%,rgba(7,17,31,0.98)_100%)]" />
        <div className="absolute inset-0 bg-[linear-gradient(90deg,rgba(7,17,31,0.2),rgba(7,17,31,0.72))]" />
        <div className="absolute inset-0 opacity-[0.15] [background-image:linear-gradient(rgba(148,163,184,0.18)_1px,transparent_1px),linear-gradient(90deg,rgba(148,163,184,0.18)_1px,transparent_1px)] [background-size:64px_64px] [mask-image:linear-gradient(to_bottom,black,transparent_78%)]" />

        <div className="relative flex w-full flex-col p-9 xl:p-12">
          <div className="inline-flex w-fit items-center gap-2 rounded-pill border border-white/15 bg-white/[0.08] px-3 py-1.5 text-xs font-semibold text-brand-100 backdrop-blur-md">
            <Network aria-hidden="true" size={15} />
            {t("auth.common.accessBadge")}
          </div>

          <div className="mt-auto max-w-xl">
            <span className="inline-flex items-center gap-2 text-xs font-bold uppercase tracking-[0.18em] text-brand-300">
              <span className="size-1.5 rounded-full bg-emerald-300 shadow-[0_0_12px_rgba(110,231,183,0.85)]" />
              {t("auth.common.connectedWorkspace")}
            </span>
            <h2 className="mt-4 text-4xl font-semibold leading-[1.08] tracking-[-0.045em] text-white xl:text-5xl">
              {visualTitle}
            </h2>
            <p className="mt-5 max-w-lg font-reading text-base leading-7 text-ink-300">{visualCopy}</p>

            <ul className="mt-8 grid gap-3">
              {workflowPoints.map(({ icon: Icon, label }) => (
                <li key={label} className="flex items-center gap-3 text-sm text-ink-200">
                  <span className="inline-flex size-8 items-center justify-center rounded-xl border border-white/10 bg-white/[0.07] text-brand-200">
                    <Icon aria-hidden="true" size={15} />
                  </span>
                  {label}
                </li>
              ))}
            </ul>

            <div className="mt-9 rounded-2xl border border-white/10 bg-white/[0.07] p-4 backdrop-blur-md">
              <div className="flex items-center justify-between gap-4">
                <div>
                  <p className="text-xs font-semibold text-white">{t("auth.common.workflowTitle")}</p>
                  <p className="mt-1 text-[11px] text-ink-400">{t("auth.common.workflowDescription")}</p>
                </div>
                <div className="flex -space-x-1.5" aria-hidden="true">
                  {[CalendarCheck2, ShieldCheck, KeyRound].map((Icon, index) => (
                    <span
                      key={index}
                      className="inline-flex size-8 items-center justify-center rounded-full border-2 border-surface-inverse bg-surface-inverse-raised text-brand-200"
                    >
                      <Icon size={13} />
                    </span>
                  ))}
                </div>
              </div>
            </div>
          </div>
        </div>
      </aside>

      <div className="relative flex min-w-0 flex-col bg-gradient-to-br from-white via-white to-brand-50/40 px-5 py-6 sm:px-9 sm:py-9 lg:px-11 lg:py-12 xl:px-14">
        <div className="relative mb-8 h-36 overflow-hidden rounded-2xl border border-brand-200/60 bg-surface-inverse shadow-card lg:hidden">
          <img
            src="/assets/auth-datacenter.webp"
            alt=""
            width={1200}
            height={800}
            loading="eager"
            decoding="async"
            className="h-full w-full object-cover object-center"
          />
          <div className="absolute inset-0 bg-gradient-to-r from-surface-inverse/95 via-surface-inverse/70 to-brand-900/25" />
          <div className="absolute inset-0 flex items-end p-5">
            <div>
              <p className="text-xs font-bold uppercase tracking-[0.16em] text-brand-300">HardwareReserve</p>
              <p className="mt-1 max-w-xs text-sm font-semibold text-white">{t("auth.common.mobileCaption")}</p>
            </div>
          </div>
        </div>

        <div className="mx-auto flex w-full max-w-[29rem] flex-1 flex-col justify-center">
          <div className="flex items-center gap-3">
            <IconTile icon={icon} />
            <p className="section-kicker">{eyebrow}</p>
          </div>
          <h1 className="mt-5 text-3xl font-semibold tracking-[-0.04em] text-ink-950 sm:text-4xl">{title}</h1>
          <p className="mt-3 font-reading text-sm leading-6 text-ink-600 sm:text-base">{description}</p>

          <div className="mt-8">{children}</div>

          <div className="mt-8 flex items-start gap-3 border-t border-border-subtle pt-6 text-xs leading-5 text-ink-500">
            <CheckCircle2 aria-hidden="true" className="mt-0.5 text-status-success" size={16} />
            <p className="font-reading">
              {t("auth.common.securityNote")}
            </p>
          </div>
        </div>
      </div>
    </section>
  );
}
