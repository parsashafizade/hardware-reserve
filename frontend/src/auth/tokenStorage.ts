import type { AuthResponse } from "../types/api";

const AUTH_STORAGE_KEY = "hardware_reserve_auth";
const AUTH_STORAGE_EVENT = "hardware_reserve_auth_updated";

function notifyAuthStorageUpdated(): void {
  window.dispatchEvent(new Event(AUTH_STORAGE_EVENT));
}

export function getStoredSession(): AuthResponse | null {
  const raw = localStorage.getItem(AUTH_STORAGE_KEY);
  if (!raw) {
    return null;
  }

  try {
    return JSON.parse(raw) as AuthResponse;
  } catch {
    localStorage.removeItem(AUTH_STORAGE_KEY);
    return null;
  }
}

export function setStoredSession(session: AuthResponse): void {
  localStorage.setItem(AUTH_STORAGE_KEY, JSON.stringify(session));
  notifyAuthStorageUpdated();
}

export function clearStoredSession(): void {
  localStorage.removeItem(AUTH_STORAGE_KEY);
  notifyAuthStorageUpdated();
}

export function setTokens(
  accessToken: string,
  refreshToken: string,
  accessTokenExpiresAt?: string,
  refreshTokenExpiresAt?: string,
): void {
  const session = getStoredSession();
  if (!session) {
    return;
  }

  setStoredSession({
    ...session,
    accessToken,
    refreshToken,
    accessTokenExpiresAt: accessTokenExpiresAt ?? session.accessTokenExpiresAt,
    refreshTokenExpiresAt: refreshTokenExpiresAt ?? session.refreshTokenExpiresAt,
  });
}

export function clearTokens(): void {
  clearStoredSession();
}

export function getAccessToken(): string | null {
  return getStoredSession()?.accessToken ?? null;
}

export function getRefreshToken(): string | null {
  return getStoredSession()?.refreshToken ?? null;
}

export function getAuthStorageEventName(): string {
  return AUTH_STORAGE_EVENT;
}
