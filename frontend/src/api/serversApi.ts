import { httpClient } from "./http";
import type { Server, ServerFilters } from "../types/api";

export const serversApi = {
  getServers(filters: ServerFilters = {}) {
    return httpClient
      .get<Server[]>("/servers", {
        params: filters,
      })
      .then((response) => response.data);
  },
  getServerById(id: number) {
    return httpClient.get<Server>(`/servers/${id}`).then((response) => response.data);
  },
  getAdminServers() {
    return httpClient.get<Server[]>("/admin/servers").then((response) => response.data);
  },
  createServer(payload: Omit<Server, "id">) {
    return httpClient.post<Server>("/admin/servers", payload).then((response) => response.data);
  },
  updateServer(id: number, payload: Omit<Server, "id">) {
    return httpClient.put<Server>(`/admin/servers/${id}`, payload).then((response) => response.data);
  },
  deleteServer(id: number) {
    return httpClient.delete(`/admin/servers/${id}`);
  },
};
