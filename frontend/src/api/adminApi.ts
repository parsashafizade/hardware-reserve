import { httpClient } from "./http";
import type {
  AdminAuditEvent,
  AdminAssignmentFilter,
  AdminMaintenanceWindow,
  AdminNotificationCampaign,
  AdminNotificationHistoryItem,
  AdminNotificationRecipient,
  AdminOrder,
  AdminPage,
  AdminReservationDetail,
  AdminSendNotificationRequest,
  AdminUser,
  AdminUserOverview,
  AssignCredentialsRequest,
  CreateAdminRequest,
  DashboardStats,
} from "../types/api";

export const adminApi = {
  getDashboardStats() {
    return httpClient.get<DashboardStats>("/dashboard/stats").then((response) => response.data);
  },
  getUsers() {
    return httpClient.get<AdminUser[]>("/admin/users").then((response) => response.data);
  },
  searchUsers(params: { query?: string; page?: number; pageSize?: number } = {}) {
    return httpClient.get<AdminPage<AdminUser>>("/admin/users/search", { params }).then((response) => response.data);
  },
  searchNotificationRecipients(params: { query?: string; page?: number; pageSize?: number } = {}, signal?: AbortSignal) {
    return httpClient.get<AdminPage<AdminNotificationRecipient>>("/admin/notification-recipients", { params, signal }).then((response) => response.data);
  },
  createAdmin(payload: CreateAdminRequest) {
    return httpClient.post<AdminUser>("/admin/users/admins", payload).then((response) => response.data);
  },
  getOrders() {
    return httpClient.get<AdminOrder[]>("/admin/orders").then((response) => response.data);
  },
  getReservations(params: { query?: string; status?: string; assignmentStatus?: AdminAssignmentFilter; page?: number; pageSize?: number } = {}) {
    return httpClient.get<AdminPage<AdminOrder>>("/admin/reservations", { params }).then((response) => response.data);
  },
  getReservation(reservationId: number) {
    return httpClient.get<AdminReservationDetail>(`/admin/reservations/${reservationId}`).then((response) => response.data);
  },
  cancelReservation(reservationId: number) {
    return httpClient.post<AdminOrder>(`/admin/reservations/${reservationId}/cancel`).then((response) => response.data);
  },
  getUserOverview(userId: number) {
    return httpClient.get<AdminUserOverview>(`/admin/users/${userId}/overview`).then((response) => response.data);
  },
  getMaintenanceWindows(serverId: number) {
    return httpClient.get<AdminMaintenanceWindow[]>(`/admin/servers/${serverId}/maintenance`).then((response) => response.data);
  },
  createMaintenanceWindow(serverId: number, payload: { startTime: string; endTime: string; reason?: string }) {
    return httpClient.post<AdminMaintenanceWindow>(`/admin/servers/${serverId}/maintenance`, payload).then((response) => response.data);
  },
  removeMaintenanceWindow(windowId: string) {
    return httpClient.delete(`/admin/servers/maintenance/${windowId}`);
  },
  sendNotification(payload: AdminSendNotificationRequest) {
    return httpClient.post<AdminNotificationCampaign>("/admin/notifications", payload).then((response) => response.data);
  },
  getNotificationHistory(page = 1, pageSize = 20) {
    return httpClient.get<AdminPage<AdminNotificationCampaign>>("/admin/notifications", { params: { page, pageSize } }).then((response) => response.data);
  },
  getNotificationDeliveries(params: { source?: string; type?: string; userId?: number; isRead?: boolean; page?: number; pageSize?: number } = {}) {
    return httpClient.get<AdminPage<AdminNotificationHistoryItem>>("/admin/notification-deliveries", { params }).then((response) => response.data);
  },
  getAudit(take = 20) {
    return httpClient.get<AdminAuditEvent[]>("/admin/audit", { params: { take } }).then((response) => response.data);
  },
  assignCredentials(payload: AssignCredentialsRequest) {
    return httpClient.post<AdminReservationDetail>("/admin/assign-credentials", payload).then((response) => response.data);
  },
  exportOrdersExcel() {
    return httpClient.get<Blob>("/admin/export/excel", { responseType: "blob" }).then((response) => response.data);
  },
};
