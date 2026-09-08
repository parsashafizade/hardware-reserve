import { useEffect, useRef, useState } from "react";
import { useTranslation } from "react-i18next";
import {
  AlertCircle,
  CheckCircle2,
  LoaderCircle,
  Mail,
  MailCheck,
  Pencil,
  RefreshCw,
  Send,
  X,
} from "lucide-react";
import { authApi } from "../../api/authApi";
import { useAuth } from "../../auth/useAuth";
import { useLocale } from "../../i18n/useLocale";
import type { EmailChangeStatus } from "../../types/api";
import { getApiErrorMessage } from "../../utils/errors";
import { OtpInput } from "../auth/OtpInput";

type PendingAction =
  | "start"
  | "verify-current"
  | "verify-new"
  | "resend-current"
  | "resend-new"
  | "cancel"
  | null;

interface EmailChangePanelProps {
  currentEmail: string;
  onCompleted: (newEmail: string) => void;
  initialExpanded?: boolean;
}

interface VerificationCardProps {
  id: string;
  title: string;
  help: string;
  codeLabel: string;
  code: string;
  verified: boolean;
  verifying: boolean;
  resending: boolean;
  resendSeconds: number;
  onCodeChange: (code: string) => void;
  onVerify: () => void;
  onResend: () => void;
}

function VerificationCard({
  id,
  title,
  help,
  codeLabel,
  code,
  verified,
  verifying,
  resending,
  resendSeconds,
  onCodeChange,
  onVerify,
  onResend,
}: VerificationCardProps) {
  const { t } = useTranslation();
  const { formatNumber } = useLocale();

  return (
    <section className="rounded-card border border-border-subtle bg-surface-muted/55 p-4 sm:p-5">
      <div className="flex items-start justify-between gap-3">
        <div className="min-w-0">
          <h4 className="text-sm font-semibold text-ink-900">{title}</h4>
          <p dir="auto" className="mt-1 break-words font-reading text-xs leading-5 text-ink-500">
            {help}
          </p>
        </div>
        {verified && (
          <span className="inline-flex shrink-0 items-center gap-1.5 rounded-full border border-status-success/20 bg-status-success/10 px-2.5 py-1 text-xs font-semibold text-emerald-700">
            <CheckCircle2 aria-hidden="true" size={14} />
            {t("profile.emailChange.verified")}
          </span>
        )}
      </div>

      {!verified && (
        <form
          className="mt-4 space-y-3"
          onSubmit={(event) => {
            event.preventDefault();
            onVerify();
          }}
        >
          <OtpInput
            id={id}
            label={codeLabel}
            value={code}
            onChange={onCodeChange}
            disabled={verifying || resending}
          />

          <div className="flex flex-col gap-2 sm:flex-row">
            <button
              className="btn-primary flex-1"
              type="submit"
              disabled={code.length !== 6 || verifying || resending}
            >
              {verifying ? (
                <LoaderCircle aria-hidden="true" className="animate-spin" size={16} />
              ) : (
                <MailCheck aria-hidden="true" size={16} />
              )}
              {verifying
                ? t("profile.emailChange.verifying")
                : t("profile.emailChange.verify")}
            </button>
            <button
              className="btn-secondary flex-1"
              type="button"
              onClick={onResend}
              disabled={resendSeconds > 0 || verifying || resending}
            >
              {resending ? (
                <LoaderCircle aria-hidden="true" className="animate-spin" size={16} />
              ) : (
                <RefreshCw aria-hidden="true" size={16} />
              )}
              {resending
                ? t("profile.emailChange.resending")
                : resendSeconds > 0
                  ? t("profile.emailChange.resendIn", {
                      seconds: formatNumber(resendSeconds),
                    })
                  : t("profile.emailChange.resend")}
            </button>
          </div>
        </form>
      )}
    </section>
  );
}

function secondsUntil(value: string, now: number): number {
  const timestamp = Date.parse(value);
  if (!Number.isFinite(timestamp)) {
    return 0;
  }

  return Math.max(0, Math.ceil((timestamp - now) / 1000));
}

export function EmailChangePanel({
  currentEmail,
  onCompleted,
  initialExpanded = false,
}: EmailChangePanelProps) {
  const { t } = useTranslation();
  const { setSession } = useAuth();
  const [status, setStatus] = useState<EmailChangeStatus | null>(null);
  const [expanded, setExpanded] = useState(false);
  const [newEmail, setNewEmail] = useState("");
  const [currentCode, setCurrentCode] = useState("");
  const [newCode, setNewCode] = useState("");
  const [pendingAction, setPendingAction] = useState<PendingAction>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [success, setSuccess] = useState("");
  const [now, setNow] = useState(() => Date.now());
  const initialExpansionHandledRef = useRef(false);

  useEffect(() => {
    let active = true;

    const loadStatus = async () => {
      try {
        const result = await authApi.getEmailChangeStatus();
        if (active) {
          setStatus(result);
          setExpanded(Boolean(result));
        }
      } catch (loadError) {
        if (active) {
          setError(getApiErrorMessage(loadError, t("profile.emailChange.loadError")));
        }
      } finally {
        if (active) {
          setLoading(false);
        }
      }
    };

    void loadStatus();
    return () => {
      active = false;
    };
  }, [t]);

  useEffect(() => {
    if (!loading && initialExpanded && !initialExpansionHandledRef.current) {
      initialExpansionHandledRef.current = true;
      if (!status) {
        setExpanded(true);
      }
      window.setTimeout(() => document.getElementById("email-change")?.scrollIntoView({ block: "center" }), 0);
    }
  }, [initialExpanded, loading, status]);

  useEffect(() => {
    if (!status) {
      return undefined;
    }

    const timer = window.setInterval(() => setNow(Date.now()), 1000);
    return () => window.clearInterval(timer);
  }, [status]);

  const startEmailChange = async (event: React.FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    setPendingAction("start");
    setError("");
    setSuccess("");

    try {
      const result = await authApi.startEmailChange({ newEmail: newEmail.trim() });
      setStatus(result);
      setCurrentCode("");
      setNewCode("");
      setNow(Date.now());
    } catch (startError) {
      setError(getApiErrorMessage(startError, t("errors.generic")));
    } finally {
      setPendingAction(null);
    }
  };

  const verify = async (destination: "current" | "new") => {
    const action = destination === "current" ? "verify-current" : "verify-new";
    const code = destination === "current" ? currentCode : newCode;
    setPendingAction(action);
    setError("");
    setSuccess("");

    try {
      const result = destination === "current"
        ? await authApi.verifyCurrentEmailChange({ code })
        : await authApi.verifyNewEmailChange({ code });

      if (result.completed) {
        if (!result.authentication) {
          setError(t("profile.emailChange.incompleteResponse"));
          return;
        }

        setSession(result.authentication);
        onCompleted(result.authentication.user.email);
        setStatus(null);
        setExpanded(false);
        setNewEmail("");
        setCurrentCode("");
        setNewCode("");
        setSuccess(t("profile.emailChange.success"));
        return;
      }

      if (result.status) {
        setStatus(result.status);
      }

      if (destination === "current") {
        setCurrentCode("");
      } else {
        setNewCode("");
      }
    } catch (verifyError) {
      setError(getApiErrorMessage(verifyError, t("errors.generic")));
    } finally {
      setPendingAction(null);
    }
  };

  const resend = async (destination: "current" | "new") => {
    setPendingAction(destination === "current" ? "resend-current" : "resend-new");
    setError("");
    setSuccess("");

    try {
      const result = destination === "current"
        ? await authApi.resendCurrentEmailChange()
        : await authApi.resendNewEmailChange();
      setStatus(result);
      setNow(Date.now());
      if (destination === "current") {
        setCurrentCode("");
      } else {
        setNewCode("");
      }
    } catch (resendError) {
      setError(getApiErrorMessage(resendError, t("errors.generic")));
    } finally {
      setPendingAction(null);
    }
  };

  const cancel = async () => {
    setPendingAction("cancel");
    setError("");

    try {
      await authApi.cancelEmailChange();
      setStatus(null);
      setExpanded(false);
      setNewEmail("");
      setCurrentCode("");
      setNewCode("");
    } catch (cancelError) {
      setError(getApiErrorMessage(cancelError, t("errors.generic")));
    } finally {
      setPendingAction(null);
    }
  };

  const currentResendSeconds = status
    ? secondsUntil(status.currentResendAvailableAtUtc, now)
    : 0;
  const newResendSeconds = status
    ? secondsUntil(status.newResendAvailableAtUtc, now)
    : 0;

  return (
    <section id="email-change" className="scroll-mt-28 mt-6 border-t border-border-subtle pt-6" aria-labelledby="email-change-title">
      <div className="flex flex-col gap-4 sm:flex-row sm:items-start sm:justify-between">
        <div className="flex items-start gap-3">
          <span className="icon-tile"><Mail aria-hidden="true" size={18} /></span>
          <div>
            <p className="section-kicker">{t("profile.emailChange.section")}</p>
            <h3 id="email-change-title" className="mt-1 card-title">
              {t("profile.emailChange.title")}
            </h3>
            <p className="mt-1 max-w-xl font-reading text-sm leading-6 text-ink-500">
              {t("profile.emailChange.description")}
            </p>
          </div>
        </div>
        {!expanded && !loading && (
          <button
            type="button"
            className="btn-secondary shrink-0"
            onClick={() => {
              setExpanded(true);
              setError("");
              setSuccess("");
            }}
          >
            <Pencil aria-hidden="true" size={16} />
            {t("profile.emailChange.changeAction")}
          </button>
        )}
      </div>

      <div className="mt-4 rounded-control border border-border-subtle bg-surface-muted/50 px-4 py-3">
        <p className="text-xs font-medium text-ink-500">{t("profile.emailChange.currentEmail")}</p>
        <p dir="ltr" className="mt-1 break-all text-sm font-semibold text-ink-900">{currentEmail}</p>
      </div>

      <div className="mt-4" aria-live="polite">
        {success && (
          <div className="alert-success flex items-start gap-2.5" role="status">
            <CheckCircle2 aria-hidden="true" className="mt-0.5 shrink-0" size={17} />
            <p>{success}</p>
          </div>
        )}
        {error && (
          <div className="alert-error flex items-start gap-2.5" role="alert">
            <AlertCircle aria-hidden="true" className="mt-0.5 shrink-0" size={17} />
            <p>{error}</p>
          </div>
        )}
      </div>

      {loading ? (
        <div className="mt-4 flex items-center gap-2 text-sm text-ink-500" role="status">
          <LoaderCircle aria-hidden="true" className="animate-spin" size={17} />
          {t("accessibility.loading")}
        </div>
      ) : status ? (
        <div className="mt-5">
          <div className="rounded-control border border-brand-200 bg-brand-50/60 p-4">
            <h4 className="text-sm font-semibold text-brand-900">{t("profile.emailChange.pendingTitle")}</h4>
            <p className="mt-1 font-reading text-xs leading-5 text-brand-800">{t("profile.emailChange.pendingDescription")}</p>
          </div>

          <div className="mt-4 grid gap-4 xl:grid-cols-2">
            <VerificationCard
              id="email-change-current-code"
              title={t("profile.emailChange.currentCodeTitle")}
              help={t("profile.emailChange.currentCodeHelp", { email: status.currentEmail })}
              codeLabel={t("profile.emailChange.codeLabel")}
              code={currentCode}
              verified={status.currentEmailVerified}
              verifying={pendingAction === "verify-current"}
              resending={pendingAction === "resend-current"}
              resendSeconds={currentResendSeconds}
              onCodeChange={setCurrentCode}
              onVerify={() => void verify("current")}
              onResend={() => void resend("current")}
            />
            <VerificationCard
              id="email-change-new-code"
              title={t("profile.emailChange.newCodeTitle")}
              help={t("profile.emailChange.newCodeHelp", { email: status.newEmail })}
              codeLabel={t("profile.emailChange.codeLabel")}
              code={newCode}
              verified={status.newEmailVerified}
              verifying={pendingAction === "verify-new"}
              resending={pendingAction === "resend-new"}
              resendSeconds={newResendSeconds}
              onCodeChange={setNewCode}
              onVerify={() => void verify("new")}
              onResend={() => void resend("new")}
            />
          </div>

          <button
            type="button"
            className="btn-ghost mt-4 text-status-danger hover:bg-red-50 hover:text-rose-800"
            onClick={() => void cancel()}
            disabled={pendingAction !== null}
          >
            {pendingAction === "cancel" ? (
              <LoaderCircle aria-hidden="true" className="animate-spin" size={16} />
            ) : (
              <X aria-hidden="true" size={16} />
            )}
            {pendingAction === "cancel"
              ? t("profile.emailChange.cancelling")
              : t("profile.emailChange.cancel")}
          </button>
        </div>
      ) : expanded ? (
        <form className="mt-5 space-y-4" onSubmit={startEmailChange}>
          <label className="field">
            <span>{t("profile.emailChange.newEmail")}</span>
            <input
              className="input"
              dir="ltr"
              type="email"
              autoComplete="email"
              maxLength={320}
              placeholder={t("profile.emailChange.newEmailPlaceholder")}
              value={newEmail}
              onChange={(event) => setNewEmail(event.target.value)}
              required
              disabled={pendingAction === "start"}
            />
            <span className="field-hint">{t("profile.emailChange.newEmailHint")}</span>
          </label>

          <div className="flex flex-col gap-2 sm:flex-row">
            <button
              type="submit"
              className="btn-primary"
              disabled={pendingAction === "start" || !newEmail.trim()}
            >
              {pendingAction === "start" ? (
                <LoaderCircle aria-hidden="true" className="animate-spin" size={16} />
              ) : (
                <Send aria-hidden="true" size={16} />
              )}
              {pendingAction === "start"
                ? t("profile.emailChange.sendingCodes")
                : t("profile.emailChange.sendCodes")}
            </button>
            <button
              type="button"
              className="btn-secondary"
              onClick={() => {
                setExpanded(false);
                setNewEmail("");
                setError("");
              }}
              disabled={pendingAction === "start"}
            >
              {t("actions.cancel")}
            </button>
          </div>
        </form>
      ) : null}
    </section>
  );
}
