import { useContext } from "react";
import { SupportRealtimeContext } from "./SupportRealtimeContextDefinition";

export function useSupportRealtime() {
  const context = useContext(SupportRealtimeContext);
  if (!context) {
    throw new Error("useSupportRealtime must be used inside SupportRealtimeProvider.");
  }

  return context;
}
