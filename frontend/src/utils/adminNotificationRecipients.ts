import type { AdminNotificationRecipient, AdminSendNotificationRequest } from "../types/api";

export function mergeSelectedRecipients(
  current: ReadonlyMap<number, AdminNotificationRecipient>,
  recipients: readonly AdminNotificationRecipient[],
): Map<number, AdminNotificationRecipient> {
  const next = new Map(current);
  for (const recipient of recipients) {
    next.set(recipient.id, recipient);
  }
  return next;
}

export function removeSelectedRecipient(
  current: ReadonlyMap<number, AdminNotificationRecipient>,
  recipientId: number,
): Map<number, AdminNotificationRecipient> {
  const next = new Map(current);
  next.delete(recipientId);
  return next;
}

export function selectedRecipientIds(
  recipients: ReadonlyMap<number, AdminNotificationRecipient>,
): number[] {
  return [...recipients.keys()].sort((left, right) => left - right);
}

export function buildAdminNotificationRecipients(
  scope: AdminSendNotificationRequest["recipientScope"],
  recipients: ReadonlyMap<number, AdminNotificationRecipient>,
): Pick<AdminSendNotificationRequest, "recipientScope" | "userIds" | "confirmBroadcast"> {
  return scope === "AllUsers"
    ? { recipientScope: scope, confirmBroadcast: true }
    : { recipientScope: scope, userIds: selectedRecipientIds(recipients), confirmBroadcast: false };
}
