import { httpClient } from "./http";
import type { CommandSearchResult, DashboardSummary } from "../types/dashboard";

export const dashboardApi = {
  getSummary() {
    return httpClient.get<DashboardSummary>("/dashboard").then((response) => response.data);
  },
  searchCommands(query: string, signal?: AbortSignal) {
    return httpClient
      .get<CommandSearchResult>("/dashboard/command-search", {
        params: { query, limit: 4 },
        signal,
      })
      .then((response) => response.data);
  },
};
