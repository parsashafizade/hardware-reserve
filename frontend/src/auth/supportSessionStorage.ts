import type { AnonymousSupportSession } from "../types/support";

const SUPPORT_SESSION_KEY = "hardware_reserve_support_session";

export function getAnonymousSupportSession(): AnonymousSupportSession | null {
  const raw = localStorage.getItem(SUPPORT_SESSION_KEY);
  if (!raw) {
    return null;
  }

  try {
    const session = JSON.parse(raw) as AnonymousSupportSession;
    if (!session.sessionToken || new Date(session.expiresAt).getTime() <= Date.now()) {
      clearAnonymousSupportSession();
      return null;
    }

    return session;
  } catch {
    clearAnonymousSupportSession();
    return null;
  }
}

export function setAnonymousSupportSession(session: AnonymousSupportSession): void {
  localStorage.setItem(SUPPORT_SESSION_KEY, JSON.stringify(session));
}

export function clearAnonymousSupportSession(): void {
  localStorage.removeItem(SUPPORT_SESSION_KEY);
}
