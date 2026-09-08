import type { AuthenticatedUser } from "../types/api";

function isSafeInternalPath(path: string | null | undefined): path is string {
  return !!path && path.startsWith("/") && !path.startsWith("//");
}

function isAdminPath(path: string): boolean {
  return path === "/admin" || path.startsWith("/admin/") || path.startsWith("/admin?");
}

export function getAuthenticatedDestination(
  user: AuthenticatedUser,
  requestedPath?: string | null,
): string {
  const isAdmin = user.role.trim().toLowerCase() === "admin";
  if (isAdmin) {
    return isSafeInternalPath(requestedPath) && isAdminPath(requestedPath)
      ? requestedPath
      : "/admin";
  }

  return isSafeInternalPath(requestedPath) && !isAdminPath(requestedPath)
    ? requestedPath
    : "/profile";
}
