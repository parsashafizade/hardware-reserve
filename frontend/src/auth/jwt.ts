const ROLE_CLAIM = "http://schemas.microsoft.com/ws/2008/06/identity/claims/role";

export function parseJwt(token: string): Record<string, unknown> | null {
  try {
    const payload = token.split(".")[1];
    if (!payload) {
      return null;
    }

    const normalized = payload.replace(/-/g, "+").replace(/_/g, "/");
    const decoded = atob(normalized);
    return JSON.parse(decoded) as Record<string, unknown>;
  } catch {
    return null;
  }
}

export function getRoleFromToken(token: string): string | null {
  const parsed = parseJwt(token);
  if (!parsed) {
    return null;
  }

  const role = parsed[ROLE_CLAIM] ?? parsed.role;
  return typeof role === "string" ? role : null;
}
