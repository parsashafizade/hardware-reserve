export type AdminCreationValidationError =
  | "required"
  | "passwordPolicy"
  | "passwordMismatch";

export function validateAdminCreation(input: {
  fullName: string;
  email: string;
  password: string;
  confirmPassword: string;
}): AdminCreationValidationError | null {
  if (!input.fullName.trim() || !input.email.trim() || !input.password) {
    return "required";
  }
  if (input.password.length < 8 || input.password.length > 128) {
    return "passwordPolicy";
  }
  return input.password === input.confirmPassword ? null : "passwordMismatch";
}
