import { lazy } from "react";
import { BrowserRouter, Navigate, Route, Routes } from "react-router-dom";
import { AppLayout } from "../components/AppLayout";
import { AdminRoute } from "./AdminRoute";
import { ProtectedRoute } from "./ProtectedRoute";
import { GuestRoute } from "./GuestRoute";
import { UserRoute } from "./UserRoute";
import { useAuth } from "../auth/useAuth";
import { SupportProvider } from "../support/SupportProvider";
import { SupportRealtimeProvider } from "../support/SupportRealtimeProvider";
import { NotificationProvider } from "../notifications/NotificationProvider";
import { DashboardProvider } from "../dashboard/DashboardProvider";

const HomePage = lazy(() => import("../pages/HomePage").then((module) => ({ default: module.HomePage })));
const ServersPage = lazy(() => import("../pages/ServersPage").then((module) => ({ default: module.ServersPage })));
const ServerDetailsPage = lazy(() => import("../pages/ServerDetailsPage").then((module) => ({ default: module.ServerDetailsPage })));
const LoginPage = lazy(() => import("../pages/LoginPage").then((module) => ({ default: module.LoginPage })));
const RegisterPage = lazy(() => import("../pages/RegisterPage").then((module) => ({ default: module.RegisterPage })));
const VerifyEmailPage = lazy(() => import("../pages/VerifyEmailPage").then((module) => ({ default: module.VerifyEmailPage })));
const ForgotPasswordPage = lazy(() => import("../pages/ForgotPasswordPage").then((module) => ({ default: module.ForgotPasswordPage })));
const ResetPasswordPage = lazy(() => import("../pages/ResetPasswordPage").then((module) => ({ default: module.ResetPasswordPage })));
const ProfilePage = lazy(() => import("../pages/ProfilePage").then((module) => ({ default: module.ProfilePage })));
const MyReservationsPage = lazy(() => import("../pages/MyReservationsPage").then((module) => ({ default: module.MyReservationsPage })));
const MyServicesPage = lazy(() => import("../pages/MyServicesPage").then((module) => ({ default: module.MyServicesPage })));
const ReservePage = lazy(() => import("../pages/ReservePage").then((module) => ({ default: module.ReservePage })));
const CheckoutPage = lazy(() => import("../pages/CheckoutPage").then((module) => ({ default: module.CheckoutPage })));
const ServiceCockpitPage = lazy(() => import("../pages/ServiceCockpitPage").then((module) => ({ default: module.ServiceCockpitPage })));
const ActivityCenterPage = lazy(() => import("../pages/ActivityCenterPage").then((module) => ({ default: module.ActivityCenterPage })));
const AdminDashboardPage = lazy(() => import("../pages/AdminDashboardPage").then((module) => ({ default: module.AdminDashboardPage })));
const AdminServersPage = lazy(() => import("../pages/AdminServersPage").then((module) => ({ default: module.AdminServersPage })));
const AdminOrdersPage = lazy(() => import("../pages/AdminOrdersPage").then((module) => ({ default: module.AdminOrdersPage })));
const AdminUsersPage = lazy(() => import("../pages/AdminUsersPage").then((module) => ({ default: module.AdminUsersPage })));
const AdminUserOverviewPage = lazy(() => import("../pages/AdminUserOverviewPage").then((module) => ({ default: module.AdminUserOverviewPage })));
const AdminNotificationsPage = lazy(() => import("../pages/AdminNotificationsPage").then((module) => ({ default: module.AdminNotificationsPage })));
const AdminSupportPage = lazy(() => import("../pages/AdminSupportPage").then((module) => ({ default: module.AdminSupportPage })));
const NotFoundPage = lazy(() => import("../pages/NotFoundPage").then((module) => ({ default: module.NotFoundPage })));

function LandingRoute() {
  const { isAdmin } = useAuth();
  return isAdmin ? <Navigate to="/admin" replace /> : <HomePage />;
}

export function AppRoutes() {
  return (
    <BrowserRouter>
      <SupportRealtimeProvider>
        <NotificationProvider>
          <DashboardProvider>
            <SupportProvider>
              <Routes>
                <Route element={<AppLayout />}>
                <Route path="/" element={<LandingRoute />} />
                <Route path="/servers" element={<ServersPage />} />
                <Route path="/server/:id" element={<ServerDetailsPage />} />

                <Route element={<GuestRoute />}>
                  <Route path="/login" element={<LoginPage />} />
                  <Route path="/register" element={<RegisterPage />} />
                </Route>
                <Route path="/verify-email" element={<VerifyEmailPage />} />
                <Route path="/forgot-password" element={<ForgotPasswordPage />} />
                <Route path="/reset-password" element={<ResetPasswordPage />} />

                <Route element={<ProtectedRoute />}>
                  <Route path="/profile" element={<ProfilePage />} />
                  <Route path="/activity" element={<ActivityCenterPage />} />

                  <Route element={<UserRoute />}>
                    <Route path="/my-reservations" element={<MyReservationsPage />} />
                    <Route path="/my-services" element={<MyServicesPage />} />
                    <Route path="/reserve/:serverId" element={<ReservePage />} />
                    <Route path="/checkout/:reservationId" element={<CheckoutPage />} />
                    <Route path="/my-reservations/:reservationId" element={<ServiceCockpitPage />} />
                  </Route>

                  <Route element={<AdminRoute />}>
                    <Route path="/admin" element={<AdminDashboardPage />} />
                    <Route path="/admin/servers" element={<AdminServersPage />} />
                    <Route path="/admin/orders" element={<AdminOrdersPage />} />
                    <Route path="/admin/users" element={<AdminUsersPage />} />
                    <Route path="/admin/users/:userId" element={<AdminUserOverviewPage />} />
                    <Route path="/admin/notifications" element={<AdminNotificationsPage />} />
                    <Route path="/admin/support" element={<AdminSupportPage />} />
                    <Route path="/admin/support/:conversationId" element={<AdminSupportPage />} />
                  </Route>
                </Route>

                <Route path="/home" element={<Navigate to="/" replace />} />
                <Route path="*" element={<NotFoundPage />} />
                </Route>
              </Routes>
            </SupportProvider>
          </DashboardProvider>
        </NotificationProvider>
      </SupportRealtimeProvider>
    </BrowserRouter>
  );
}
