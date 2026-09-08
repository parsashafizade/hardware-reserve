import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";
import { formatLocalizedDate, IRAN_TIME_ZONE } from "../src/i18n/dateTime";
import { adminEn } from "../src/i18n/translations/admin";
import { getActivityDateGroup } from "../src/utils/activityDate";
import {
  buildAdminNotificationRecipients,
  mergeSelectedRecipients,
  removeSelectedRecipient,
} from "../src/utils/adminNotificationRecipients";
import type { AdminNotificationRecipient } from "../src/types/api";

const numericDate = { year: "numeric", month: "numeric", day: "numeric", timeZone: "UTC" } as const;

test("Persian dates use Jalali while English uses Gregorian for the same UTC instant", () => {
  const instant = "2026-03-21T00:00:00Z";
  assert.equal(formatLocalizedDate(instant, "fa", numericDate), "۱۴۰۵/۱/۱");
  assert.equal(formatLocalizedDate(instant, "en", numericDate), "3/21/2026");
});

test("Jalali leap-day and new-year boundaries remain correct", () => {
  assert.equal(formatLocalizedDate("2025-03-20T12:00:00Z", "fa", numericDate), "۱۴۰۳/۱۲/۳۰");
  assert.equal(formatLocalizedDate("2025-03-21T12:00:00Z", "fa", numericDate), "۱۴۰۴/۱/۱");
  assert.equal(formatLocalizedDate("2025-12-31T12:00:00Z", "en", numericDate), "12/31/2025");
  assert.equal(formatLocalizedDate("2026-01-01T12:00:00Z", "en", numericDate), "1/1/2026");
});

test("UTC instants are converted to the requested presentation timezone before calendar formatting", () => {
  const beforeTehranMidnight = "2026-03-20T19:00:00Z";
  const afterTehranMidnight = "2026-03-20T21:00:00Z";
  const tehranOptions = { ...numericDate, timeZone: "Asia/Tehran" };
  assert.equal(formatLocalizedDate(beforeTehranMidnight, "fa", tehranOptions), "۱۴۰۴/۱۲/۲۹");
  assert.equal(formatLocalizedDate(afterTehranMidnight, "fa", tehranOptions), "۱۴۰۵/۱/۱");
});

test("reservation timestamps use Persian Jalali presentation in Iran time", () => {
  const instant = "2026-08-23T12:30:00Z";
  const options = { dateStyle: "short", timeStyle: "short", timeZone: IRAN_TIME_ZONE } as const;

  assert.equal(formatLocalizedDate(instant, "fa", options), "۱۴۰۵/۶/۱, ۱۶:۰۰");
  assert.equal(formatLocalizedDate(instant, "en", options), "8/23/26, 4:00 PM");
});

test("reservation selected and suggested times share the Tehran formatter without changing the native value contract", async () => {
  const source = await readFile(new URL("../src/pages/ReservePage.tsx", import.meta.url), "utf8");

  assert.match(source, /label: formatReservationDateTime\(start\)/);
  assert.match(source, /selectedHourlyStart = hourlyStart\s*\? formatReservationDateTime/);
  assert.match(source, /formatReservationDateTime\(suggestion\.suggestedStart\)/);
  assert.match(source, /type="datetime-local"[\s\S]*?value=\{hourlyStart\}/);
  assert.match(source, /startTime: reservationPreview\.start\.toISOString\(\)/);
  assert.match(source, /useCurrentTime\(60_000\)/);
});

test("today grouping recomputes across a local midnight", () => {
  const notification = new Date(2026, 7, 23, 23, 55);
  assert.equal(getActivityDateGroup(notification, new Date(2026, 7, 23, 23, 59).getTime()), "today");
  assert.equal(getActivityDateGroup(notification, new Date(2026, 7, 24, 0, 1).getTime()), "yesterday");
});

test("recipient selection persists across searches, deduplicates IDs, and never turns empty targeted sends into broadcast", () => {
  const userA: AdminNotificationRecipient = { id: 3, fullName: "کاربر الف", email: "a@example.test" };
  const userB: AdminNotificationRecipient = { id: 1, fullName: "User B", email: "b@example.test" };
  const userC: AdminNotificationRecipient = { id: 2, fullName: "User C", email: "c@example.test" };

  let selected = mergeSelectedRecipients(new Map(), [userA]);
  selected = mergeSelectedRecipients(selected, [userB, userC, userA]);
  assert.deepEqual([...selected.keys()], [3, 1, 2]);
  assert.deepEqual(buildAdminNotificationRecipients("SelectedUsers", selected), {
    recipientScope: "SelectedUsers",
    userIds: [1, 2, 3],
    confirmBroadcast: false,
  });

  selected = removeSelectedRecipient(selected, userB.id);
  assert.equal(selected.has(userB.id), false);
  assert.deepEqual(buildAdminNotificationRecipients("SelectedUsers", new Map()), {
    recipientScope: "SelectedUsers",
    userIds: [],
    confirmBroadcast: false,
  });
  assert.deepEqual(buildAdminNotificationRecipients("AllUsers", selected), {
    recipientScope: "AllUsers",
    confirmBroadcast: true,
  });
});

test("single selected recipients use grammatical English labels", async () => {
  assert.equal(adminEn.admin.notifications.selectedCountOne, "1 user selected");
  assert.equal(adminEn.admin.notifications.selectedRecipientsHistoryOne, "1 selected user");

  const source = await readFile(new URL("../src/pages/AdminNotificationsPage.tsx", import.meta.url), "utf8");
  assert.match(source, /selectedRecipients\.size === 1/);
  assert.match(source, /campaign\.targetCount === 1/);
});

test("Web server filters retain their controls without a sticky dock", async () => {
  const source = await readFile(new URL("../src/pages/ServersPage.tsx", import.meta.url), "utf8");
  assert.doesNotMatch(source, /catalog-filter-dock|lg:sticky/);
  for (const behavior of ["setSearch", "setSort", "updateFilter", "clearFilters", "filtersOpen"]) {
    assert.match(source, new RegExp(behavior));
  }
});
