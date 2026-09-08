import { StatusBadge } from "../ui/StatusBadge";
import { useTranslation } from "react-i18next";

type StatusTone = "neutral" | "brand" | "success" | "warning" | "danger" | "info";

interface AccountStatusBadgeProps {
  status: string;
}

interface StatusPresentation {
  label: string;
  tone: StatusTone;
}

function normalizeStatus(status: string): string {
  return status.replace(/[\s_-]/g, "").toLowerCase();
}

function humanizeStatus(status: string): string {
  return status
    .replace(/([a-z])([A-Z])/g, "$1 $2")
    .replace(/[_-]/g, " ")
    .replace(/^./, (character) => character.toUpperCase());
}

function reservationPresentation(status: string, translate: (key: string) => string): StatusPresentation {
  switch (normalizeStatus(status)) {
    case "pendingpayment":
      return { label: translate("status.reservation.pendingPayment"), tone: "warning" };
    case "paid":
      return { label: translate("status.reservation.paid"), tone: "success" };
    case "cancelled":
      return { label: translate("status.reservation.cancelled"), tone: "neutral" };
    default:
      return { label: humanizeStatus(status), tone: "info" };
  }
}

function paymentPresentation(status: string, translate: (key: string) => string): StatusPresentation {
  switch (normalizeStatus(status)) {
    case "completed":
      return { label: translate("status.payment.completed"), tone: "success" };
    case "pending":
      return { label: translate("status.payment.pending"), tone: "warning" };
    case "failed":
      return { label: translate("status.payment.failed"), tone: "danger" };
    case "refunded":
      return { label: translate("status.payment.refunded"), tone: "info" };
    case "unpaid":
      return { label: translate("status.payment.unpaid"), tone: "neutral" };
    default:
      return { label: humanizeStatus(status), tone: "neutral" };
  }
}

export function ReservationStatusBadge({ status }: AccountStatusBadgeProps) {
  const { t } = useTranslation();
  const presentation = reservationPresentation(status, t);
  return (
    <StatusBadge tone={presentation.tone} showDot>
      {presentation.label}
    </StatusBadge>
  );
}

export function PaymentStatusBadge({ status }: AccountStatusBadgeProps) {
  const { t } = useTranslation();
  const presentation = paymentPresentation(status, t);
  return (
    <StatusBadge tone={presentation.tone}>
      {presentation.label}
    </StatusBadge>
  );
}
