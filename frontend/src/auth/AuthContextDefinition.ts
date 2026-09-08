import { createContext } from "react";
import type { AuthResponse } from "../types/api";

export interface AuthContextValue {
  session: AuthResponse | null;
  isAuthenticated: boolean;
  isAdmin: boolean;
  setSession: (session: AuthResponse) => void;
  logout: () => Promise<void>;
}

export const AuthContext = createContext<AuthContextValue | undefined>(undefined);
