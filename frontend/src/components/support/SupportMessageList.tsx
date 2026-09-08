import { useCallback, useEffect, useRef, useState } from "react";
import { useTranslation } from "react-i18next";
import {
  Bot,
  ChevronDown,
  Clock3,
  Headphones,
  LoaderCircle,
  RefreshCw,
  UserRound,
} from "lucide-react";
import type { SupportMessage } from "../../types/support";
import { formatSupportDateTime, formatSupportTime, getSupportSenderLabel } from "../../utils/support";
import { SupportMessageContent } from "./BidiText";
import { usePrefersReducedMotion } from "../../hooks/usePrefersReducedMotion";

export interface PendingSupportMessage {
  content: string;
  clientMessageId: string;
  state: "sending" | "failed";
  error?: string;
}

interface SupportMessageListProps {
  messages: SupportMessage[];
  loading: boolean;
  hasMore: boolean;
  loadingOlder: boolean;
  onLoadOlder: () => Promise<void>;
  perspective: "user" | "admin";
  pending?: PendingSupportMessage | null;
  onRetryPending?: () => void;
  aiProcessing?: boolean;
  emptyMessage?: string;
  className?: string;
}

function SenderIcon({ senderType }: { senderType: SupportMessage["senderType"] }) {
  if (senderType === "AI") {
    return <Bot aria-hidden="true" size={14} />;
  }
  if (senderType === "ADMIN") {
    return <Headphones aria-hidden="true" size={14} />;
  }
  return <UserRound aria-hidden="true" size={14} />;
}

function MessageBubble({
  message,
  perspective,
}: {
  message: SupportMessage;
  perspective: "user" | "admin";
}) {
  const { t } = useTranslation();
  const isCurrentSender =
    perspective === "user" ? message.senderType === "USER" : message.senderType === "ADMIN";
  const senderLabel =
    perspective === "admin" && message.senderType === "USER"
      ? t("support.sender.customer")
      : getSupportSenderLabel(message.senderType);

  return (
    <article
      dir="ltr"
      className={`flex w-full ${isCurrentSender ? "justify-end" : "justify-start"}`}
      data-message-id={message.id}
    >
      <div className={`max-w-[88%] sm:max-w-[78%] lg:max-w-[42rem] ${isCurrentSender ? "items-end" : "items-start"} flex flex-col`}>
        <div className="mb-1.5 flex items-center gap-1.5 px-1 text-[11px] font-semibold text-ink-500">
          <SenderIcon senderType={message.senderType} />
          <span dir="auto" className="support-bidi">{senderLabel}</span>
        </div>
        <div
          className={[
            "rounded-2xl px-4 py-3.5 text-sm leading-7 shadow-control",
            isCurrentSender
              ? "rounded-br-md bg-brand-600 text-white"
              : message.senderType === "AI"
                ? "rounded-bl-md border border-brand-100 bg-brand-50/90 text-ink-800"
                : "rounded-bl-md border border-border-subtle bg-white text-ink-800",
          ].join(" ")}
        >
          <SupportMessageContent content={message.content} />
        </div>
        <time
          dir="auto"
          dateTime={message.createdAt}
          title={formatSupportDateTime(message.createdAt)}
          className="mt-1 px-1 text-[10px] font-medium text-ink-500"
        >
          {formatSupportTime(message.createdAt)}
        </time>
      </div>
    </article>
  );
}

function PendingBubble({
  pending,
  onRetry,
  perspective,
}: {
  pending: PendingSupportMessage;
  onRetry?: () => void;
  perspective: "user" | "admin";
}) {
  const { t } = useTranslation();
  return (
    <div dir="ltr" className="flex w-full justify-end">
      <div className="flex max-w-[88%] flex-col items-end sm:max-w-[78%] lg:max-w-[42rem]">
        <div className="mb-1.5 flex items-center gap-1.5 px-1 text-[11px] font-semibold text-ink-500">
          <UserRound aria-hidden="true" size={14} />
          <span dir="auto" className="support-bidi">{perspective === "admin" ? t("support.sender.admin") : t("support.sender.user")}</span>
        </div>
        <div className={`rounded-2xl rounded-br-md px-4 py-3.5 text-sm leading-7 text-white shadow-control ${pending.state === "failed" ? "bg-status-danger" : "bg-brand-600/80"}`}>
          <SupportMessageContent content={pending.content} />
        </div>
        <div dir="auto" className={`mt-1 flex items-center gap-1.5 px-1 text-[10px] font-semibold ${pending.state === "failed" ? "text-status-danger" : "text-ink-500"}`}>
          {pending.state === "sending" ? (
            <>
              <LoaderCircle aria-hidden="true" className="animate-spin" size={11} />
              {t("support.messages.sending")}
            </>
          ) : (
            <>
              <span>{pending.error || t("support.messages.notSent")}</span>
              {onRetry && (
                <button type="button" className="inline-flex items-center gap-1 underline underline-offset-2" onClick={onRetry}>
                  <RefreshCw aria-hidden="true" size={10} />
                  {t("support.messages.retry")}
                </button>
              )}
            </>
          )}
        </div>
      </div>
    </div>
  );
}

export function SupportMessageList({
  messages,
  loading,
  hasMore,
  loadingOlder,
  onLoadOlder,
  perspective,
  pending,
  onRetryPending,
  aiProcessing = false,
  emptyMessage,
  className = "",
}: SupportMessageListProps) {
  const { t } = useTranslation();
  const scrollRef = useRef<HTMLDivElement>(null);
  const wasNearBottomRef = useRef(true);
  const previousTailRef = useRef<string | null>(null);
  const initialScrollCompletedRef = useRef(false);
  const [newMessagesAvailable, setNewMessagesAvailable] = useState(false);
  const prefersReducedMotion = usePrefersReducedMotion();

  const scrollToBottom = useCallback((behavior: ScrollBehavior = "smooth") => {
    const node = scrollRef.current;
    if (!node) {
      return;
    }
    node.scrollTo({
      top: node.scrollHeight,
      behavior: prefersReducedMotion && behavior === "smooth" ? "auto" : behavior,
    });
    wasNearBottomRef.current = true;
    setNewMessagesAvailable(false);
  }, [prefersReducedMotion]);

  useEffect(() => {
    const tailId = messages.at(-1)?.id ?? null;
    if (!tailId || tailId === previousTailRef.current) {
      return;
    }

    if (!initialScrollCompletedRef.current || wasNearBottomRef.current) {
      requestAnimationFrame(() => scrollToBottom(initialScrollCompletedRef.current ? "smooth" : "auto"));
      initialScrollCompletedRef.current = true;
    } else {
      requestAnimationFrame(() => setNewMessagesAvailable(true));
    }
    previousTailRef.current = tailId;
  }, [messages, scrollToBottom]);

  useEffect(() => {
    if (pending?.state === "sending" && wasNearBottomRef.current) {
      requestAnimationFrame(() => scrollToBottom("smooth"));
    }
  }, [pending?.state, scrollToBottom]);

  const handleScroll = () => {
    const node = scrollRef.current;
    if (!node) {
      return;
    }
    const nearBottom = node.scrollHeight - node.scrollTop - node.clientHeight < 80;
    wasNearBottomRef.current = nearBottom;
    if (nearBottom) {
      setNewMessagesAvailable(false);
    }
  };

  const handleLoadOlder = async () => {
    const node = scrollRef.current;
    const previousHeight = node?.scrollHeight ?? 0;
    const previousTop = node?.scrollTop ?? 0;
    await onLoadOlder();
    requestAnimationFrame(() => {
      requestAnimationFrame(() => {
        if (node) {
          node.scrollTop = previousTop + (node.scrollHeight - previousHeight);
        }
      });
    });
  };

  return (
    <div className={`relative min-h-0 flex-1 ${className}`.trim()}>
      <div
        ref={scrollRef}
        role="log"
        aria-live="polite"
        aria-relevant="additions"
        aria-label={t("support.messages.logAria")}
        onScroll={handleScroll}
        className="support-message-scroll h-full overflow-y-auto overscroll-contain px-4 py-5 sm:px-5"
      >
        {loading ? (
          <div className="space-y-4" role="status" aria-label={t("support.messages.loading")}>
            <div className="skeleton h-20 w-4/5 rounded-2xl" />
            <div className="ms-auto skeleton h-16 w-3/4 rounded-2xl" />
            <div className="skeleton h-28 w-[88%] rounded-2xl" />
          </div>
        ) : (
          <div className="space-y-5">
            {hasMore && (
              <div className="flex justify-center pb-1">
                <button
                  type="button"
                  className="inline-flex min-h-9 items-center gap-2 rounded-pill border border-border-subtle bg-white px-3 py-1.5 text-xs font-semibold text-ink-600 shadow-control hover:border-brand-200 hover:text-brand-700 disabled:opacity-60"
                  onClick={() => void handleLoadOlder()}
                  disabled={loadingOlder}
                >
                  {loadingOlder ? <LoaderCircle aria-hidden="true" className="animate-spin" size={13} /> : <Clock3 aria-hidden="true" size={13} />}
                  {loadingOlder ? t("support.messages.loadingHistory") : t("support.messages.loadOlder")}
                </button>
              </div>
            )}

            {messages.length === 0 && !pending ? (
              <div className="mx-auto flex max-w-xs flex-col items-center py-12 text-center text-sm text-ink-500">
                <span className="icon-tile-neutral"><Headphones aria-hidden="true" size={19} /></span>
                <p className="mt-3 leading-6">{emptyMessage ?? t("support.messages.empty")}</p>
              </div>
            ) : (
              messages.map((message) => (
                <MessageBubble key={message.id} message={message} perspective={perspective} />
              ))
            )}

            {pending && <PendingBubble pending={pending} onRetry={onRetryPending} perspective={perspective} />}

            {aiProcessing && (
              <div dir="ltr" className="flex justify-start" role="status" aria-live="polite">
                <div className="rounded-2xl rounded-bl-md border border-brand-100 bg-brand-50 px-4 py-3 text-sm text-ink-600 shadow-control">
                  <span dir="auto" className="inline-flex items-center gap-2">
                    <Bot aria-hidden="true" size={15} className="text-brand-700" />
                    {t("support.messages.aiThinking")}
                    <span className="support-typing-dots" aria-hidden="true"><i /><i /><i /></span>
                  </span>
                </div>
              </div>
            )}
          </div>
        )}
      </div>

      {newMessagesAvailable && (
        <button
          type="button"
          className="absolute bottom-3 left-1/2 z-10 inline-flex min-h-9 -translate-x-1/2 items-center gap-1.5 rounded-pill bg-ink-900 px-3.5 py-2 text-xs font-semibold text-white shadow-floating"
          onClick={() => scrollToBottom("smooth")}
        >
          <ChevronDown aria-hidden="true" size={14} />
          {t("support.messages.newMessages")}
        </button>
      )}
    </div>
  );
}
