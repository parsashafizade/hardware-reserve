import type { MyReservation, ServerSpecs } from "./api";

export type DashboardPrimaryState =
  | "PENDING_PAYMENT"
  | "ACTIVE"
  | "STARTING_SOON"
  | "UPCOMING"
  | "RECENT_COMPLETED"
  | "DISCOVERY";

export interface DashboardReservation extends MyReservation {
  canReserveAgain: boolean;
  server: ServerSpecs;
}

export interface DashboardMetrics {
  totalReservations: number;
  pendingPayment: number;
  active: number;
  upcoming: number;
  completed: number;
}

export interface DashboardSummary {
  serverTimeUtc: string;
  primaryState: DashboardPrimaryState;
  primaryReservation?: DashboardReservation | null;
  metrics: DashboardMetrics;
}

export interface CommandServerResult {
  serverId: number;
  label: string;
  cpu: string;
  gpu: string;
  ram: string;
  pricePerHour: number;
}

export interface CommandReservationResult {
  reservationId: number;
  serverId: number;
  serverLabel: string;
  startTime: string;
  endTime: string;
  status: string;
  paymentStatus: string;
}

export interface CommandSearchResult {
  servers: CommandServerResult[];
  reservations: CommandReservationResult[];
}
