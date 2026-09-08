import assert from "node:assert/strict";
import test from "node:test";
import type { ReservationCockpit } from "../src/types/api.ts";
import { deriveReservationLifecycle } from "../src/utils/reservationLifecycle.ts";

const now = Date.parse("2026-08-20T10:00:00.000Z");

function reservation(overrides: Partial<ReservationCockpit> = {}): ReservationCockpit {
  return {
    reservationId: 1,
    startTime: "2026-08-20T12:00:00.000Z",
    endTime: "2026-08-20T16:00:00.000Z",
    totalPrice: 300_000,
    status: "Paid",
    paymentStatus: "Completed",
    serverTimeUtc: "2026-08-20T10:00:00.000Z",
    server: {
      serverId: 1,
      cpu: "AMD EPYC",
      gpu: "NVIDIA A100",
      ram: "64GB",
      storage: "2TB NVMe",
      os: "Ubuntu 24.04",
    },
    ...overrides,
  };
}

test("derives payment, upcoming, starting-soon, active, completed, and cancelled phases", () => {
  assert.equal(deriveReservationLifecycle(reservation({ status: "PendingPayment" }), now).phase, "awaitingPayment");
  assert.equal(deriveReservationLifecycle(reservation(), now).phase, "upcoming");
  assert.equal(deriveReservationLifecycle(reservation({ startTime: "2026-08-20T10:20:00.000Z" }), now).phase, "startingSoon");
  assert.equal(deriveReservationLifecycle(reservation({ startTime: "2026-08-20T09:00:00.000Z" }), now).phase, "active");
  assert.equal(deriveReservationLifecycle(reservation({ startTime: "2026-08-20T08:00:00.000Z", endTime: "2026-08-20T09:00:00.000Z" }), now).phase, "completed");
  assert.equal(deriveReservationLifecycle(reservation({ status: "Cancelled" }), now).phase, "cancelled");
});

test("countdown uses authoritative timestamps and switches target at the start boundary", () => {
  const beforeStart = deriveReservationLifecycle(
    reservation({ startTime: "2026-08-20T10:15:00.000Z", endTime: "2026-08-20T11:00:00.000Z" }),
    now,
  );
  assert.equal(beforeStart.countdownSeconds, 900);

  const atStart = deriveReservationLifecycle(
    reservation({ startTime: "2026-08-20T10:00:00.000Z", endTime: "2026-08-20T11:00:00.000Z" }),
    now,
  );
  assert.equal(atStart.phase, "active");
  assert.equal(atStart.countdownSeconds, 3_600);
});
