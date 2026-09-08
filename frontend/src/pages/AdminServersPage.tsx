import { useEffect, useState } from "react";
import { AlertCircle, Boxes, CheckCircle2, Gauge, LoaderCircle, Pencil, Plus, RotateCcw, Server as ServerIcon, X } from "lucide-react";
import { useTranslation } from "react-i18next";
import { serversApi } from "../api/serversApi";
import { AdminNavigation } from "../components/admin/AdminNavigation";
import { AdminServerMaintenancePanel } from "../components/admin/AdminServerMaintenancePanel";
import { PageHeader } from "../components/ui/PageHeader";
import { StatusBadge } from "../components/ui/StatusBadge";
import type { Server, ServerWorkloadCapability } from "../types/api";
import { getApiErrorMessage } from "../utils/errors";
import { formatCurrency } from "../utils/format";
import { useLocale } from "../i18n/useLocale";

type ServerForm = Omit<Server, "id">;
type WorkloadType = ServerWorkloadCapability["workloadType"];

const workloadTypes: WorkloadType[] = [
  "ModelTraining", "Inference", "Rendering", "DevelopmentCompilation",
  "DataProcessing", "WebBackendHosting", "GeneralCompute",
];

const initialForm: ServerForm = {
  cpu: "", gpu: "", ram: "", storage: "", os: "Ubuntu 22.04",
  pricePerHour: 20_000, pricePerDay: 360_000, isActive: true,
  operationalStatus: "Available", finderEligible: true,
  cpuCapabilityLevel: 50, gpuCapabilityLevel: 0, performanceTier: "Standard",
  workloadCapabilities: [{ workloadType: "GeneralCompute", suitabilityLevel: 3 }],
};

export function AdminServersPage() {
  const { t } = useTranslation();
  const { formatNumber } = useLocale();
  const [servers, setServers] = useState<Server[]>([]);
  const [form, setForm] = useState<ServerForm>(initialForm);
  const [editingId, setEditingId] = useState<number | null>(null);
  const [loading, setLoading] = useState(true);
  const [submitting, setSubmitting] = useState(false);
  const [deletingId, setDeletingId] = useState<number | null>(null);
  const [error, setError] = useState("");
  const [message, setMessage] = useState("");
  const [requestVersion, setRequestVersion] = useState(0);
  const isEditing = editingId !== null;

  useEffect(() => {
    let cancelled = false;
    const load = async () => {
      setLoading(true);
      setError("");
      try {
        const data = await serversApi.getAdminServers();
        if (!cancelled) setServers(data);
      } catch (loadError) {
        if (!cancelled) {
          setServers([]);
          setError(getApiErrorMessage(loadError, t("admin.servers.loadError")));
        }
      } finally {
        if (!cancelled) setLoading(false);
      }
    };
    void load();
    return () => { cancelled = true; };
  }, [requestVersion, t]);

  const refreshServers = async () => setServers(await serversApi.getAdminServers());
  const resetForm = () => { setEditingId(null); setForm(initialForm); };

  const onSubmit = async (event: React.FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    setSubmitting(true);
    setError("");
    setMessage("");
    try {
      if (editingId !== null) {
        await serversApi.updateServer(editingId, form);
        setMessage(t("admin.servers.updated", { id: formatNumber(editingId) }));
      } else {
        await serversApi.createServer(form);
        setMessage(t("admin.servers.created"));
      }
      resetForm();
      await refreshServers();
    } catch (submitError) {
      setError(getApiErrorMessage(submitError, t("admin.servers.saveError")));
    } finally {
      setSubmitting(false);
    }
  };

  const edit = (server: Server) => {
    const editable = { ...server } as Partial<Server>;
    delete editable.id;
    setEditingId(server.id);
    setForm(editable as ServerForm);
    setError("");
    setMessage("");
    window.scrollTo({ top: 0, behavior: "auto" });
  };

  const remove = async (id: number) => {
    setDeletingId(id);
    setError("");
    setMessage("");
    try {
      await serversApi.deleteServer(id);
      setMessage(t("admin.servers.deactivated", { id: formatNumber(id) }));
      await refreshServers();
    } catch (deleteError) {
      setError(getApiErrorMessage(deleteError, t("admin.servers.deactivateError")));
    } finally {
      setDeletingId(null);
    }
  };

  const updateOperationalStatus = (status: Server["operationalStatus"]) => {
    setForm({ ...form, operationalStatus: status, isActive: status !== "Disabled" });
  };

  const updateCapability = (workloadType: WorkloadType, enabled: boolean, level = 3) => {
    setForm((current) => ({
      ...current,
      workloadCapabilities: enabled
        ? [...current.workloadCapabilities.filter((item) => item.workloadType !== workloadType), { workloadType, suitabilityLevel: level }]
        : current.workloadCapabilities.filter((item) => item.workloadType !== workloadType),
    }));
  };

  return (
    <div className="page-stack">
      <AdminNavigation />
      <PageHeader eyebrow={t("admin.common.eyebrow")} title={t("admin.servers.title")} description={t("admin.servers.description")} icon={Boxes} actions={!loading ? <span className="badge-brand">{t("admin.servers.managedCount", { count: servers.length, formattedCount: formatNumber(servers.length) })}</span> : undefined} />

      <section className="card" aria-labelledby="server-editor-title">
        <div className="flex items-start gap-3 border-b border-border-subtle pb-5">
          <span className="icon-tile"><ServerIcon aria-hidden="true" size={19} /></span>
          <div><p className="section-kicker">{t("admin.servers.editor")}</p><h2 id="server-editor-title" className="mt-1 card-title">{isEditing ? t("admin.servers.editTitle", { id: formatNumber(editingId) }) : t("admin.servers.addTitle")}</h2><p className="mt-1 text-sm text-ink-500">{t("admin.servers.editorCopy")}</p></div>
        </div>
        {(error || message) && <div className="mt-5" aria-live="polite">{error && <div className="alert-error flex gap-2.5" role="alert"><AlertCircle aria-hidden="true" className="mt-0.5" size={17} /><p>{error}</p></div>}{message && <div className="alert-success flex gap-2.5" role="status"><CheckCircle2 aria-hidden="true" className="mt-0.5" size={17} /><p>{message}</p></div>}</div>}

        <form className="mt-6 space-y-7" onSubmit={onSubmit}>
          <fieldset className="grid gap-4 md:grid-cols-2 xl:grid-cols-3">
            <legend className="mb-4 text-sm font-semibold text-ink-900">{t("admin.servers.hardwareSection")}</legend>
            <label className="field"><span>CPU</span><input dir="auto" className="input" value={form.cpu} onChange={(event) => setForm({ ...form, cpu: event.target.value })} placeholder={t("admin.servers.cpuPlaceholder")} required disabled={submitting} /></label>
            <label className="field"><span>GPU</span><input dir="auto" className="input" value={form.gpu} onChange={(event) => setForm({ ...form, gpu: event.target.value })} placeholder={t("admin.servers.gpuPlaceholder")} required disabled={submitting} /></label>
            <label className="field"><span>{t("admin.servers.memory")}</span><input dir="auto" className="input" value={form.ram} onChange={(event) => setForm({ ...form, ram: event.target.value })} placeholder="64GB" required disabled={submitting} /></label>
            <label className="field"><span>{t("admin.servers.storage")}</span><input dir="auto" className="input" value={form.storage} onChange={(event) => setForm({ ...form, storage: event.target.value })} placeholder="1TB NVMe" required disabled={submitting} /></label>
            <label className="field"><span>{t("admin.servers.os")}</span><input dir="auto" className="input" value={form.os} onChange={(event) => setForm({ ...form, os: event.target.value })} required disabled={submitting} /></label>
            <label className="field"><span>{t("admin.servers.performanceTier")}</span><select className="select" value={form.performanceTier} onChange={(event) => setForm({ ...form, performanceTier: event.target.value as Server["performanceTier"] })} disabled={submitting}>{(["Entry", "Standard", "High", "Extreme"] as const).map((tier) => <option key={tier} value={tier}>{t(`admin.servers.tiers.${tier}`)}</option>)}</select></label>
          </fieldset>

          <fieldset className="grid gap-4 border-t border-border-subtle pt-6 md:grid-cols-2 xl:grid-cols-3">
            <legend className="mb-4 text-sm font-semibold text-ink-900">{t("admin.servers.pricingAvailabilitySection")}</legend>
            <label className="field"><span>{t("admin.servers.hourlyPrice")}</span><input dir="ltr" className="input text-left" type="number" min="1000" step="1000" value={form.pricePerHour} onChange={(event) => setForm({ ...form, pricePerHour: Number(event.target.value) })} required disabled={submitting} /></label>
            <label className="field"><span>{t("admin.servers.dailyPrice")}</span><input dir="ltr" className="input text-left" type="number" min="1000" step="1000" value={form.pricePerDay} onChange={(event) => setForm({ ...form, pricePerDay: Number(event.target.value) })} required disabled={submitting} /></label>
            <label className="field"><span>{t("admin.servers.operationalStatus")}</span><select className="select" value={form.operationalStatus} onChange={(event) => updateOperationalStatus(event.target.value as Server["operationalStatus"])} disabled={submitting}>{(["Available", "TemporarilyUnavailable", "Maintenance", "Disabled"] as const).map((status) => <option key={status} value={status}>{t(`admin.servers.statuses.${status}`)}</option>)}</select></label>
          </fieldset>

          <fieldset className="border-t border-border-subtle pt-6">
            <legend className="mb-2 text-sm font-semibold text-ink-900">{t("admin.servers.finderSection")}</legend>
            <p className="mb-4 max-w-3xl text-sm text-ink-500">{t("admin.servers.finderCopy")}</p>
            <div className="grid gap-4 md:grid-cols-3">
              <label className="flex min-h-11 items-center gap-3 rounded-control border border-border-subtle bg-surface-muted/55 px-4 text-sm font-semibold text-ink-700"><input type="checkbox" checked={form.finderEligible} onChange={(event) => setForm({ ...form, finderEligible: event.target.checked })} disabled={submitting} /><span>{t("admin.servers.finderEligible")}</span></label>
              <label className="field"><span>{t("admin.servers.cpuCapability")}</span><input className="input" type="number" min="0" max="100" value={form.cpuCapabilityLevel} onChange={(event) => setForm({ ...form, cpuCapabilityLevel: Number(event.target.value) })} disabled={submitting} /></label>
              <label className="field"><span>{t("admin.servers.gpuCapability")}</span><input className="input" type="number" min="0" max="100" value={form.gpuCapabilityLevel} onChange={(event) => setForm({ ...form, gpuCapabilityLevel: Number(event.target.value) })} disabled={submitting} /></label>
            </div>
            <div className="mt-4 grid gap-3 sm:grid-cols-2 xl:grid-cols-3">
              {workloadTypes.map((workloadType) => {
                const capability = form.workloadCapabilities.find((item) => item.workloadType === workloadType);
                return <div key={workloadType} className="rounded-control border border-border-subtle bg-white p-3"><label className="flex items-center gap-2 text-sm font-semibold text-ink-800"><input type="checkbox" checked={Boolean(capability)} onChange={(event) => updateCapability(workloadType, event.target.checked)} disabled={submitting} /><span>{t(`admin.servers.workloads.${workloadType}`)}</span></label>{capability && <label className="mt-3 flex items-center justify-between gap-3 text-xs text-ink-500"><span>{t("admin.servers.suitability")}</span><select className="select min-h-9 w-24 py-1.5" value={capability.suitabilityLevel} onChange={(event) => updateCapability(workloadType, true, Number(event.target.value))} disabled={submitting}>{[1, 2, 3, 4, 5].map((level) => <option key={level} value={level}>{formatNumber(level)} / {formatNumber(5)}</option>)}</select></label>}</div>;
              })}
            </div>
          </fieldset>

          <div className="flex flex-col gap-2 border-t border-border-subtle pt-6 sm:flex-row sm:justify-end">{isEditing && <button className="btn-secondary" type="button" onClick={resetForm} disabled={submitting}><X aria-hidden="true" size={16} />{t("actions.cancel")}</button>}<button className="btn-primary" type="submit" disabled={submitting}>{submitting ? <LoaderCircle aria-hidden="true" className="animate-spin" size={17} /> : isEditing ? <Pencil aria-hidden="true" size={17} /> : <Plus aria-hidden="true" size={17} />}{submitting ? t("admin.servers.saving") : isEditing ? t("admin.servers.update") : t("admin.servers.create")}</button></div>
        </form>
      </section>

      {!loading && servers.length > 0 && <AdminServerMaintenancePanel servers={servers} />}

      <section aria-labelledby="managed-servers-title">
        <div className="mb-5"><p className="section-kicker">{t("admin.servers.records")}</p><h2 id="managed-servers-title" className="mt-1 text-2xl font-semibold tracking-[-0.03em] text-ink-950">{t("admin.servers.configurations")}</h2></div>
        {loading ? <div className="space-y-3" role="status" aria-label={t("admin.servers.loading")}><div className="skeleton h-20 rounded-card" /><div className="skeleton h-20 rounded-card" /></div> : error && servers.length === 0 ? <div className="state-panel" role="alert"><span className="icon-tile-neutral"><AlertCircle aria-hidden="true" size={21} /></span><h2 className="mt-4 card-title">{t("admin.servers.unavailable")}</h2><p className="mt-2 max-w-md body-copy">{error}</p><button type="button" className="btn-primary mt-5" onClick={() => setRequestVersion((version) => version + 1)}><RotateCcw aria-hidden="true" size={16} />{t("actions.retry")}</button></div> : servers.length === 0 ? <div className="state-panel"><span className="icon-tile-neutral"><Boxes aria-hidden="true" size={21} /></span><h2 className="mt-4 card-title">{t("admin.servers.empty")}</h2><p className="mt-2 max-w-md body-copy">{t("admin.servers.emptyCopy")}</p></div> : <div className="grid gap-3 xl:grid-cols-2">{servers.map((server) => <article key={server.id} className="card-compact"><div className="flex items-start justify-between gap-3"><div className="min-w-0"><p className="section-kicker">{t("server.labels.serverNumber", { id: formatNumber(server.id) })}</p><h3 dir="auto" className="mt-1 truncate font-semibold text-ink-950">{server.gpu !== "None" ? server.gpu : server.cpu}</h3><p dir="auto" className="mt-1 truncate text-xs text-ink-500">{server.cpu}</p></div><StatusBadge tone={server.operationalStatus === "Available" ? "success" : server.operationalStatus === "Disabled" ? "neutral" : "warning"} showDot>{t(`admin.servers.statuses.${server.operationalStatus}`)}</StatusBadge></div><dl className="mt-4 grid grid-cols-2 gap-3 rounded-control bg-surface-muted/55 p-3 text-xs sm:grid-cols-4"><div><dt className="text-ink-500">{t("admin.servers.capacity")}</dt><dd dir="auto" className="bidi-auto mt-1 font-semibold text-ink-900">{server.ram} · {server.storage}</dd></div><div><dt className="text-ink-500">{t("admin.servers.performanceTier")}</dt><dd className="mt-1 font-semibold text-ink-900">{t(`admin.servers.tiers.${server.performanceTier}`)}</dd></div><div><dt className="text-ink-500">{t("admin.servers.hourly")}</dt><dd className="mt-1 font-semibold text-ink-900">{formatCurrency(server.pricePerHour)}</dd></div><div><dt className="text-ink-500">{t("admin.servers.finderSection")}</dt><dd className="mt-1 inline-flex items-center gap-1 font-semibold text-ink-900"><Gauge aria-hidden="true" size={13} />{server.finderEligible ? t("common.active") : t("common.inactive")}</dd></div></dl><div className="mt-4 flex flex-wrap gap-2">{server.workloadCapabilities.map((capability) => <span key={capability.workloadType} className="badge-neutral">{t(`admin.servers.workloads.${capability.workloadType}`)} · {formatNumber(capability.suitabilityLevel)}/{formatNumber(5)}</span>)}</div><div className="mt-4 grid grid-cols-2 gap-2"><button className="btn-secondary" type="button" onClick={() => edit(server)}><Pencil aria-hidden="true" size={15} />{t("actions.edit")}</button><button className="btn-danger" type="button" onClick={() => void remove(server.id)} disabled={!server.isActive || deletingId === server.id}>{deletingId === server.id ? <LoaderCircle aria-hidden="true" className="animate-spin" size={15} /> : <X aria-hidden="true" size={15} />}{t("admin.servers.deactivate")}</button></div></article>)}</div>}
      </section>
    </div>
  );
}
