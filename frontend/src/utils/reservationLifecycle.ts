import type { ReservationCockpit } from "../types/api";

export type ReservationLifecyclePhase =
  | "awaitingPayment"
  | "upcoming"
  | "startingSoon"
  | "active"
  | "completed"
  | "cancelled";

export interface ReservationLifecycle {
  phase: ReservationLifecyclePhase;
  countdownSeconds: number | null;
  currentStep: number;
}

function normalizeStatus(status: string): string {
  return status.replace(/[\s_-]/g, "").toLowerCase();
}

export function deriveReservationLifecycle(
  reservation: ReservationCockpit,
  nowUtcMilliseconds: number,
): ReservationLifecycle {
  const status = normalizeStatus(reservation.status);
  const start = new Date(reservation.startTime).getTime();
  const end = new Date(reservation.endTime).getTime();

  if (status === "cancelled") {
    return { phase: "cancelled", countdownSeconds: null, currentStep: 0 };
  }
  if (status === "pendingpayment") {
    return { phase: "awaitingPayment", countdownSeconds: null, currentStep: 1 };
  }
  if (nowUtcMilliseconds < start) {
    const seconds = Math.max(0, Math.ceil((start - nowUtcMilliseconds) / 1_000));
    return {
      phase: seconds <= 30 * 60 ? "startingSoon" : "upcoming",
      countdownSeconds: seconds,
      currentStep: 2,
    };
  }
  if (nowUtcMilliseconds < end) {
    return {
      phase: "active",
      countdownSeconds: Math.max(0, Math.ceil((end - nowUtcMilliseconds) / 1_000)),
      currentStep: 3,
    };
  }
  return { phase: "completed", countdownSeconds: null, currentStep: 4 };
}
