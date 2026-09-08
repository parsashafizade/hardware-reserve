import { Navigate, Outlet } from "react-router-dom";
import { useAuth } from "../auth/useAuth";

export function UserRoute() {
  const { isAdmin } = useAuth();
  return isAdmin ? <Navigate to="/admin" replace /> : <Outlet />;
}
