import assert from "node:assert/strict";
import test from "node:test";
import { normalizeCommandQuery, rankPaletteCommands } from "../src/utils/commandPalette.ts";

const commands = [
  { id: "servers", label: "Browse servers", keywords: ["سرورها", "hardware"], priority: 10 },
  { id: "reservations", label: "My Reservations", keywords: ["رزروهای من", "bookings"], priority: 5 },
  { id: "support", label: "Contact support", keywords: ["پشتیبانی", "help"], priority: 3 },
  { id: "active", label: "Open active service", keywords: ["سرویس فعال"], priority: 40 },
];

test("normalizes Persian Arabic character variants and spacing", () => {
  assert.equal(normalizeCommandQuery("  تغيير   ايميل  "), "تغییر ایمیل");
  assert.equal(normalizeCommandQuery("H100  SERVER"), "h100 server");
});

test("ranks exact and prefix matches ahead of keyword and fuzzy matches", () => {
  assert.equal(rankPaletteCommands(commands, "My Reservations")[0]?.id, "reservations");
  assert.equal(rankPaletteCommands(commands, "Browse")[0]?.id, "servers");
  assert.equal(rankPaletteCommands(commands, "hardware")[0]?.id, "servers");
  assert.equal(rankPaletteCommands(commands, "sprt")[0]?.id, "support");
});

test("supports Persian queries and context priority for the empty state", () => {
  assert.equal(rankPaletteCommands(commands, "پشتیبانی")[0]?.id, "support");
  assert.equal(rankPaletteCommands(commands, "رزروهای من")[0]?.id, "reservations");
  assert.equal(rankPaletteCommands(commands, "")[0]?.id, "active");
});

test("returns no command when the query is unrelated", () => {
  assert.deepEqual(rankPaletteCommands(commands, "unrelated phrase"), []);
});
