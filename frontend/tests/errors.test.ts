import assert from "node:assert/strict";
import test from "node:test";
import { AxiosError } from "axios";
import i18n from "../src/i18n/config.ts";
import { getApiErrorMessage } from "../src/utils/errors.ts";

function apiError(code: string, status: number): AxiosError {
  return new AxiosError("request failed", AxiosError.ERR_BAD_RESPONSE, undefined, undefined, {
    data: { code, message: "Server fallback must not leak through localized codes." },
    status,
    statusText: String(status),
    headers: {},
    config: { headers: {} },
  });
}

test("localizes stable authentication and authorization error codes", async () => {
  await i18n.changeLanguage("en");
  assert.equal(
    getApiErrorMessage(apiError("AUTHENTICATION_REQUIRED", 401)),
    "Sign in again to continue.",
  );
  assert.equal(
    getApiErrorMessage(apiError("FORBIDDEN", 403)),
    "You do not have permission to perform this action.",
  );

  await i18n.changeLanguage("fa");
  assert.equal(
    getApiErrorMessage(apiError("AUTHENTICATION_REQUIRED", 401)),
    "برای ادامه، دوباره وارد شوید.",
  );
  assert.equal(
    getApiErrorMessage(apiError("FORBIDDEN", 403)),
    "اجازه انجام این عملیات را ندارید.",
  );
});
