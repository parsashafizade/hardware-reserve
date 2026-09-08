import { useCallback, useEffect, useState } from "react";
import { AlertCircle, CalendarClock, LoaderCircle, Plus, Trash2 } from "lucide-react";
import { useTranslation } from "react-i18next";
import { adminApi } from "../../api/adminApi";
import { useLocale } from "../../i18n/useLocale";
import type { AdminMaintenanceWindow, Server } from "../../types/api";
import { getApiErrorMessage } from "../../utils/errors";

export function AdminServerMaintenancePanel({ servers }: { servers: Server[] }) {
  const { t } = useTranslation();
  const { formatDate, formatNumber } = useLocale();
  const [serverId, setServerId] = useState(servers.find((server) => server.isActive)?.id ?? servers[0]?.id ?? 0);
  const [windows, setWindows] = useState<AdminMaintenanceWindow[]>([]);
  const [startTime, setStartTime] = useState("");
  const [endTime, setEndTime] = useState("");
  const [reason, setReason] = useState("");
  const [loading, setLoading] = useState(false);
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState("");

  const load = useCallback(async (selectedServerId: number) => {
    if (!selectedServerId) return;
    setLoading(true);
    setError("");
    try { setWindows(await adminApi.getMaintenanceWindows(selectedServerId)); }
    catch (loadError) { setError(getApiErrorMessage(loadError, t("admin.maintenance.loadError"))); }
    finally { setLoading(false); }
  }, [t]);

  useEffect(() => { void load(serverId); }, [load, serverId]);

  const createWindow = async (event: React.FormEvent) => {
    event.preventDefault();
    setSubmitting(true);
    setError("");
    try {
      await adminApi.createMaintenanceWindow(serverId, { startTime: new Date(startTime).toISOString(), endTime: new Date(endTime).toISOString(), reason: reason.trim() || undefined });
      setStartTime(""); setEndTime(""); setReason("");
      await load(serverId);
    } catch (submitError) { setError(getApiErrorMessage(submitError, t("admin.maintenance.createError"))); }
    finally { setSubmitting(false); }
  };

  const removeWindow = async (windowId: string) => {
    if (!window.confirm(t("admin.maintenance.removeConfirm"))) return;
    setError("");
    try { await adminApi.removeMaintenanceWindow(windowId); await load(serverId); }
    catch (removeError) { setError(getApiErrorMessage(removeError, t("admin.maintenance.removeError"))); }
  };

  const dateTimeOptions: Intl.DateTimeFormatOptions = { dateStyle: "medium", timeStyle: "short" };
  return <section className="card" aria-labelledby="maintenance-title"><div className="flex items-start gap-3 border-b border-border-subtle pb-5"><span className="icon-tile-neutral"><CalendarClock aria-hidden="true" size={19} /></span><div><p className="section-kicker">{t("admin.maintenance.eyebrow")}</p><h2 id="maintenance-title" className="mt-1 card-title">{t("admin.maintenance.title")}</h2><p className="mt-1 text-sm text-ink-500">{t("admin.maintenance.description")}</p></div></div>{error && <div className="alert-error mt-5 flex gap-2.5" role="alert"><AlertCircle aria-hidden="true" size={17} /><p>{error}</p></div>}<form className="mt-5 grid gap-4 lg:grid-cols-5" onSubmit={createWindow}><label className="field"><span>{t("admin.maintenance.server")}</span><select className="select" value={serverId} onChange={(event) => setServerId(Number(event.target.value))}>{servers.map((server) => <option key={server.id} value={server.id}>#{formatNumber(server.id)} · {server.gpu === "None" ? server.cpu : server.gpu}</option>)}</select></label><label className="field"><span>{t("admin.maintenance.start")}</span><input className="input" type="datetime-local" value={startTime} onChange={(event) => setStartTime(event.target.value)} required /></label><label className="field"><span>{t("admin.maintenance.end")}</span><input className="input" type="datetime-local" value={endTime} onChange={(event) => setEndTime(event.target.value)} required /></label><label className="field"><span>{t("admin.maintenance.reason")}</span><input dir="auto" className="input" maxLength={300} value={reason} onChange={(event) => setReason(event.target.value)} /></label><button className="btn-primary self-end" type="submit" disabled={submitting || !startTime || !endTime}>{submitting ? <LoaderCircle aria-hidden="true" className="animate-spin" size={16} /> : <Plus aria-hidden="true" size={16} />}{t("admin.maintenance.add")}</button></form><div className="mt-5 space-y-2" aria-busy={loading}>{loading ? <div className="skeleton h-16 rounded-control" /> : windows.length === 0 ? <p className="rounded-control bg-surface-muted/55 p-4 text-sm text-ink-500">{t("admin.maintenance.empty")}</p> : windows.map((item) => <div key={item.id} className="flex flex-col gap-3 rounded-control border border-border-subtle p-4 sm:flex-row sm:items-center sm:justify-between"><div><p className="font-semibold text-ink-900"><bdi>{formatDate(item.startTime, dateTimeOptions)}</bdi> → <bdi>{formatDate(item.endTime, dateTimeOptions)}</bdi></p>{item.reason && <p dir="auto" className="mt-1 text-sm text-ink-500">{item.reason}</p>}</div><button type="button" className="btn-danger min-h-9 px-3 py-1.5" onClick={() => void removeWindow(item.id)}><Trash2 aria-hidden="true" size={14} />{t("admin.maintenance.remove")}</button></div>)}</div></section>;
}
