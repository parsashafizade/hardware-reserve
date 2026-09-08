import { useContext } from "react";
import { SupportContext } from "./SupportContextDefinition";

export function useSupport() {
  const context = useContext(SupportContext);
  if (!context) {
    throw new Error("useSupport must be used inside SupportProvider.");
  }

  return context;
}
