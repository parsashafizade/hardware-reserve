import { Navigate, Outlet } from "react-router-dom";
import { useAuth } from "../auth/useAuth";
import { getAuthenticatedDestination } from "../auth/destinations";

export function GuestRoute() {
  const { isAuthenticated, session } = useAuth();

  if (isAuthenticated && session) {
    return <Navigate to={getAuthenticatedDestination(session.user)} replace />;
  }

  return <Outlet />;
}
