export function getAdminActionBadgeLabel(
  count: number,
  formatNumber: (value: number) => string = String,
): string | null {
  return count > 0 ? formatNumber(count) : null;
}
