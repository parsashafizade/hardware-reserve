import type { ElementType } from "react";

interface BidiTextProps {
  text: string;
  className?: string;
  as?: ElementType;
}

export function BidiText({ text, className = "", as: Component = "bdi" }: BidiTextProps) {
  return (
    <Component dir="auto" className={`support-bidi ${className}`.trim()}>
      {text}
    </Component>
  );
}

export function SupportMessageContent({ content }: { content: string }) {
  const parts = content.split(/(https?:\/\/[^\s]+)/giu);

  return (
    <p dir="auto" className="support-message-content">
      {parts.map((part, index) =>
        /^https?:\/\//iu.test(part) ? (
          <a
            key={`${part}-${index}`}
            href={part}
            target="_blank"
            rel="noreferrer noopener"
            dir="ltr"
            className="font-semibold underline decoration-current/40 underline-offset-2 hover:decoration-current"
          >
            {part}
          </a>
        ) : (
          <span key={`${part}-${index}`}>{part}</span>
        ),
      )}
    </p>
  );
}
