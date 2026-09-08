import { useEffect, useRef, useState } from "react";
import { useTranslation } from "react-i18next";
import {
  AlertCircle,
  CheckCircle2,
  LoaderCircle,
  MessageSquareQuote,
  Pencil,
  Plus,
  Save,
  Trash2,
  X,
} from "lucide-react";
import { adminSupportApi } from "../../../api/adminSupportApi";
import type { SupportQuickReply, UpsertSupportQuickReplyRequest } from "../../../types/support";
import { getApiErrorMessage } from "../../../utils/errors";
import {
  isAmbiguousMutationFailure,
  reconcileCreatedQuickReply,
} from "../../../utils/mutationReconciliation";
import { BidiText } from "../../support/BidiText";
import { useLocale } from "../../../i18n/useLocale";

interface QuickReplyManagerProps {
  open: boolean;
  replies: SupportQuickReply[];
  onClose: () => void;
  onChanged: () => Promise<void>;
}

const emptyDraft: UpsertSupportQuickReplyRequest = {
  title: "",
  content: "",
  category: "",
  isActive: true,
  sortOrder: 0,
};

export function QuickReplyManager({ open, replies, onClose, onChanged }: QuickReplyManagerProps) {
  const { t } = useTranslation();
  const { formatNumber } = useLocale();
  const closeRef = useRef<HTMLButtonElement>(null);
  const dialogRef = useRef<HTMLElement>(null);
  const onCloseRef = useRef(onClose);
  const returnFocusRef = useRef<HTMLElement | null>(null);
  const [editingId, setEditingId] = useState<string | null>(null);
  const [draft, setDraft] = useState<UpsertSupportQuickReplyRequest>(emptyDraft);
  const [saving, setSaving] = useState(false);
  const [deactivatingId, setDeactivatingId] = useState<string | null>(null);
  const [error, setError] = useState("");
  const [message, setMessage] = useState("");

  useEffect(() => {
    onCloseRef.current = onClose;
  }, [onClose]);

  useEffect(() => {
    if (!open) {
      return;
    }
    returnFocusRef.current = document.activeElement instanceof HTMLElement ? document.activeElement : null;
    requestAnimationFrame(() => closeRef.current?.focus());
    const previousOverflow = document.body.style.overflow;
    document.body.style.overflow = "hidden";
    const handleKeyDown = (event: KeyboardEvent) => {
      if (event.key === "Escape") {
        onCloseRef.current();
        return;
      }
      if (event.key === "Tab" && dialogRef.current) {
        const focusable = [...dialogRef.current.querySelectorAll<HTMLElement>(
          'button:not([disabled]), textarea:not([disabled]), input:not([disabled]), select:not([disabled]), [tabindex]:not([tabindex="-1"])',
        )].filter((element) => !element.hasAttribute("hidden"));
        const first = focusable[0];
        const last = focusable.at(-1);
        if (first && last && event.shiftKey && document.activeElement === first) {
          event.preventDefault();
          last.focus();
        } else if (first && last && !event.shiftKey && document.activeElement === last) {
          event.preventDefault();
          first.focus();
        }
      }
    };
    window.addEventListener("keydown", handleKeyDown);
    return () => {
      document.body.style.overflow = previousOverflow;
      window.removeEventListener("keydown", handleKeyDown);
      returnFocusRef.current?.focus({ preventScroll: true });
    };
  }, [open]);

  if (!open) {
    return null;
  }

  const resetDraft = () => {
    setEditingId(null);
    setDraft(emptyDraft);
    setError("");
  };

  const editReply = (reply: SupportQuickReply) => {
    setEditingId(reply.id);
    setDraft({
      title: reply.title,
      content: reply.content,
      category: reply.category ?? "",
      isActive: reply.isActive,
      sortOrder: reply.sortOrder,
    });
    setError("");
    setMessage("");
  };

  const save = async (event: React.FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    if (!draft.title.trim() || !draft.content.trim()) {
      return;
    }
    setSaving(true);
    setError("");
    setMessage("");
    const request: UpsertSupportQuickReplyRequest = {
      ...draft,
      title: draft.title.trim(),
      content: draft.content.trim(),
      category: draft.category?.trim() || undefined,
      sortOrder: Number(draft.sortOrder),
    };
    const baselineIds = new Set(replies.map((reply) => reply.id));
    try {
      if (editingId) {
        await adminSupportApi.updateQuickReply(editingId, request);
        setMessage(t("support.quickReplies.updated"));
      } else {
        await adminSupportApi.createQuickReply(request);
        setMessage(t("support.quickReplies.created"));
      }
      resetDraft();
      await onChanged();
    } catch (saveError) {
      if (!editingId && isAmbiguousMutationFailure(saveError)) {
        try {
          const authoritativeReplies = await adminSupportApi.getQuickReplies(true);
          const reconciled = reconcileCreatedQuickReply(
            baselineIds,
            request,
            authoritativeReplies,
          );
          if (reconciled) {
            setMessage(t("support.quickReplies.created"));
            resetDraft();
            await onChanged();
            return;
          }
        } catch {
          // Preserve the original mutation error when reconciliation is unavailable.
        }
      }
      setError(getApiErrorMessage(saveError, t("support.quickReplies.saveError")));
    } finally {
      setSaving(false);
    }
  };

  const deactivate = async (replyId: string) => {
    setDeactivatingId(replyId);
    setError("");
    setMessage("");
    try {
      await adminSupportApi.deactivateQuickReply(replyId);
      setMessage(t("support.quickReplies.deactivated"));
      if (editingId === replyId) {
        resetDraft();
      }
      await onChanged();
    } catch (deactivateError) {
      setError(getApiErrorMessage(deactivateError, t("support.quickReplies.deactivateError")));
    } finally {
      setDeactivatingId(null);
    }
  };

  return (
    <div className="fixed inset-0 z-[100] flex items-end justify-center bg-ink-950/45 p-0 backdrop-blur-sm sm:items-center sm:p-6" role="presentation">
      <section ref={dialogRef} role="dialog" aria-modal="true" aria-labelledby="quick-replies-title" className="flex max-h-[92dvh] w-full max-w-4xl flex-col overflow-hidden rounded-t-panel border border-white/70 bg-surface-raised shadow-floating sm:rounded-panel">
        <header className="flex items-center justify-between gap-4 border-b border-border-subtle bg-white px-5 py-4 sm:px-6">
          <div className="flex items-center gap-3">
            <span className="icon-tile"><MessageSquareQuote aria-hidden="true" size={18} /></span>
            <div>
              <p className="section-kicker">{t("support.quickReplies.eyebrow")}</p>
              <h2 id="quick-replies-title" className="mt-0.5 text-lg font-semibold text-ink-950">{t("support.quickReplies.title")}</h2>
            </div>
          </div>
          <button ref={closeRef} type="button" className="btn-icon size-10 min-h-10" onClick={onClose} aria-label={t("support.quickReplies.closeAria")}>
            <X aria-hidden="true" size={18} />
          </button>
        </header>

        <div className="support-message-scroll grid min-h-0 flex-1 overflow-y-auto lg:grid-cols-[1fr_1.05fr]">
          <section className="border-b border-border-subtle p-5 sm:p-6 lg:border-b-0 lg:border-e" aria-labelledby="quick-reply-form-title">
            <div className="flex items-center justify-between gap-3">
              <h3 id="quick-reply-form-title" className="text-sm font-semibold text-ink-900">{editingId ? t("support.quickReplies.editTitle") : t("support.quickReplies.createTitle")}</h3>
              {editingId && (
                <button type="button" className="text-xs font-semibold text-brand-700 hover:text-brand-800" onClick={resetDraft}>{t("support.quickReplies.createInstead")}</button>
              )}
            </div>

            <form className="mt-5 space-y-4" onSubmit={save}>
              <label className="field">
                <span>{t("support.quickReplies.titleLabel")}</span>
                <input dir="auto" className="input support-composer-textarea" value={draft.title} onChange={(event) => setDraft((current) => ({ ...current, title: event.target.value }))} maxLength={120} required disabled={saving} />
              </label>
              <label className="field">
                <span>{t("support.quickReplies.contentLabel")}</span>
                <textarea dir="auto" className="input support-composer-textarea min-h-36 font-reading" value={draft.content} onChange={(event) => setDraft((current) => ({ ...current, content: event.target.value }))} maxLength={2_000} required disabled={saving} />
                <span className="field-hint text-end">{formatNumber(draft.content.length)}/{formatNumber(2_000)}</span>
              </label>
              <div className="grid gap-4 sm:grid-cols-[1fr_7rem]">
                <label className="field">
                  <span>{t("support.quickReplies.categoryLabel")} <span className="font-normal text-ink-500">({t("common.optional")})</span></span>
                  <input dir="auto" className="input support-composer-textarea" value={draft.category ?? ""} onChange={(event) => setDraft((current) => ({ ...current, category: event.target.value }))} maxLength={80} disabled={saving} />
                </label>
                <label className="field">
                  <span>{t("support.quickReplies.sortOrder")}</span>
                  <input className="input" type="number" min={0} max={10_000} value={draft.sortOrder} onChange={(event) => setDraft((current) => ({ ...current, sortOrder: Number(event.target.value) }))} disabled={saving} />
                </label>
              </div>
              <label className="flex min-h-11 items-center gap-3 rounded-control border border-border-subtle bg-white px-3.5 text-sm font-medium text-ink-700">
                <input type="checkbox" checked={draft.isActive} onChange={(event) => setDraft((current) => ({ ...current, isActive: event.target.checked }))} disabled={saving} />
                {t("support.quickReplies.available")}
              </label>

              {error && <div className="alert-error flex items-start gap-2 text-sm" role="alert"><AlertCircle aria-hidden="true" className="mt-0.5" size={15} />{error}</div>}
              {message && <div className="alert-success flex items-start gap-2 text-sm" role="status"><CheckCircle2 aria-hidden="true" className="mt-0.5" size={15} />{message}</div>}

              <button type="submit" className="btn-primary w-full" disabled={saving || !draft.title.trim() || !draft.content.trim()}>
                {saving ? <LoaderCircle aria-hidden="true" className="animate-spin" size={16} /> : editingId ? <Save aria-hidden="true" size={16} /> : <Plus aria-hidden="true" size={16} />}
                {saving ? t("support.quickReplies.saving") : editingId ? t("support.quickReplies.saveChanges") : t("support.quickReplies.create")}
              </button>
            </form>
          </section>

          <section className="p-5 sm:p-6" aria-labelledby="saved-quick-replies-title">
            <div className="flex items-center justify-between gap-3">
              <h3 id="saved-quick-replies-title" className="text-sm font-semibold text-ink-900">{t("support.quickReplies.saved")}</h3>
              <span className="badge">{t("support.quickReplies.total", { count: replies.length, formattedCount: formatNumber(replies.length) })}</span>
            </div>
            {replies.length === 0 ? (
              <div className="mt-5 rounded-control border border-dashed border-border-strong p-8 text-center text-sm leading-6 text-ink-500">{t("support.quickReplies.empty")}</div>
            ) : (
              <div className="mt-4 space-y-3">
                {replies.map((reply) => (
                  <article key={reply.id} className="rounded-control border border-border-subtle bg-white p-4 shadow-control">
                    <div className="flex min-w-0 items-start justify-between gap-3">
                      <div className="min-w-0">
                        <BidiText text={reply.title} className="block truncate text-sm font-semibold text-ink-900" />
                        <div className="mt-1.5 flex flex-wrap gap-1.5">
                          <span className={reply.isActive ? "badge-success" : "badge"}>{reply.isActive ? t("support.quickReplies.active") : t("support.quickReplies.inactive")}</span>
                          {reply.category && <BidiText text={reply.category} className="badge-brand max-w-40 truncate" />}
                        </div>
                      </div>
                      <span className="text-[10px] font-semibold text-ink-500">#{formatNumber(reply.sortOrder)}</span>
                    </div>
                    <BidiText text={reply.content} className="mt-3 block line-clamp-3 whitespace-pre-wrap font-reading text-xs leading-5 text-ink-500" />
                    <div className="mt-4 flex items-center gap-2 border-t border-border-subtle pt-3">
                      <button type="button" className="btn-secondary min-h-9 flex-1 px-3 py-1.5 text-xs" onClick={() => editReply(reply)}>
                        <Pencil aria-hidden="true" size={13} />
                        {t("support.quickReplies.edit")}
                      </button>
                      {reply.isActive && (
                        <button type="button" className="btn-ghost min-h-9 px-3 py-1.5 text-xs text-status-danger hover:bg-red-50 hover:text-status-danger" onClick={() => void deactivate(reply.id)} disabled={deactivatingId === reply.id}>
                          {deactivatingId === reply.id ? <LoaderCircle aria-hidden="true" className="animate-spin" size={13} /> : <Trash2 aria-hidden="true" size={13} />}
                          {t("support.quickReplies.deactivate")}
                        </button>
                      )}
                    </div>
                  </article>
                ))}
              </div>
            )}
          </section>
        </div>
      </section>
    </div>
  );
}
