import assert from "node:assert/strict";
import { readdirSync, readFileSync } from "node:fs";
import test from "node:test";
import { fileURLToPath } from "node:url";
import { resources } from "../src/i18n/resources.ts";

type TranslationMap = Map<string, string>;

function flattenTranslations(
  value: object,
  prefix = "",
  output: TranslationMap = new Map(),
): TranslationMap {
  for (const [name, entry] of Object.entries(value)) {
    const key = prefix ? `${prefix}.${name}` : name;
    if (entry && typeof entry === "object") {
      flattenTranslations(entry, key, output);
    } else {
      output.set(key, String(entry));
    }
  }
  return output;
}

function semanticKey(key: string): string {
  return key.replace(/_(zero|one|two|few|many|other)$/u, "");
}

function semanticKeys(translations: TranslationMap): Set<string> {
  return new Set([...translations.keys()].map(semanticKey));
}

function placeholders(value: string): string[] {
  return [...value.matchAll(/\{\{\s*([^},\s]+)[^}]*\}\}/gu)]
    .map((match) => match[1])
    .sort();
}

function placeholderContracts(translations: TranslationMap): Map<string, string> {
  const contracts = new Map<string, Set<string>>();
  for (const [key, value] of translations) {
    const base = semanticKey(key);
    const variants = contracts.get(base) ?? new Set<string>();
    variants.add(placeholders(value).join(","));
    contracts.set(base, variants);
  }
  return new Map([...contracts].map(([key, variants]) => [key, [...variants].sort().join("|")]));
}

function sourceFiles(directory: string): string[] {
  return readdirSync(directory, { withFileTypes: true }).flatMap((entry) => {
    const path = `${directory}/${entry.name}`;
    return entry.isDirectory() ? sourceFiles(path) : [path];
  });
}

const fa = flattenTranslations(resources.fa.translation);
const en = flattenTranslations(resources.en.translation);

test("Persian and English translation catalogs have semantic key and placeholder parity", () => {
  assert.deepEqual([...semanticKeys(fa)].sort(), [...semanticKeys(en)].sort());
  assert.deepEqual([...placeholderContracts(fa)], [...placeholderContracts(en)]);
});

test("every statically referenced translation exists in both locales", () => {
  const sourceRoot = fileURLToPath(new URL("../src", import.meta.url));
  const calls = /(?:\bt|i18n\.t)\(\s*(["'`])([^"'`]+)\1/gu;
  const missing: string[] = [];

  for (const path of sourceFiles(sourceRoot).filter((file) => /\.(ts|tsx)$/u.test(file))) {
    const source = readFileSync(path, "utf8");
    for (const match of source.matchAll(calls)) {
      const key = match[2];
      if (key.includes("${")) {
        continue;
      }
      if (!semanticKeys(fa).has(key) || !semanticKeys(en).has(key)) {
        missing.push(`${path.replace(`${sourceRoot}/`, "")}: ${key}`);
      }
    }
  }

  assert.deepEqual(missing, []);
});

test("backend-driven enum translation contracts stay complete", () => {
  const requiredKeys = [
    ...["weak", "medium", "strong"].map((value) => `auth.common.passwordStrength.${value}`),
    ...["all", "gpu", "cpu"].map((value) => `catalog.compute.${value}`),
    ...["light", "moderate", "heavy"].map((value) => `catalog.finder.intensity.${value}`),
    ...["automatic", "required", "notNeeded"].map((value) => `catalog.finder.gpu.${value}`),
    ...["value", "balanced", "performance"].map((value) => `catalog.finder.priority.${value}`),
    ...["Entry", "Standard", "High", "Extreme"].map((value) => `admin.servers.tiers.${value}`),
    ...["Available", "TemporarilyUnavailable", "Maintenance", "Disabled"].map((value) => `admin.servers.statuses.${value}`),
    ...["ModelTraining", "Inference", "Rendering", "DevelopmentCompilation", "DataProcessing", "WebBackendHosting", "GeneralCompute"].map((value) => `admin.servers.workloads.${value}`),
    ...["PendingPayment", "Active", "Upcoming", "Completed", "Cancelled"].map((value) => `admin.orders.filtersStatus.${value}`),
    ...["ReservationCreated", "PaymentConfirmed", "ReservationStartsSoon", "ReservationStarted", "ReservationEndsSoon", "ReservationCompleted", "ServiceDetailsAssigned", "SupportReply", "AdminMessage", "ReservationCancelled"].map((value) => `notifications.items.${value}`),
    "support.status.aiActive",
    "support.status.waitingForAdmin",
    "support.status.adminActive",
    "support.status.resolved",
    "support.status.closed",
  ];

  for (const key of requiredKeys) {
    assert.ok(fa.has(key), `Missing Persian translation: ${key}`);
    assert.ok(en.has(key), `Missing English translation: ${key}`);
  }
});
