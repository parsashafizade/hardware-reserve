import { ArrowRight, Home, SearchX } from "lucide-react";
import { useTranslation } from "react-i18next";
import { Link } from "react-router-dom";

export function NotFoundPage() {
  const { t } = useTranslation();
  return (
    <div className="mx-auto max-w-3xl py-8 sm:py-16">
      <div className="state-panel min-h-[26rem] overflow-hidden bg-white shadow-card">
        <div className="relative">
          <span className="icon-tile size-14"><SearchX aria-hidden="true" size={24} /></span>
          <span className="absolute -right-8 -top-7 text-7xl font-semibold tracking-[-0.08em] text-brand-100" aria-hidden="true">404</span>
        </div>
        <p className="section-kicker mt-8">{t("notFound.eyebrow")}</p>
        <h1 className="mt-2 text-3xl font-semibold tracking-[-0.04em] text-ink-950 sm:text-4xl">{t("notFound.title")}</h1>
        <p className="mt-4 max-w-lg body-copy">{t("notFound.description")}</p>
        <div className="mt-7 flex w-full max-w-md flex-col gap-2 sm:flex-row sm:justify-center">
          <Link to="/" className="btn-primary">
            <Home aria-hidden="true" size={17} />
            {t("notFound.home")}
          </Link>
          <Link to="/servers" className="btn-secondary">
            {t("notFound.servers")}
            <ArrowRight aria-hidden="true" className="directional-icon" size={16} />
          </Link>
        </div>
      </div>
    </div>
  );
}
