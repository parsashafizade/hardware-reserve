import assert from "node:assert/strict";
import test from "node:test";
import { getAuthenticatedDestination } from "../src/auth/destinations.ts";
import { getAdminActionBadgeLabel } from "../src/utils/adminActionBadges.ts";
import { validateAdminCreation } from "../src/utils/adminCreation.ts";
import type { AuthenticatedUser } from "../src/types/api.ts";

const admin: AuthenticatedUser = { id: 1, fullName: "Admin", email: "admin@test.local", role: "Admin" };
const user: AuthenticatedUser = { id: 2, fullName: "User", email: "user@test.local", role: "User" };

test("role-aware destinations keep Admins in the Admin experience", () => {
  assert.equal(getAuthenticatedDestination(admin), "/admin");
  assert.equal(getAuthenticatedDestination(admin, "/my-reservations"), "/admin");
  assert.equal(getAuthenticatedDestination(admin, "/admin/support"), "/admin/support");
  assert.equal(getAuthenticatedDestination(user), "/profile");
  assert.equal(getAuthenticatedDestination(user, "/my-services"), "/my-services");
  assert.equal(getAuthenticatedDestination(user, "/admin"), "/profile");
  assert.equal(getAuthenticatedDestination(user, "//outside.example"), "/profile");
});

test("action badges render only authoritative positive counts", () => {
  assert.equal(getAdminActionBadgeLabel(3), "3");
  assert.equal(getAdminActionBadgeLabel(0), null);
  assert.equal(getAdminActionBadgeLabel(-1), null);
  assert.equal(getAdminActionBadgeLabel(12, (value) => `localized-${value}`), "localized-12");
});

test("Admin creation client validation enforces confirmation and shared password length", () => {
  assert.equal(validateAdminCreation({ fullName: "", email: "a@test.local", password: "12345678", confirmPassword: "12345678" }), "required");
  assert.equal(validateAdminCreation({ fullName: "Admin", email: "a@test.local", password: "short", confirmPassword: "short" }), "passwordPolicy");
  assert.equal(validateAdminCreation({ fullName: "Admin", email: "a@test.local", password: "12345678", confirmPassword: "87654321" }), "passwordMismatch");
  assert.equal(validateAdminCreation({ fullName: "Admin", email: "a@test.local", password: "12345678", confirmPassword: "12345678" }), null);
});
