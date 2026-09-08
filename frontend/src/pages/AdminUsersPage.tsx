import { useEffect, useState } from "react";
import { AlertCircle, CheckCircle2, KeyRound, LoaderCircle, Mail, RotateCcw, Search, UserPlus, UserRound, Users } from "lucide-react";
import { useTranslation } from "react-i18next";
import { Link } from "react-router-dom";
import { adminApi } from "../api/adminApi";
import { AdminNavigation } from "../components/admin/AdminNavigation";
import { PageHeader } from "../components/ui/PageHeader";
import { StatusBadge } from "../components/ui/StatusBadge";
import type { AdminUser } from "../types/api";
import { getApiErrorMessage, isApiCode } from "../utils/errors";
import { formatDateTime, isolateBidiText } from "../utils/format";
import { useLocale } from "../i18n/useLocale";
import { validateAdminCreation } from "../utils/adminCreation";

function UserRoleBadge({ role }: { role: string }) {
  const { t } = useTranslation();
  const isAdmin = role.trim().toLowerCase() === "admin";
  return <StatusBadge tone={isAdmin ? "brand" : "neutral"} showDot>{isAdmin ? t("admin.common.roleAdmin") : t("admin.common.roleUser")}</StatusBadge>;
}

export function AdminUsersPage() {
  const { t } = useTranslation();
  const { formatNumber } = useLocale();
  const [users, setUsers] = useState<AdminUser[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [requestVersion, setRequestVersion] = useState(0);
  const [query, setQuery] = useState("");
  const [page, setPage] = useState(1);
  const [totalCount, setTotalCount] = useState(0);
  const [fullName, setFullName] = useState("");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [confirmPassword, setConfirmPassword] = useState("");
  const [creating, setCreating] = useState(false);
  const [createError, setCreateError] = useState("");
  const [createMessage, setCreateMessage] = useState("");

  useEffect(() => {
    let cancelled = false;
    const load = async () => {
      setLoading(true);
      setError("");
      try {
        const response = await adminApi.searchUsers({ query: query.trim() || undefined, page, pageSize: 20 });
        if (!cancelled) { setUsers(response.items); setTotalCount(response.totalCount); }
      } catch (loadError) {
        if (!cancelled) {
          setUsers([]);
          setError(getApiErrorMessage(loadError, t("admin.users.loadError")));
        }
      } finally {
        if (!cancelled) setLoading(false);
      }
    };
    void load();
    return () => { cancelled = true; };
  }, [page, query, requestVersion, t]);

  const createAdmin = async (event: React.FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    setCreateError("");
    setCreateMessage("");

    const validationError = validateAdminCreation({ fullName, email, password, confirmPassword });
    if (validationError) {
      const key = validationError === "required"
        ? "admin.users.create.validationRequired"
        : `admin.users.create.${validationError}`;
      setCreateError(t(key));
      return;
    }

    setCreating(true);
    try {
      const created = await adminApi.createAdmin({
        fullName: fullName.trim(),
        email: email.trim(),
        password,
      });
      setFullName("");
      setEmail("");
      setPassword("");
      setConfirmPassword("");
      setQuery("");
      setPage(1);
      setRequestVersion((version) => version + 1);
      setCreateMessage(t("admin.users.create.success", { email: isolateBidiText(created.email) }));
    } catch (submitError) {
      setCreateError(isApiCode(submitError, "EMAIL_ALREADY_EXISTS")
        ? t("admin.users.create.duplicateEmail")
        : getApiErrorMessage(submitError, t("admin.users.create.failed")));
    } finally {
      setCreating(false);
    }
  };

  return (
    <div className="page-stack">
      <AdminNavigation />
      <PageHeader
        eyebrow={t("admin.common.eyebrow")}
        title={t("admin.users.title")}
        description={t("admin.users.description")}
        icon={Users}
        actions={!loading && !error ? <span className="badge-brand">{t("admin.users.accountCount", { count: totalCount, formattedCount: formatNumber(totalCount) })}</span> : undefined}
      />

      <section className="rounded-card border border-border-subtle bg-white p-5 shadow-card sm:p-6" aria-labelledby="create-admin-title">
        <div className="flex items-start gap-3">
          <span className="icon-tile"><UserPlus aria-hidden="true" size={19} /></span>
          <div>
            <h2 id="create-admin-title" className="card-title">{t("admin.users.create.title")}</h2>
            <p className="mt-1 body-copy">{t("admin.users.create.description")}</p>
          </div>
        </div>
        <form className="mt-5 grid gap-4 lg:grid-cols-2" onSubmit={createAdmin}>
          <label className="field"><span>{t("admin.users.create.fullName")}</span><div className="relative"><UserRound aria-hidden="true" className="pointer-events-none absolute start-3 top-1/2 -translate-y-1/2 text-ink-400" size={16} /><input className="input ps-10" dir="auto" value={fullName} onChange={(event) => setFullName(event.target.value)} maxLength={200} autoComplete="name" required /></div></label>
          <label className="field"><span>{t("admin.users.create.email")}</span><div className="relative"><Mail aria-hidden="true" className="pointer-events-none absolute start-3 top-1/2 -translate-y-1/2 text-ink-400" size={16} /><input className="input ps-10 text-left" dir="ltr" type="email" value={email} onChange={(event) => setEmail(event.target.value)} maxLength={320} autoComplete="off" required /></div></label>
          <label className="field"><span>{t("admin.users.create.password")}</span><div className="relative"><KeyRound aria-hidden="true" className="pointer-events-none absolute start-3 top-1/2 -translate-y-1/2 text-ink-400" size={16} /><input className="input ps-10 text-left" dir="ltr" type="password" value={password} onChange={(event) => setPassword(event.target.value)} minLength={8} maxLength={128} autoComplete="new-password" required /></div></label>
          <label className="field"><span>{t("admin.users.create.confirmPassword")}</span><div className="relative"><KeyRound aria-hidden="true" className="pointer-events-none absolute start-3 top-1/2 -translate-y-1/2 text-ink-400" size={16} /><input className="input ps-10 text-left" dir="ltr" type="password" value={confirmPassword} onChange={(event) => setConfirmPassword(event.target.value)} minLength={8} maxLength={128} autoComplete="new-password" required /></div></label>
          <div className="lg:col-span-2" aria-live="polite">
            {createError && <div className="alert-error flex items-start gap-2.5" role="alert"><AlertCircle aria-hidden="true" className="mt-0.5" size={17} /><p>{createError}</p></div>}
            {createMessage && <div className="alert-success flex items-start gap-2.5" role="status"><CheckCircle2 aria-hidden="true" className="mt-0.5" size={17} /><p dir="auto">{createMessage}</p></div>}
          </div>
          <div className="lg:col-span-2">
            <button className="btn-primary" type="submit" disabled={creating}>
              {creating ? <LoaderCircle aria-hidden="true" className="animate-spin" size={17} /> : <UserPlus aria-hidden="true" size={17} />}
              {creating ? t("admin.users.create.creating") : t("admin.users.create.action")}
            </button>
          </div>
        </form>
      </section>

      <label className="field max-w-xl"><span>{t("admin.users.search")}</span><div className="relative"><Search aria-hidden="true" className="pointer-events-none absolute start-3 top-1/2 -translate-y-1/2 text-ink-400" size={16} /><input dir="auto" className="input ps-10" value={query} onChange={(event) => { setQuery(event.target.value); setPage(1); }} placeholder={t("admin.users.searchPlaceholder")} /></div></label>

      {loading ? (
        <div className="space-y-3" role="status" aria-label={t("admin.users.loading")}>
          <div className="skeleton h-16 rounded-card" />
          <div className="skeleton h-16 rounded-card" />
          <div className="skeleton h-16 rounded-card" />
        </div>
      ) : error ? (
        <div className="state-panel" role="alert">
          <span className="icon-tile-neutral"><AlertCircle aria-hidden="true" size={21} /></span>
          <h2 className="mt-4 card-title">{t("admin.users.unavailable")}</h2>
          <p className="mt-2 max-w-md body-copy">{error}</p>
          <button type="button" className="btn-primary mt-5" onClick={() => setRequestVersion((version) => version + 1)}>
            <RotateCcw aria-hidden="true" size={16} />{t("actions.retry")}
          </button>
        </div>
      ) : users.length === 0 ? (
        <div className="state-panel">
          <span className="icon-tile-neutral"><Users aria-hidden="true" size={21} /></span>
          <h2 className="mt-4 card-title">{t("admin.users.empty")}</h2>
          <p className="mt-2 max-w-md body-copy">{t("admin.users.emptyCopy")}</p>
        </div>
      ) : (
        <>
          <div className="table-shell hidden md:block">
            <table className="data-table">
              <thead><tr><th scope="col">{t("common.id")}</th><th scope="col">{t("admin.users.user")}</th><th scope="col">{t("admin.users.email")}</th><th scope="col">{t("admin.users.role")}</th><th scope="col">{t("admin.users.verification")}</th><th scope="col">{t("admin.users.created")}</th><th scope="col">{t("common.actions")}</th></tr></thead>
              <tbody>
                {users.map((user) => (
                  <tr key={user.id}>
                    <td className="font-semibold">#{formatNumber(user.id)}</td>
                    <td dir="auto" className="font-semibold text-ink-900">{user.fullName}</td>
                    <td dir="ltr" className="break-all text-left">{user.email}</td>
                    <td><UserRoleBadge role={user.role} /></td>
                    <td><StatusBadge tone={user.isEmailVerified ? "success" : "warning"}>{user.isEmailVerified ? t("admin.users.verified") : t("admin.users.unverified")}</StatusBadge></td>
                    <td>{formatDateTime(user.createdAt)}</td>
                    <td><Link className="btn-secondary min-h-9 px-3 py-1.5" to={`/admin/users/${user.id}`}>{t("admin.users.open")}</Link></td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>

          <div className="grid gap-3 md:hidden">
            {users.map((user) => (
              <article key={user.id} className="card-compact">
                <div className="flex items-start justify-between gap-3">
                  <div className="flex min-w-0 items-center gap-3">
                    <span className="icon-tile size-10"><UserRound aria-hidden="true" size={17} /></span>
                    <div className="min-w-0">
                      <p dir="auto" className="truncate font-semibold text-ink-950">{user.fullName}</p>
                      <p dir="ltr" className="mt-0.5 break-all text-left text-xs text-ink-500">{user.email}</p>
                    </div>
                  </div>
                  <UserRoleBadge role={user.role} />
                </div>
                <div className="mt-4 flex items-center justify-between gap-4 border-t border-border-subtle pt-3 text-xs text-ink-500">
                  <span>{t("admin.users.accountNumber", { id: formatNumber(user.id) })}</span>
                  <span className="text-end">{t("admin.users.createdAt", { date: formatDateTime(user.createdAt) })}</span>
                </div>
                <Link className="btn-secondary mt-3 w-full" to={`/admin/users/${user.id}`}>{t("admin.users.open")}</Link>
              </article>
            ))}
          </div>
        </>
      )}
      {!loading && totalCount > 20 && <div className="flex items-center justify-between gap-3"><button className="btn-secondary" type="button" disabled={page <= 1} onClick={() => setPage((value) => Math.max(1, value - 1))}>{t("admin.orders.previous")}</button><span className="text-sm text-ink-500">{t("admin.orders.page", { page: formatNumber(page) })}</span><button className="btn-secondary" type="button" disabled={page * 20 >= totalCount} onClick={() => setPage((value) => value + 1)}>{t("admin.orders.next")}</button></div>}
    </div>
  );
}
