import { isAxiosError } from "axios";
import type { SupportQuickReply, UpsertSupportQuickReplyRequest } from "../types/support";

export function isAmbiguousMutationFailure(error: unknown): boolean {
  if (!isAxiosError(error)) {
    return false;
  }

  return !error.response || error.response.status >= 500;
}

function normalizeOptional(value: string | null | undefined): string | null {
  return value?.trim() || null;
}

export function reconcileCreatedQuickReply(
  baselineIds: ReadonlySet<string>,
  request: UpsertSupportQuickReplyRequest,
  authoritativeReplies: SupportQuickReply[],
): SupportQuickReply | null {
  const matches = authoritativeReplies.filter((reply) =>
    !baselineIds.has(reply.id)
    && reply.title.trim() === request.title.trim()
    && reply.content.trim() === request.content.trim()
    && normalizeOptional(reply.category) === normalizeOptional(request.category)
    && reply.isActive === request.isActive
    && reply.sortOrder === Number(request.sortOrder));

  return matches.length === 1 ? matches[0] : null;
}
