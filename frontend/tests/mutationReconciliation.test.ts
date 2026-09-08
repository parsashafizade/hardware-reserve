import assert from "node:assert/strict";
import test from "node:test";
import { AxiosError } from "axios";
import type { SupportQuickReply, UpsertSupportQuickReplyRequest } from "../src/types/support.ts";
import {
  isAmbiguousMutationFailure,
  reconcileCreatedQuickReply,
} from "../src/utils/mutationReconciliation.ts";

const request: UpsertSupportQuickReplyRequest = {
  title: " Connection check ",
  content: "Please share the reservation ID.",
  category: "Provisioning",
  isActive: true,
  sortOrder: 20,
};

function reply(id: string, overrides: Partial<SupportQuickReply> = {}): SupportQuickReply {
  return {
    id,
    title: "Connection check",
    content: "Please share the reservation ID.",
    category: "Provisioning",
    isActive: true,
    sortOrder: 20,
    createdAt: "2026-08-22T10:00:00Z",
    updatedAt: "2026-08-22T10:00:00Z",
    ...overrides,
  };
}

test("reconciles exactly one new normalized quick reply and ignores baseline duplicates", () => {
  const baselineIds = new Set(["existing"]);
  assert.equal(
    reconcileCreatedQuickReply(baselineIds, request, [reply("existing"), reply("created")])?.id,
    "created",
  );
});

test("does not guess when no new exact match or multiple matches exist", () => {
  const baselineIds = new Set(["existing"]);
  assert.equal(reconcileCreatedQuickReply(baselineIds, request, [reply("existing")]), null);
  assert.equal(
    reconcileCreatedQuickReply(baselineIds, request, [reply("one"), reply("two")]),
    null,
  );
  assert.equal(
    reconcileCreatedQuickReply(baselineIds, request, [reply("created", { sortOrder: 21 })]),
    null,
  );
});

test("only transport and server failures are mutation-ambiguous", () => {
  const network = new AxiosError("offline", AxiosError.ERR_NETWORK);
  const validation = new AxiosError("invalid", AxiosError.ERR_BAD_REQUEST, undefined, undefined, {
    data: {},
    status: 400,
    statusText: "400",
    headers: {},
    config: { headers: {} },
  });
  const server = new AxiosError("server", AxiosError.ERR_BAD_RESPONSE, undefined, undefined, {
    data: {},
    status: 503,
    statusText: "503",
    headers: {},
    config: { headers: {} },
  });

  assert.equal(isAmbiguousMutationFailure(network), true);
  assert.equal(isAmbiguousMutationFailure(server), true);
  assert.equal(isAmbiguousMutationFailure(validation), false);
  assert.equal(isAmbiguousMutationFailure(new Error("local validation")), false);
});
