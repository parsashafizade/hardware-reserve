import { useEffect, useRef, useState } from "react";
import {
  AlertCircle,
  ArrowLeft,
  CheckCircle2,
  Clock3,
  CreditCard,
  LoaderCircle,
  ReceiptText,
  RotateCcw,
  ShieldCheck,
} from "lucide-react";
import { Link, useNavigate, useParams } from "react-router-dom";
import { useTranslation } from "react-i18next";
import { paymentsApi } from "../api/paymentsApi";
import { reservationsApi } from "../api/reservationsApi";
import { PaymentStatusBadge, ReservationStatusBadge } from "../components/account/AccountStatusBadges";
import { ServerSpecGrid } from "../components/server/ServerSpecGrid";
import { PageHeader } from "../components/ui/PageHeader";
import type { MyReservation, PaymentResult } from "../types/api";
import { getApiErrorMessage } from "../utils/errors";
import { formatCurrency, formatDateTime, formatDuration } from "../utils/format";
import { useLocale } from "../i18n/useLocale";

function normalizeStatus(status: string): string {
  return status.replace(/[\s_-]/g, "").toLowerCase();
}

function CheckoutSkeleton({ label }: { label: string }) {
  return (
    <div className="page-stack" role="status" aria-label={label}>
      <div className="space-y-3">
        <div className="skeleton h-4 w-28" />
        <div className="skeleton h-11 w-full max-w-md" />
        <div className="skeleton h-5 w-full max-w-2xl" />
      </div>
      <div className="grid gap-6 lg:grid-cols-[minmax(0,1fr)_23rem]">
        <div className="skeleton h-[30rem] rounded-card" />
        <div className="skeleton h-[28rem] rounded-panel" />
      </div>
    </div>
  );
}

export function CheckoutPage() {
  const { t } = useTranslation();
  const { formatNumber } = useLocale();
  const { reservationId } = useParams();
  const navigate = useNavigate();
  const redirectTimer = useRef<number | null>(null);

  const [reservation, setReservation] = useState<MyReservation | null>(null);
  const [payment, setPayment] = useState<PaymentResult | null>(null);
  const [loading, setLoading] = useState(true);
  const [paying, setPaying] = useState(false);
  const [error, setError] = useState("");
  const [requestVersion, setRequestVersion] = useState(0);

  useEffect(() => {
    let cancelled = false;

    const loadReservation = async () => {
      if (!reservationId || !Number.isFinite(Number(reservationId))) {
        if (!cancelled) {
          setReservation(null);
          setError(t("checkout.invalidId"));
          setLoading(false);
        }
        return;
      }

      setLoading(true);
      setError("");

      try {
        const response = await reservationsApi.getReservationById(Number(reservationId));
        if (!cancelled) {
          setReservation(response);
        }
      } catch (loadError) {
        if (!cancelled) {
          setReservation(null);
          setError(getApiErrorMessage(loadError, t("checkout.loadError")));
        }
      } finally {
        if (!cancelled) {
          setLoading(false);
        }
      }
    };

    void loadReservation();
    return () => {
      cancelled = true;
    };
  }, [requestVersion, reservationId, t]);

  useEffect(() => () => {
    if (redirectTimer.current !== null) {
      window.clearTimeout(redirectTimer.current);
    }
  }, []);

  const payNow = async () => {
    if (!reservationId || !reservation || normalizeStatus(reservation.status) !== "pendingpayment") {
      return;
    }

    setPaying(true);
    setError("");

    try {
      const response = await paymentsApi.payReservation(Number(reservationId));
      setPayment(response);
      redirectTimer.current = window.setTimeout(() => {
        navigate(`/my-reservations/${reservationId}`, { replace: true });
      }, 900);
    } catch (paymentError) {
      setError(getApiErrorMessage(paymentError, t("checkout.paymentError")));
    } finally {
      setPaying(false);
    }
  };

  if (loading) {
    return <CheckoutSkeleton label={t("checkout.loading")} />;
  }

  if (!reservation) {
    return (
      <div className="state-panel" role="alert">
        <span className="icon-tile-neutral"><AlertCircle aria-hidden="true" size={21} /></span>
        <h1 className="mt-4 card-title">{t("checkout.unavailableTitle")}</h1>
        <p className="mt-2 max-w-md body-copy">{error || t("checkout.loadError")}</p>
        <div className="mt-5 flex flex-col gap-2 sm:flex-row">
          <button type="button" className="btn-primary" onClick={() => setRequestVersion((version) => version + 1)}>
            <RotateCcw aria-hidden="true" size={16} />
            {t("actions.retry")}
          </button>
          <Link to="/my-reservations" className="btn-secondary">
            <ArrowLeft aria-hidden="true" className="directional-icon" size={16} />
            {t("checkout.backToReservations")}
          </Link>
        </div>
      </div>
    );
  }

  const pendingPayment = normalizeStatus(reservation.status) === "pendingpayment";

  return (
    <div className="page-stack">
      <PageHeader
        eyebrow={t("checkout.eyebrow")}
        title={t("checkout.title")}
        description={t("checkout.description")}
        icon={CreditCard}
        actions={
          <Link to="/my-reservations" className="btn-secondary">
            <ArrowLeft aria-hidden="true" className="directional-icon" size={16} />
            {t("checkout.backToReservations")}
          </Link>
        }
      />

      <div className="grid items-start gap-6 lg:grid-cols-[minmax(0,1fr)_23rem]">
        <section className="card" aria-labelledby="checkout-configuration-title">
          <div className="flex flex-col gap-4 border-b border-border-subtle pb-5 sm:flex-row sm:items-start sm:justify-between">
            <div>
              <p className="section-kicker">{t("checkout.reservationNumber", { id: formatNumber(reservation.reservationId) })}</p>
              <h2 id="checkout-configuration-title" className="mt-1 card-title">{t("checkout.configuration")}</h2>
              <p className="mt-1 text-sm leading-6 text-ink-500">{t("checkout.configurationCopy")}</p>
            </div>
            <div className="flex flex-wrap gap-2">
              <ReservationStatusBadge status={reservation.status} />
              <PaymentStatusBadge status={reservation.paymentStatus} />
            </div>
          </div>

          <ServerSpecGrid server={reservation.server} className="mt-5" />

          <section className="mt-5 rounded-control border border-border-subtle bg-surface-muted/55 p-4 sm:p-5" aria-labelledby="checkout-window-title">
            <div className="flex items-center gap-2">
              <Clock3 aria-hidden="true" className="text-brand-700" size={17} />
              <h3 id="checkout-window-title" className="text-sm font-semibold text-ink-900">{t("checkout.window")}</h3>
            </div>
            <dl className="mt-4 grid gap-4 sm:grid-cols-3">
              <div>
                <dt className="meta-text">{t("checkout.starts")}</dt>
                <dd className="mt-1 text-sm font-semibold text-ink-900">{formatDateTime(reservation.startTime)}</dd>
              </div>
              <div>
                <dt className="meta-text">{t("checkout.ends")}</dt>
                <dd className="mt-1 text-sm font-semibold text-ink-900">{formatDateTime(reservation.endTime)}</dd>
              </div>
              <div>
                <dt className="meta-text">{t("checkout.duration")}</dt>
                <dd className="mt-1 text-sm font-semibold text-ink-900">{formatDuration(reservation.startTime, reservation.endTime)}</dd>
              </div>
            </dl>
          </section>
        </section>

        <aside className="card-inverse p-6 lg:sticky lg:top-28" aria-labelledby="payment-summary-title">
          <div aria-hidden="true" className="absolute -right-16 -top-16 size-48 rounded-full bg-brand-400/15 blur-3xl" />
          <div className="relative">
            <div className="flex items-start justify-between gap-3">
              <div>
                <p className="text-xs font-bold uppercase tracking-[0.16em] text-brand-200">{t("checkout.paymentSummary")}</p>
                <h2 id="payment-summary-title" className="mt-1 text-lg font-semibold text-white">{t("checkout.reservationTotal")}</h2>
              </div>
              <span className="icon-tile-inverse size-10"><ReceiptText aria-hidden="true" size={18} /></span>
            </div>

            <p dir="auto" className="bidi-auto mt-7 text-4xl font-semibold tracking-[-0.05em] text-white">{formatCurrency(reservation.totalPrice)}</p>
            <p className="mt-3 text-xs leading-5 text-ink-400">{t("checkout.amountNote")}</p>

            <div className="my-6 border-t border-white/10" />

            {payment ? (
              <div className="rounded-control border border-emerald-300/20 bg-emerald-300/10 p-4" role="status" aria-live="polite">
                <div className="flex items-start gap-3">
                  <CheckCircle2 aria-hidden="true" className="mt-0.5 text-emerald-200" size={19} />
                  <div>
                    <p className="text-sm font-semibold text-white">{t("checkout.completed")}</p>
                    <p className="mt-1 text-xs leading-5 text-ink-300">{formatCurrency(payment.amount)} · {t("checkout.paidOn", { date: formatDateTime(payment.paymentDate) })}</p>
                    <p className="mt-2 text-xs font-semibold text-emerald-200">{t("checkout.redirecting")}</p>
                  </div>
                </div>
              </div>
            ) : (
              <>
                {!pendingPayment && (
                  <div className="rounded-control border border-amber-300/20 bg-amber-300/10 p-4 text-xs leading-5 text-amber-100">
                    {t("checkout.unavailableState")}
                  </div>
                )}

                {error && (
                  <div className="mt-4 rounded-control border border-rose-300/20 bg-rose-300/10 p-4 text-xs leading-5 text-rose-100" role="alert">
                    {error}
                  </div>
                )}

                <button type="button" onClick={() => void payNow()} className="btn-light mt-5 w-full" disabled={paying || !pendingPayment}>
                  {paying ? <LoaderCircle aria-hidden="true" className="animate-spin" size={17} /> : <ShieldCheck aria-hidden="true" size={17} />}
                  {paying ? t("checkout.paying") : t("checkout.pay")}
                </button>
                <p className="mt-3 text-center text-xs leading-5 text-ink-500">{t("checkout.universityNote")}</p>
              </>
            )}
          </div>
        </aside>
      </div>
    </div>
  );
}
