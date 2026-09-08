import { createContext } from "react";
import type { DashboardSummary } from "../types/dashboard";

export interface DashboardContextValue {
  summary: DashboardSummary | null;
  loading: boolean;
  refreshing: boolean;
  error: string;
  clockOffsetMilliseconds: number;
  refresh: () => Promise<void>;
}

export const DashboardContext = createContext<DashboardContextValue | null>(null);
