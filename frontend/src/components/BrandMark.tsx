import { Server } from "lucide-react";

interface BrandMarkProps {
  inverse?: boolean;
}

export function BrandMark({ inverse = false }: BrandMarkProps) {
  return (
    <span lang="en" dir="ltr" className="group inline-flex items-center gap-2.5">
      <span
        className={`relative inline-flex size-10 items-center justify-center overflow-hidden rounded-control border transition duration-base ease-standard group-hover:-translate-y-0.5 ${
          inverse
            ? "border-white/15 bg-white/10 text-white shadow-control backdrop-blur-md"
            : "border-brand-400/30 bg-gradient-to-br from-brand-600 to-brand-400 text-white shadow-glow"
        }`}
      >
        <span aria-hidden="true" className="absolute inset-x-1 top-0 h-px bg-white/60" />
        <Server aria-hidden="true" size={20} strokeWidth={2.1} />
        <span
          aria-hidden="true"
          className={`absolute bottom-1.5 right-1.5 size-1.5 rounded-full ring-2 ${
            inverse ? "bg-brand-300 ring-surface-inverse" : "bg-white ring-brand-500"
          }`}
        />
      </span>
      <span className={`font-latin text-base font-extrabold tracking-[-0.035em] ${inverse ? "text-white" : "text-ink-950"}`}>
        Hardware<span className={inverse ? "text-brand-300" : "text-brand-600"}>Reserve</span>
      </span>
    </span>
  );
}
