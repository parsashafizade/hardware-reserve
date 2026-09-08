import { httpClient } from "./http";
import type {
  AuthResponse,
  CaptchaChallenge,
  EmailChangeStatus,
  EmailChangeVerificationResponse,
  ForgotPasswordRequest,
  LoginRequest,
  MessageResponse,
  Profile,
  RegisterRequest,
  RegisterResponse,
  ResendVerificationCodeRequest,
  ResetPasswordRequest,
  UpdateProfileRequest,
  VerifyEmailRequest,
  VerifyPasswordResetCodeRequest,
  VerifyPasswordResetCodeResponse,
} from "../types/api";

export const authApi = {
  getCaptcha() {
    return httpClient.get<CaptchaChallenge>("/auth/captcha").then((response) => response.data);
  },
  register(payload: RegisterRequest) {
    return httpClient
      .post<RegisterResponse>("/auth/register", payload)
      .then((response) => response.data);
  },
  verifyEmail(payload: VerifyEmailRequest) {
  return httpClient
    .post<AuthResponse>("/auth/verify-email", payload)
    .then((response) => response.data);
  },

  resendVerificationCode(payload: ResendVerificationCodeRequest) {
    return httpClient
      .post<MessageResponse>("/auth/resend-verification-code", payload)
      .then((response) => response.data);
  },

  login(payload: LoginRequest) {
    return httpClient.post<AuthResponse>("/auth/login", payload).then((response) => response.data);
  },
  forgotPassword(payload: ForgotPasswordRequest) {
    return httpClient.post<MessageResponse>("/auth/forgot-password", payload).then((response) => response.data);
  },
  verifyPasswordResetCode(
  payload: VerifyPasswordResetCodeRequest,
  ) {
    return httpClient
      .post<VerifyPasswordResetCodeResponse>(
        "/auth/verify-password-reset-code",
        payload,
      )
      .then((response) => response.data);
  },
  resetPassword(payload: ResetPasswordRequest) {
    return httpClient
      .post<AuthResponse>("/auth/reset-password", payload)
      .then((response) => response.data);
  },
  logout(payload: { refreshToken: string }) {
    return httpClient.post<MessageResponse>("/auth/logout", payload).then((response) => response.data);
  },
  getProfile() {
    return httpClient.get<Profile>("/me").then((response) => response.data);
  },
  updateProfile(payload: UpdateProfileRequest) {
    return httpClient.put<Profile>("/me", payload).then((response) => response.data);
  },
  getEmailChangeStatus() {
    return httpClient
      .get<EmailChangeStatus>("/me/email-change")
      .then((response) => response.status === 204 ? null : response.data);
  },
  startEmailChange(payload: { newEmail: string }) {
    return httpClient
      .post<EmailChangeStatus>("/me/email-change", payload)
      .then((response) => response.data);
  },
  verifyCurrentEmailChange(payload: { code: string }) {
    return httpClient
      .post<EmailChangeVerificationResponse>(
        "/me/email-change/verify-current",
        payload,
      )
      .then((response) => response.data);
  },
  verifyNewEmailChange(payload: { code: string }) {
    return httpClient
      .post<EmailChangeVerificationResponse>(
        "/me/email-change/verify-new",
        payload,
      )
      .then((response) => response.data);
  },
  resendCurrentEmailChange() {
    return httpClient
      .post<EmailChangeStatus>("/me/email-change/resend-current")
      .then((response) => response.data);
  },
  resendNewEmailChange() {
    return httpClient
      .post<EmailChangeStatus>("/me/email-change/resend-new")
      .then((response) => response.data);
  },
  cancelEmailChange() {
    return httpClient.delete<void>("/me/email-change");
  },
  uploadProfileImage(file: File | Blob) {
    const formData = new FormData();
    formData.append("file", file, "profile-image.jpg");

    return httpClient
      .post<Profile>("/me/profile-image", formData, {
        headers: {
          "Content-Type": "multipart/form-data",
        },
      })
      .then((response) => response.data);
  },
};
