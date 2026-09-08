import type { Server } from "../types/api";
import i18n from "../i18n/config";
import { hasDedicatedGpu } from "./serverDiscovery";

export { hasDedicatedGpu };

export function getComputeTypeLabel(server: Pick<Server, "gpu">): string {
  return hasDedicatedGpu(server) ? i18n.t("server.computeType.gpu") : i18n.t("server.computeType.cpu");
}
