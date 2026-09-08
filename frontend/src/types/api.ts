export interface AuthenticatedUser {
  id: number;
  fullName: string;
  email: string;
  role: string;
}

export interface AuthResponse {
  accessToken: string;
  accessTokenExpiresAt: string;
  refreshToken: string;
  refreshTokenExpiresAt: string;
  user: AuthenticatedUser;
}
export interface RegisterResponse {
  email: string;
  requiresEmailVerification: boolean;
  message: string;
}

export interface VerifyEmailRequest {
  email: string;
  code: string;
}

export interface ResendVerificationCodeRequest {
  email: string;
}

export interface CaptchaChallenge {
  captchaId: string;
  a: number;
  b: number;
}

export interface RegisterRequest {
  fullName: string;
  email: string;
  password: string;
  captchaId: string;
  captchaAnswer: number;
}

export interface LoginRequest {
  identifier: string;
  password: string;
  captchaId: string;
  captchaAnswer: number;
}

export interface ForgotPasswordRequest {
  email: string;
}

export interface ResetPasswordRequest {
  token: string;
  newPassword: string;
  confirmPassword: string;
}

export interface MessageResponse {
  message: string;
}

export interface Server {
  id: number;
  cpu: string;
  gpu: string;
  ram: string;
  storage: string;
  os: string;
  pricePerHour: number;
  pricePerDay: number;
  isActive: boolean;
  operationalStatus: "Available" | "TemporarilyUnavailable" | "Maintenance" | "Disabled";
  finderEligible: boolean;
  cpuCapabilityLevel: number;
  gpuCapabilityLevel: number;
  performanceTier: "Entry" | "Standard" | "High" | "Extreme";
  workloadCapabilities: ServerWorkloadCapability[];
}

export interface ServerWorkloadCapability {
  workloadType:
    | "ModelTraining"
    | "Inference"
    | "Rendering"
    | "DevelopmentCompilation"
    | "DataProcessing"
    | "WebBackendHosting"
    | "GeneralCompute";
  suitabilityLevel: number;
}

export interface ServerFilters {
  cpu?: string;
  gpu?: string;
  ram?: string;
  storage?: string;
  os?: string;
}

export interface CreateReservationRequest {
  serverId: number;
  startTime: string;
  endTime: string;
  quotedTotalPrice?: number;
}

export interface CreateReservationResult {
  reservationId: number;
  totalPrice: number;
  durationSummary: string;
}

export type ReservationPricingMode = "Hourly" | "Daily" | "DailyAndHourly";

export interface ReservationQuote {
  serverId: number;
  startTime: string;
  endTime: string;
  durationHours: number;
  totalPrice: number;
  pricingMode: ReservationPricingMode;
  isAvailable: boolean;
}

export interface SuggestReservationRequest {
  serverId: number;
  desiredDurationHours: number;
}

export interface SuggestReservationResult {
  suggestedStart?: string | null;
  suggestedEnd?: string | null;
  message: string;
}

export interface ServerSpecs {
  serverId: number;
  cpu: string;
  gpu: string;
  ram: string;
  storage: string;
  os: string;
}

export interface MyReservation {
  reservationId: number;
  startTime: string;
  endTime: string;
  totalPrice: number;
  status: string;
  paymentStatus: string;
  server: ServerSpecs;
}

export interface ReservationCockpit extends MyReservation {
  serverTimeUtc: string;
  paymentId?: number | null;
  paymentDate?: string | null;
  assignedIp?: string | null;
  assignedUsername?: string | null;
  assignedPassword?: string | null;
}

export interface BusyReservationSlot {
  reservationId?: number | null;
  startTime: string;
  endTime: string;
  source: "Reservation" | "Maintenance";
}

export interface MyService {
  reservationId: number;
  startTime: string;
  endTime: string;
  totalPrice: number;
  server: ServerSpecs;
  assignedIp?: string | null;
  assignedUsername?: string | null;
  assignedPassword?: string | null;
  message?: string | null;
}

export interface PaymentResult {
  paymentId: number;
  reservationId: number;
  amount: number;
  paymentDate: string;
  status: string;
}

export interface Profile {
  id: number;
  fullName: string;
  email: string;
  role: string;
  profileImagePath?: string | null;
  createdAt: string;
}

export interface UpdateProfileRequest {
  fullName: string;
}

export interface EmailChangeStatus {
  currentEmail: string;
  newEmail: string;
  currentEmailVerified: boolean;
  newEmailVerified: boolean;
  currentCodeExpiresAtUtc: string;
  newCodeExpiresAtUtc: string;
  currentResendAvailableAtUtc: string;
  newResendAvailableAtUtc: string;
  expiresAtUtc: string;
}

export interface EmailChangeVerificationResponse {
  completed: boolean;
  status?: EmailChangeStatus | null;
  authentication?: AuthResponse | null;
}

export interface AdminUser {
  id: number;
  fullName: string;
  email: string;
  role: string;
  createdAt: string;
  isEmailVerified: boolean;
}

export interface CreateAdminRequest {
  fullName: string;
  email: string;
  password: string;
}

export const ADMIN_ASSIGNMENT_FILTERS = ["All", "NeedsAssignment", "Assigned"] as const;
export type AdminAssignmentFilter = (typeof ADMIN_ASSIGNMENT_FILTERS)[number];
export type AdminAssignmentStatus = "Assigned" | "NotAssigned";

export interface AdminOrder {
  reservationId: number;
  userId: number;
  userFullName: string;
  userEmail: string;
  serverId: number;
  cpu: string;
  gpu: string;
  ram: string;
  storage: string;
  os: string;
  startTime: string;
  endTime: string;
  totalPrice: number;
  reservationStatus: string;
  paymentStatus: string;
  credentialsAssigned: boolean;
  assignmentStatus: AdminAssignmentStatus;
}

export interface AdminReservationDetail extends AdminOrder {
  assignedIp: string | null;
  assignedUsername: string | null;
  assignedPassword: string | null;
}

export interface AssignCredentialsRequest {
  reservationId: number;
  assignedIp: string;
  assignedUsername: string;
  assignedPassword: string;
}

export interface DashboardStats {
  totalUsers: number;
  totalServers: number;
  totalPurchases: number;
  activeReservations: number;
  upcomingReservations: number;
  startingSoonReservations: number;
  endingSoonReservations: number;
  pendingPayments: number;
  unavailableServers: number;
  maintenanceServers: number;
  waitingSupportConversations: number;
  pendingAssignmentReservations: number;
  supportAttentionConversations: number;
  recentAuditEvents: AdminAuditEvent[];
}

export interface AdminPage<T> {
  items: T[];
  page: number;
  pageSize: number;
  totalCount: number;
}

export interface AdminMaintenanceWindow {
  id: string;
  serverId: number;
  startTime: string;
  endTime: string;
  reason?: string | null;
  createdAt: string;
}

export interface AdminNotificationCampaign {
  id: string;
  createdByAdminUserId: number;
  recipientScope: "User" | "SelectedUsers" | "AllUsers";
  recipientUserId?: number | null;
  recipientEmail?: string | null;
  title: string;
  message: string;
  category: string;
  targetCount: number;
  createdAt: string;
}

export interface AdminNotificationRecipient {
  id: number;
  fullName: string;
  email: string;
}

export interface AdminNotificationHistoryItem {
  id: string;
  userId: number;
  userEmail: string;
  source: "System" | "Admin";
  type: string;
  title?: string | null;
  message?: string | null;
  resourceLabel?: string | null;
  reservationId?: number | null;
  supportConversationId?: string | null;
  adminCampaignId?: string | null;
  createdByAdminUserId?: number | null;
  createdAt: string;
  readAt?: string | null;
}

export interface AdminSendNotificationRequest {
  recipientScope: "SelectedUsers" | "AllUsers";
  userIds?: number[];
  title: string;
  message: string;
  category: "General" | "Reservation" | "Payment" | "Support" | "Account";
  confirmBroadcast: boolean;
}

export interface AdminAuditEvent {
  id: string;
  adminUserId: number;
  action: string;
  entityType: string;
  entityId: string;
  details?: string | null;
  createdAt: string;
}

export interface AdminUserOverview extends AdminUser {
  emailVerifiedAt?: string | null;
  reservationCount: number;
  activeReservationCount: number;
  completedPaymentCount: number;
  supportConversationCount: number;
  unreadNotificationCount: number;
  recentReservations: AdminOrder[];
}

export interface VerifyPasswordResetCodeRequest {
  email: string;
  code: string;
}

export interface VerifyPasswordResetCodeResponse {
  resetToken: string;
  expiresAtUtc: string;
}

export interface ErrorResponse {
  traceId: string;
  code?: string | null;
  message: string;
  errors?: Record<string, string[]>;
}
