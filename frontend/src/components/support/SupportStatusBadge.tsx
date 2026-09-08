import { StatusBadge } from "../ui/StatusBadge";
import type { SupportConversationStatus } from "../../types/support";
import { getSupportStatusLabel } from "../../utils/support";

export function SupportStatusBadge({ status }: { status: SupportConversationStatus }) {
  const tone =
    status === "WAITING_FOR_ADMIN"
      ? "warning"
      : status === "ADMIN_ACTIVE"
        ? "info"
        : status === "RESOLVED"
          ? "success"
          : status === "AI_ACTIVE"
            ? "brand"
            : "neutral";

  return (
    <StatusBadge tone={tone} showDot>
      {getSupportStatusLabel(status)}
    </StatusBadge>
  );
}
