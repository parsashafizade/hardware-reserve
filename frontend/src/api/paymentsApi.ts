import { httpClient } from "./http";
import type { PaymentResult } from "../types/api";

export const paymentsApi = {
  payReservation(reservationId: number) {
    return httpClient.post<PaymentResult>(`/payments/${reservationId}`).then((response) => response.data);
  },
};
