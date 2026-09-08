import { httpClient } from "./http";
import type {
  BusyReservationSlot,
  CreateReservationRequest,
  CreateReservationResult,
  MyReservation,
  MyService,
  ReservationQuote,
  ReservationCockpit,
  SuggestReservationRequest,
  SuggestReservationResult,
} from "../types/api";

export const reservationsApi = {
  createReservation(payload: CreateReservationRequest) {
    return httpClient.post<CreateReservationResult>("/reservations", payload).then((response) => response.data);
  },
  quoteReservation(payload: CreateReservationRequest) {
    return httpClient.post<ReservationQuote>("/reservations/quote", payload).then((response) => response.data);
  },
  suggestReservation(payload: SuggestReservationRequest) {
    return httpClient.post<SuggestReservationResult>("/reservations/suggest", payload).then((response) => response.data);
  },
  getMyReservations() {
    return httpClient.get<MyReservation[]>("/my-reservations").then((response) => response.data);
  },
  getReservationById(reservationId: number) {
    return httpClient.get<MyReservation>(`/reservations/${reservationId}`).then((response) => response.data);
  },
  getCockpit(reservationId: number) {
    return httpClient
      .get<ReservationCockpit>(`/reservations/${reservationId}/cockpit`)
      .then((response) => response.data);
  },
  getBusySlots(serverId: number, fromUtc?: string, toUtc?: string) {
    return httpClient
      .get<BusyReservationSlot[]>(`/reservations/server/${serverId}/busy`, {
        params: { fromUtc, toUtc },
      })
      .then((response) => response.data);
  },
  getMyServices() {
    return httpClient.get<MyService[]>("/my-services").then((response) => response.data);
  },
  exportMyReservationsCsv() {
    return httpClient.get<Blob>("/export/csv", { responseType: "blob" }).then((response) => response.data);
  },
};
