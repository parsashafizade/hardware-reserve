import { StrictMode } from "react";
import { createRoot } from "react-dom/client";
import { AppRoutes } from "./routes/AppRoutes";
import { AuthProvider } from "./auth/AuthContext";
import { LocaleProvider } from "./i18n/LocaleProvider";
import "./i18n/config";
import "./styles/design-tokens.css";
import "./styles/tailwind.css";

createRoot(document.getElementById("root")!).render(
  <StrictMode>
    <LocaleProvider>
      <AuthProvider>
        <AppRoutes />
      </AuthProvider>
    </LocaleProvider>
  </StrictMode>,
);
