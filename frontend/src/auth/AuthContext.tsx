import { useEffect, useMemo, useState, type ReactNode } from "react";
import type { AuthResponse } from "../types/api";
import { clearTokens, getAuthStorageEventName, getRefreshToken, getStoredSession, setStoredSession } from "./tokenStorage";
import { authApi } from "../api/authApi";
import { AuthContext, type AuthContextValue } from "./AuthContextDefinition";

export function AuthProvider({ children }: { children: ReactNode }) {
  const [session, setSessionState] = useState<AuthResponse | null>(() => getStoredSession());

  useEffect(() => {
    const onStorage = () => {
      setSessionState(getStoredSession());
    };

    const authStorageEvent = getAuthStorageEventName();
    window.addEventListener("storage", onStorage);
    window.addEventListener(authStorageEvent, onStorage);
    return () => {
      window.removeEventListener("storage", onStorage);
      window.removeEventListener(authStorageEvent, onStorage);
    };
  }, []);

  const setSession = (nextSession: AuthResponse) => {
    setStoredSession(nextSession);
    setSessionState(nextSession);
  };

  const logout = async () => {
    const refreshToken = getRefreshToken();
    if (refreshToken) {
      try {
        await authApi.logout({ refreshToken });
      } catch {
        // ignore symbolic logout failures
      }
    }

    clearTokens();
    setSessionState(null);
  };

  const value = useMemo<AuthContextValue>(() => {
    const role = session?.user.role ?? "";
    return {
      session,
      isAuthenticated: !!session?.accessToken,
      isAdmin: role.toLowerCase() === "admin",
      setSession,
      logout,
    };
  }, [session]);

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}
