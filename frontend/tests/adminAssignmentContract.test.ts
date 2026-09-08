import assert from "node:assert/strict";
import test from "node:test";
import { ADMIN_ASSIGNMENT_FILTERS, type AdminReservationDetail } from "../src/types/api.ts";
import type { UserNotification } from "../src/types/notifications.ts";

test("Admin assignment filters use the backend wire values", () => {
  assert.deepEqual(ADMIN_ASSIGNMENT_FILTERS, ["All", "NeedsAssignment", "Assigned"]);
});

test("protected detail and assignment notification keep the shared deep-link contract", () => {
  const detail = {
    credentialsAssigned: true,
    assignmentStatus: "Assigned",
    assignedIp: "203.0.113.10",
    assignedUsername: "operator",
    assignedPassword: "secret",
  } as AdminReservationDetail;
  const notification: UserNotification = {
    id: "e3dd3771-45b1-49a2-b735-59331c0ec4dd",
    type: "ServiceDetailsAssigned",
    source: "System",
    reservationId: 42,
    createdAt: "2026-08-23T08:30:00Z",
  };

  assert.equal(detail.assignmentStatus, "Assigned");
  assert.equal(detail.assignedPassword, "secret");
  assert.equal(notification.reservationId, 42);
});
