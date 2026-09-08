import { isAxiosError } from "axios";

/**
 * Only an authoritative client/authentication rejection invalidates the
 * persisted session. Connectivity, timeout, throttling, and server failures
 * leave the rotated refresh token available for a later retry.
 */
export function shouldInvalidateSessionAfterRefreshFailure(error: unknown): boolean {
  if (!isAxiosError(error)) {
    return false;
  }

  const status = error.response?.status;
  return status === 400 || status === 401 || status === 403;
}
