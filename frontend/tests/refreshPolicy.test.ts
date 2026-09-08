import assert from "node:assert/strict";
import test from "node:test";
import { AxiosError } from "axios";
import { shouldInvalidateSessionAfterRefreshFailure } from "../src/auth/refreshPolicy.ts";

function axiosFailure(status?: number): AxiosError {
  return new AxiosError(
    "refresh failed",
    status ? AxiosError.ERR_BAD_REQUEST : AxiosError.ERR_NETWORK,
    undefined,
    undefined,
    status
      ? {
          data: {},
          status,
          statusText: String(status),
          headers: {},
          config: { headers: {} },
        }
      : undefined,
  );
}

test("invalidates a session only after an authoritative refresh rejection", () => {
  assert.equal(shouldInvalidateSessionAfterRefreshFailure(axiosFailure(400)), true);
  assert.equal(shouldInvalidateSessionAfterRefreshFailure(axiosFailure(401)), true);
  assert.equal(shouldInvalidateSessionAfterRefreshFailure(axiosFailure(403)), true);
});

test("preserves a session across connectivity, throttling, and server failures", () => {
  assert.equal(shouldInvalidateSessionAfterRefreshFailure(axiosFailure()), false);
  assert.equal(shouldInvalidateSessionAfterRefreshFailure(axiosFailure(429)), false);
  assert.equal(shouldInvalidateSessionAfterRefreshFailure(axiosFailure(500)), false);
  assert.equal(shouldInvalidateSessionAfterRefreshFailure(new Error("offline")), false);
});
