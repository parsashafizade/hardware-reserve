export type ActivityDateGroup = "today" | "yesterday" | "earlier";

export function getActivityDateGroup(value: string | Date, nowMilliseconds: number): ActivityDateGroup {
  const now = new Date(nowMilliseconds);
  const today = new Date(now.getFullYear(), now.getMonth(), now.getDate()).getTime();
  const date = typeof value === "string" ? new Date(value) : value;
  const notificationDay = new Date(date.getFullYear(), date.getMonth(), date.getDate()).getTime();
  if (notificationDay === today) {
    return "today";
  }

  const yesterday = new Date(today);
  yesterday.setDate(yesterday.getDate() - 1);
  return notificationDay === yesterday.getTime() ? "yesterday" : "earlier";
}
