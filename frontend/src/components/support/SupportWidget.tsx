import { useEffect, useRef, useState } from "react";
import {
  ArrowLeft,
  Bot,
  Headphones,
  History,
  LoaderCircle,
  LockKeyhole,
  MessageCircle,
  MessageSquarePlus,
  Send,
  Sparkles,
  UserRoundCheck,
  WifiOff,
  X,
} from "lucide-react";
import { Link, useLocation } from "react-router-dom";
import { useTranslation } from "react-i18next";
import { useAuth } from "../../auth/useAuth";
import { useSupport } from "../../support/useSupport";
import type { SupportConversationStatus } from "../../types/support";
import { getApiErrorMessage } from "../../utils/errors";
import { SUPPORT_CATEGORIES, getSupportCategoryLabel, getSupportStatusLabel } from "../../utils/support";
import { SupportConversationHistory } from "./SupportConversationHistory";
import { SupportMessageList, type PendingSupportMessage } from "./SupportMessageList";
import { SupportStatusBadge } from "./SupportStatusBadge";
import { useLocale } from "../../i18n/useLocale";

const SUPPORT_INTRO_STORAGE_KEY = "hardwarereserve.support-intro-dismissed";
const SUPPORT_INTRO_DURATION_MS = 8_000;

function shouldShowSupportIntro(): boolean {
  try {
    return window.localStorage.getItem(SUPPORT_INTRO_STORAGE_KEY) !== "1";
  } catch {
    return true;
  }
}

function persistSupportIntroDismissal(): void {
  try {
    window.localStorage.setItem(SUPPORT_INTRO_STORAGE_KEY, "1");
  } catch {
    // The callout still dismisses for this page when storage is unavailable.
  }
}

function ConversationStateNotice({ status }: { status: SupportConversationStatus }) {
  const { t } = useTranslation();
  if (status === "AI_ACTIVE") {
    return null;
  }

  const config = {
    WAITING_FOR_ADMIN: {
      icon: Headphones,
      className: "border-amber-200 bg-amber-50 text-amber-900",
      text: t("support.widget.waitingNotice"),
    },
    ADMIN_ACTIVE: {
      icon: UserRoundCheck,
      className: "border-blue-200 bg-blue-50 text-blue-900",
      text: t("support.widget.adminNotice"),
    },
    RESOLVED: {
      icon: Sparkles,
      className: "border-emerald-200 bg-emerald-50 text-emerald-900",
      text: t("support.widget.resolvedNotice"),
    },
    CLOSED: {
      icon: LockKeyhole,
      className: "border-border-subtle bg-surface-muted text-ink-700",
      text: t("support.widget.closedNotice"),
    },
  }[status];

  const Icon = config.icon;
  return (
    <div className={`mx-4 mt-3 flex items-start gap-2.5 rounded-control border px-3 py-2.5 text-xs leading-5 sm:mx-5 ${config.className}`} role="status">
      <Icon aria-hidden="true" className="mt-0.5 shrink-0" size={14} />
      <p>{config.text}</p>
    </div>
  );
}

function NewConversationView({
  onStart,
  loading,
  error,
  initialMessage,
}: {
  onStart: (message: string, category?: string) => Promise<void>;
  loading: boolean;
  error: string;
  initialMessage: string;
}) {
  const { t } = useTranslation();
  const { formatNumber } = useLocale();
  const { isAuthenticated } = useAuth();
  const location = useLocation();
  const [category, setCategory] = useState("");
  const [message, setMessage] = useState(initialMessage);

  useEffect(() => {
    setMessage(initialMessage);
  }, [initialMessage]);

  const submit = async (event: React.FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    const trimmed = message.trim();
    if (!trimmed || loading) {
      return;
    }
    await onStart(trimmed, category || undefined);
    setMessage("");
  };

  return (
    <div className="support-message-scroll flex-1 overflow-y-auto px-5 py-6">
      <div className="mx-auto max-w-sm">
        <div className="flex size-14 items-center justify-center rounded-2xl border border-brand-200 bg-brand-50 text-brand-700 shadow-control">
          <Bot aria-hidden="true" size={25} />
        </div>
        <h3 className="mt-5 text-xl font-semibold tracking-[-0.03em] text-ink-950">{t("support.widget.welcomeTitle")}</h3>
        <p className="mt-2 text-sm leading-6 text-ink-500">
          {t("support.widget.welcomeCopy")}
        </p>

        {!isAuthenticated && (
          <div className="mt-4 rounded-control border border-brand-100 bg-brand-50/70 p-3 text-xs leading-5 text-ink-600">
            {t("support.widget.guestPrefix")} {" "}
            <Link
              to={`/login?returnUrl=${encodeURIComponent(`${location.pathname}${location.search}`)}`}
              className="font-semibold text-brand-700 underline underline-offset-2"
            >
              {t("support.widget.guestLogin")}
            </Link>
            .
          </div>
        )}

        <form className="mt-6 space-y-5" onSubmit={submit}>
          <fieldset>
            <legend className="text-xs font-semibold text-ink-600">
              {t("support.widget.topic")} <span className="font-normal text-ink-500">({t("common.optional")})</span>
            </legend>
            <div className="mt-2 flex flex-wrap gap-2">
              {SUPPORT_CATEGORIES.map((item) => (
                <button
                  key={item}
                  type="button"
                  aria-pressed={category === item}
                  onClick={() => setCategory((current) => (current === item ? "" : item))}
                  disabled={loading}
                  className={`min-h-9 rounded-pill border px-3 py-1.5 text-xs font-semibold transition duration-base ${category === item ? "border-brand-600 bg-brand-600 text-white shadow-control" : "border-border-subtle bg-white text-ink-600 hover:border-brand-200 hover:bg-brand-50 hover:text-brand-800"}`}
                >
                  {getSupportCategoryLabel(item)}
                </button>
              ))}
            </div>
          </fieldset>

          <label className="field">
            <span>{t("support.widget.question")}</span>
            <textarea
              className="input support-composer-textarea min-h-28 font-reading"
              dir="auto"
              value={message}
              onChange={(event) => setMessage(event.target.value)}
              placeholder={t("support.widget.questionPlaceholder")}
              maxLength={4_000}
              autoFocus
              disabled={loading}
              required
            />
            <span className="flex items-center justify-between gap-3 text-xs font-normal text-ink-500">
              <span>{t("support.widget.categoryOptional")}</span>
              <span>{formatNumber(message.length)}/{formatNumber(4_000)}</span>
            </span>
          </label>

          {error && <div className="alert-error text-sm" role="alert">{error}</div>}

          <button type="submit" className="btn-primary w-full" disabled={loading || !message.trim()}>
            {loading ? <LoaderCircle aria-hidden="true" className="animate-spin" size={17} /> : <Send aria-hidden="true" size={17} />}
            {loading ? t("support.widget.starting") : t("support.widget.start")}
          </button>
        </form>
      </div>
    </div>
  );
}

function ConversationComposer({
  status,
  sending,
  onSend,
  onRequestAdmin,
  requestingAdmin,
}: {
  status: SupportConversationStatus;
  sending: boolean;
  onSend: (content: string) => Promise<void>;
  onRequestAdmin: () => Promise<void>;
  requestingAdmin: boolean;
}) {
  const { t } = useTranslation();
  const { formatNumber } = useLocale();
  const [content, setContent] = useState("");
  const isClosed = status === "CLOSED";

  const submit = async (event?: React.FormEvent<HTMLFormElement>) => {
    event?.preventDefault();
    const trimmed = content.trim();
    if (!trimmed || sending || isClosed) {
      return;
    }
    setContent("");
    await onSend(trimmed);
  };

  return (
    <div className="border-t border-border-subtle bg-white px-3 py-3 sm:px-4">
      {status === "AI_ACTIVE" && (
        <div className="mb-2 flex items-center justify-between gap-3 px-1">
          <p className="text-[11px] leading-4 text-ink-500">{t("support.widget.aiFirst")}</p>
          <button
            type="button"
            className="inline-flex min-h-8 items-center gap-1.5 rounded-pill px-2.5 text-[11px] font-semibold text-brand-700 hover:bg-brand-50 disabled:opacity-50"
            onClick={() => void onRequestAdmin()}
            disabled={requestingAdmin || sending}
          >
            {requestingAdmin ? <LoaderCircle aria-hidden="true" className="animate-spin" size={12} /> : <Headphones aria-hidden="true" size={12} />}
            {t("support.widget.requestHuman")}
          </button>
        </div>
      )}

      <form onSubmit={submit} className="flex items-end gap-2">
        <label className="sr-only" htmlFor="support-message-composer">{t("support.widget.message")}</label>
        <textarea
          id="support-message-composer"
          dir="auto"
          rows={1}
          className="input support-composer-textarea support-composer-compact max-h-32 min-h-11 flex-1 resize-none py-2.5 font-reading"
          value={content}
          onChange={(event) => setContent(event.target.value)}
          onKeyDown={(event) => {
            if (event.key === "Enter" && !event.shiftKey && !event.nativeEvent.isComposing) {
              event.preventDefault();
              void submit();
            }
          }}
          placeholder={isClosed ? t("support.widget.closedPlaceholder") : status === "RESOLVED" ? t("support.widget.reopenPlaceholder") : t("support.widget.messagePlaceholder")}
          maxLength={4_000}
          disabled={isClosed || sending}
        />
        <button
          type="submit"
          className="btn-primary size-11 min-h-11 shrink-0 px-0"
          aria-label={t("support.widget.sendAria")}
          disabled={isClosed || sending || !content.trim()}
        >
          {sending ? <LoaderCircle aria-hidden="true" className="animate-spin" size={17} /> : <Send aria-hidden="true" size={17} />}
        </button>
      </form>
      {!isClosed && content.length > 3_600 && (
        <p className="mt-1 text-end text-[10px] font-medium text-ink-500">{formatNumber(content.length)}/{formatNumber(4_000)}</p>
      )}
    </div>
  );
}

export function SupportWidget() {
  const { t } = useTranslation();
  const { formatNumber } = useLocale();
  const { isAdmin } = useAuth();
  const {
    isOpen,
    view,
    unreadCount,
    realtimeState,
    activeConversation,
    messages,
    messagesLoading,
    messagesLoadingOlder,
    messagesError,
    messagesHasMore,
    newConversationDraft,
    openSupport,
    closeSupport,
    showHistory,
    showNewConversation,
    loadOlderMessages,
    createConversation,
    sendMessage,
    requestAdministrator,
  } = useSupport();
  const launcherRef = useRef<HTMLButtonElement>(null);
  const closeButtonRef = useRef<HTMLButtonElement>(null);
  const panelRef = useRef<HTMLElement>(null);
  const [pending, setPending] = useState<PendingSupportMessage | null>(null);
  const [startLoading, setStartLoading] = useState(false);
  const [startError, setStartError] = useState("");
  const [requestingAdmin, setRequestingAdmin] = useState(false);
  const [actionError, setActionError] = useState("");
  const [showLauncherIntro, setShowLauncherIntro] = useState(shouldShowSupportIntro);

  useEffect(() => {
    if (!showLauncherIntro || isOpen) {
      return;
    }

    const timeout = window.setTimeout(() => {
      setShowLauncherIntro(false);
      persistSupportIntroDismissal();
    }, SUPPORT_INTRO_DURATION_MS);

    return () => window.clearTimeout(timeout);
  }, [isOpen, showLauncherIntro]);

  useEffect(() => {
    if (!isOpen) {
      return;
    }

    requestAnimationFrame(() => closeButtonRef.current?.focus({ preventScroll: true }));
    const handleKeyDown = (event: KeyboardEvent) => {
      if (event.key === "Escape") {
        closeSupport();
        requestAnimationFrame(() => launcherRef.current?.focus());
        return;
      }
      if (event.key === "Tab" && mobileMedia.matches && panelRef.current) {
        const focusable = [...panelRef.current.querySelectorAll<HTMLElement>(
          'a[href], button:not([disabled]), textarea:not([disabled]), input:not([disabled]), select:not([disabled]), [tabindex]:not([tabindex="-1"])',
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
    const mobileMedia = window.matchMedia("(max-width: 639px)");
    const previousOverflow = document.body.style.overflow;
    const updateBodyLock = () => {
      document.body.style.overflow = mobileMedia.matches ? "hidden" : previousOverflow;
    };
    updateBodyLock();
    mobileMedia.addEventListener("change", updateBodyLock);
    window.addEventListener("keydown", handleKeyDown);
    return () => {
      window.removeEventListener("keydown", handleKeyDown);
      mobileMedia.removeEventListener("change", updateBodyLock);
      document.body.style.overflow = previousOverflow;
    };
  }, [closeSupport, isOpen]);

  if (isAdmin) {
    return null;
  }

  const submitMessage = async (content: string, existingClientId?: string) => {
    if (pending?.state === "sending") {
      return;
    }
    const clientMessageId = existingClientId ?? crypto.randomUUID();
    setActionError("");
    setPending({ content, clientMessageId, state: "sending" });
    try {
      await sendMessage(content, clientMessageId);
      setPending(null);
    } catch (error) {
      setPending({
        content,
        clientMessageId,
        state: "failed",
        error: getApiErrorMessage(error, t("support.widget.sendError")),
      });
    }
  };

  const startConversation = async (message: string, category?: string) => {
    setStartLoading(true);
    setStartError("");
    try {
      await createConversation(category);
      await submitMessage(message);
    } catch (error) {
      setStartError(getApiErrorMessage(error, t("support.widget.startError")));
    } finally {
      setStartLoading(false);
    }
  };

  const handleRequestAdmin = async () => {
    setRequestingAdmin(true);
    setActionError("");
    try {
      await requestAdministrator();
    } catch (error) {
      setActionError(getApiErrorMessage(error, t("support.widget.humanError")));
    } finally {
      setRequestingAdmin(false);
    }
  };

  const closeAndRestoreFocus = () => {
    closeSupport();
    requestAnimationFrame(() => launcherRef.current?.focus());
  };

  const dismissLauncherIntro = (restoreFocus = false) => {
    setShowLauncherIntro(false);
    persistSupportIntroDismissal();
    if (restoreFocus) {
      requestAnimationFrame(() => launcherRef.current?.focus());
    }
  };

  const openFromLauncher = () => {
    dismissLauncherIntro();
    openSupport();
  };

  const headerSubtitle =
    view === "history"
      ? t("support.widget.historySubtitle")
      : view === "new" || !activeConversation
        ? t("support.widget.newSubtitle")
        : getSupportStatusLabel(activeConversation.status);

  return (
    <>
      {isOpen && <div aria-hidden="true" className="overlay-enter fixed inset-0 z-[75] bg-ink-950/40 backdrop-blur-sm sm:hidden" />}

      {isOpen && (
        <section
          ref={panelRef}
          role="dialog"
          aria-labelledby="support-widget-title"
          aria-label={t("support.widget.dialogAria")}
          className="dialog-panel-enter fixed bottom-24 end-4 z-[80] flex h-[min(44rem,calc(100dvh-7rem))] w-[calc(100vw-2rem)] max-w-[26rem] flex-col overflow-hidden rounded-panel border border-white/70 bg-surface-raised shadow-floating max-sm:inset-0 max-sm:h-[100dvh] max-sm:w-full max-sm:max-w-none max-sm:rounded-none max-sm:border-0 sm:end-6"
        >
          <header className="relative overflow-hidden bg-surface-inverse px-4 py-4 text-white sm:px-5">
            <div aria-hidden="true" className="absolute -end-12 -top-16 size-40 rounded-full bg-brand-400/20 blur-3xl" />
            <div className="relative flex items-start justify-between gap-3">
              <div className="flex min-w-0 items-center gap-3">
                <span className="icon-tile-inverse size-10"><MessageCircle aria-hidden="true" size={18} /></span>
                <div className="min-w-0">
                  <h2 id="support-widget-title" className="truncate text-sm font-semibold text-white">HardwareReserve</h2>
                  <p className="mt-0.5 truncate text-[11px] text-ink-400">{t("support.widget.supportLabel")} · {headerSubtitle}</p>
                </div>
              </div>
              <div className="flex shrink-0 items-center gap-1">
                {view !== "history" && (
                  <button type="button" className="support-header-action" onClick={showHistory} aria-label={t("support.widget.viewConversations")}>
                    <History aria-hidden="true" size={16} />
                    <span className="hidden min-[390px]:inline">{t("support.widget.history")}</span>
                  </button>
                )}
                {view !== "new" && (
                  <button type="button" className="support-header-icon" onClick={showNewConversation} aria-label={t("support.widget.newConversationAria")}>
                    <MessageSquarePlus aria-hidden="true" size={17} />
                  </button>
                )}
                <button ref={closeButtonRef} type="button" className="support-header-icon" onClick={closeAndRestoreFocus} aria-label={t("support.widget.closeAria")}>
                  <X aria-hidden="true" size={18} />
                </button>
              </div>
            </div>
          </header>

          {view === "history" ? (
            <div className="min-h-0 flex-1 bg-surface-muted/40">
              <div className="flex items-center justify-between border-b border-border-subtle bg-white px-4 py-3">
                <button type="button" className="inline-flex min-h-9 items-center gap-1.5 text-xs font-semibold text-ink-600 hover:text-brand-700" onClick={() => activeConversation ? void openSupport("conversation") : showNewConversation()}>
                  <ArrowLeft aria-hidden="true" className="directional-icon" size={14} />
                  {t("support.widget.back")}
                </button>
                <button type="button" className="inline-flex min-h-9 items-center gap-1.5 text-xs font-semibold text-brand-700 hover:text-brand-800" onClick={showNewConversation}>
                  <MessageSquarePlus aria-hidden="true" size={14} />
                  {t("support.widget.newConversation")}
                </button>
              </div>
              <div className="h-[calc(100%-3.25rem)]"><SupportConversationHistory /></div>
            </div>
          ) : view === "new" || !activeConversation ? (
            <NewConversationView
              onStart={startConversation}
              loading={startLoading}
              error={startError}
              initialMessage={newConversationDraft}
            />
          ) : (
            <div className="flex min-h-0 flex-1 flex-col bg-surface-muted/35">
              <div className="flex flex-wrap items-center justify-between gap-2 border-b border-border-subtle bg-white px-4 py-2.5 sm:px-5">
                <SupportStatusBadge status={activeConversation.status} />
                {activeConversation.category && (
                  <span dir="auto" className="support-bidi max-w-[45%] truncate text-[11px] font-medium text-ink-500">{getSupportCategoryLabel(activeConversation.category)}</span>
                )}
              </div>

              {realtimeState === "reconnecting" || realtimeState === "disconnected" ? (
                <div className="flex items-center justify-center gap-2 border-b border-amber-200 bg-amber-50 px-4 py-2 text-[11px] font-medium text-amber-900" role="status">
                  <WifiOff aria-hidden="true" size={13} />
                  {realtimeState === "reconnecting" ? t("support.widget.reconnecting") : t("support.widget.paused")}
                </div>
              ) : null}

              <ConversationStateNotice status={activeConversation.status} />

              {(messagesError || actionError) && (
                <div className="mx-4 mt-3 rounded-control border border-status-danger/20 bg-red-50 px-3 py-2 text-xs leading-5 text-status-danger sm:mx-5" role="alert">
                  {actionError || messagesError}
                </div>
              )}

              <SupportMessageList
                key={activeConversation.id}
                messages={messages}
                loading={messagesLoading}
                hasMore={messagesHasMore}
                loadingOlder={messagesLoadingOlder}
                onLoadOlder={loadOlderMessages}
                perspective="user"
                pending={pending}
                onRetryPending={pending?.state === "failed" ? () => void submitMessage(pending.content, pending.clientMessageId) : undefined}
                aiProcessing={pending?.state === "sending" && activeConversation.status === "AI_ACTIVE"}
                emptyMessage={t("support.widget.emptyThread")}
              />

              {activeConversation.status === "CLOSED" ? (
                <div className="border-t border-border-subtle bg-white p-4">
                  <button type="button" className="btn-primary w-full" onClick={showNewConversation}>
                    <MessageSquarePlus aria-hidden="true" size={16} />
                    {t("support.widget.newConversation")}
                  </button>
                </div>
              ) : (
                <ConversationComposer
                  status={activeConversation.status}
                  sending={pending?.state === "sending"}
                  onSend={(content) => submitMessage(content)}
                  onRequestAdmin={handleRequestAdmin}
                  requestingAdmin={requestingAdmin}
                />
              )}
            </div>
          )}
        </section>
      )}

      {!isOpen && showLauncherIntro && (
        <aside className="support-launcher-intro fixed bottom-[5.5rem] end-4 z-[69] w-[min(18rem,calc(100vw-2rem))] rounded-card border border-border-subtle bg-white/95 p-4 shadow-floating backdrop-blur-xl sm:bottom-24 sm:end-6">
          <div className="flex items-start gap-3">
            <span className="icon-tile size-9">
              <Sparkles aria-hidden="true" size={16} />
            </span>
            <div className="min-w-0 flex-1">
              <p className="text-sm font-semibold text-ink-950">{t("support.widget.introTitle")}</p>
              <p className="mt-1 font-reading text-xs leading-5 text-ink-600">{t("support.widget.introCopy")}</p>
            </div>
            <button
              type="button"
              className="control-press -me-1 -mt-1 inline-flex size-8 items-center justify-center rounded-lg text-ink-500 hover:bg-surface-muted hover:text-ink-900"
              aria-label={t("support.widget.dismissIntro")}
              onClick={() => dismissLauncherIntro(true)}
            >
              <X aria-hidden="true" size={15} />
            </button>
          </div>
        </aside>
      )}

      {!isOpen && (
        <button
          ref={launcherRef}
          type="button"
          className="control-press group fixed bottom-5 end-4 z-[70] flex size-14 items-center justify-center rounded-2xl border border-white/20 bg-surface-inverse text-white shadow-floating transition duration-base hover:-translate-y-0.5 hover:bg-surface-inverse-raised hover:shadow-glow active:translate-y-0 sm:bottom-6 sm:end-6 sm:size-15"
          onClick={openFromLauncher}
          aria-label={unreadCount > 0 ? t("support.widget.launcherUnread", { count: unreadCount, formattedCount: formatNumber(unreadCount) }) : t("support.widget.launcher")}
        >
          <MessageCircle aria-hidden="true" size={24} className="transition-transform duration-base group-hover:scale-105" />
          {unreadCount > 0 && (
            <span dir="ltr" className="absolute -end-1.5 -top-1.5 inline-flex min-h-5 min-w-5 items-center justify-center rounded-pill border-2 border-white bg-status-danger px-1 text-[10px] font-bold text-white shadow-control">
              {unreadCount > 99 ? `${formatNumber(99)}+` : formatNumber(unreadCount)}
            </span>
          )}
        </button>
      )}
    </>
  );
}
