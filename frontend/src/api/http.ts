import axios, { AxiosError, type InternalAxiosRequestConfig } from "axios";
import type { AuthResponse } from "../types/api";
import { clearTokens, getAccessToken, getRefreshToken, setStoredSession } from "../auth/tokenStorage";
import { shouldInvalidateSessionAfterRefreshFailure } from "../auth/refreshPolicy";
import { API_BASE_URL } from "./config";

interface RetryableRequestConfig extends InternalAxiosRequestConfig {
  _retry?: boolean;
}

function redirectToLogin() {
  const returnUrl = encodeURIComponent(`${window.location.pathname}${window.location.search}`);
  window.location.href = `/login?returnUrl=${returnUrl}`;
}

async function requestRefreshToken(): Promise<AuthResponse> {
  const refreshToken = getRefreshToken();
  if (!refreshToken) {
    throw new Error("No refresh token available");
  }

  const response = await axios.post<AuthResponse>(`${API_BASE_URL}/auth/refresh`, {
    refreshToken,
  });

  return response.data;
}

export const httpClient = axios.create({
  baseURL: API_BASE_URL,
});

let refreshPromise: Promise<AuthResponse> | null = null;

httpClient.interceptors.request.use((config) => {
  const token = getAccessToken();
  if (token) {
    config.headers.Authorization = `Bearer ${token}`;
  }

  return config;
});

httpClient.interceptors.response.use(
  (response) => response,
  async (error: AxiosError) => {
    const originalRequest = error.config as RetryableRequestConfig | undefined;

    if (!originalRequest) {
      return Promise.reject(error);
    }

    const url = originalRequest.url ?? "";
    const isAuthEndpoint =
      url.includes("/auth/login") ||
      url.includes("/auth/register") ||
      url.includes("/auth/verify-email") ||
      url.includes("/auth/resend-verification-code") ||
      url.includes("/auth/refresh");

    if (error.response?.status !== 401 || originalRequest._retry || isAuthEndpoint) {
      return Promise.reject(error);
    }

    originalRequest._retry = true;

    try {
      if (!refreshPromise) {
        refreshPromise = requestRefreshToken();
      }

      const refreshed = await refreshPromise;
      // Refresh returns the canonical user as well as rotated tokens. Keeping
      // the complete response ensures role changes take effect without a
      // logout/login cycle while API authorization remains authoritative.
      setStoredSession(refreshed);
      refreshPromise = null;

      originalRequest.headers.Authorization = `Bearer ${refreshed.accessToken}`;
      return httpClient(originalRequest);
    } catch (refreshError) {
      refreshPromise = null;
      if (!getRefreshToken() || shouldInvalidateSessionAfterRefreshFailure(refreshError)) {
        clearTokens();
        redirectToLogin();
      }
      return Promise.reject(refreshError);
    }
  },
);
