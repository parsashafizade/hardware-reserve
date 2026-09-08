import type { Server, ServerFilters } from "../types/api.ts";

export type CatalogSort = "priceAsc" | "priceDesc" | "ramDesc";
export type ComputeFilter = "all" | "gpu" | "cpu";
export type FinderWorkload =
  | "aiTraining"
  | "aiInference"
  | "rendering"
  | "development"
  | "dataProcessing"
  | "hosting"
  | "general"
  | "custom";
export type FinderIntensity = "light" | "moderate" | "heavy";
export type FinderGpuPreference = "automatic" | "required" | "notNeeded";
export type FinderPriority = "value" | "balanced" | "performance";
export type RecommendationTradeoff = "performance" | "value" | "balanced";
export type RecommendationReason =
  | "strongGpu"
  | "gpuReady"
  | "strongCpu"
  | "memoryHeadroom"
  | "meetsMemory"
  | "costEfficient"
  | "balancedResources";

export interface CatalogQuery {
  search: string;
  filters: ServerFilters;
  compute: ComputeFilter;
  sort: CatalogSort;
}

export interface FinderPreferences {
  workload: FinderWorkload;
  customWorkload: string;
  intensity: FinderIntensity;
  gpuPreference: FinderGpuPreference;
  minimumRamGb: number;
  durationHours: number;
  priority: FinderPriority;
}

export interface ServerRecommendation {
  server: Server;
  fitScore: number;
  estimatedCost: number;
  capabilityScore: number;
  tradeoff: RecommendationTradeoff;
  reasons: RecommendationReason[];
  resolvedWorkload: Exclude<FinderWorkload, "custom">;
}

interface WorkloadProfile {
  capabilityType: Server["workloadCapabilities"][number]["workloadType"];
  gpuWeight: number;
  cpuWeight: number;
  ramWeight: number;
  storageWeight: number;
  baseRamGb: number;
  baseStorageGb: number;
  requiresGpu: boolean;
}

interface RankedCandidate {
  server: Server;
  estimatedCost: number;
  capabilityScore: number;
  fitScore: number;
  reasons: RecommendationReason[];
}

const workloadProfiles: Record<Exclude<FinderWorkload, "custom">, WorkloadProfile> = {
  aiTraining: {
    capabilityType: "ModelTraining",
    gpuWeight: 0.6,
    cpuWeight: 0.1,
    ramWeight: 0.2,
    storageWeight: 0.1,
    baseRamGb: 64,
    baseStorageGb: 1_024,
    requiresGpu: true,
  },
  aiInference: {
    capabilityType: "Inference",
    gpuWeight: 0.55,
    cpuWeight: 0.1,
    ramWeight: 0.25,
    storageWeight: 0.1,
    baseRamGb: 32,
    baseStorageGb: 512,
    requiresGpu: true,
  },
  rendering: {
    capabilityType: "Rendering",
    gpuWeight: 0.55,
    cpuWeight: 0.2,
    ramWeight: 0.15,
    storageWeight: 0.1,
    baseRamGb: 32,
    baseStorageGb: 1_024,
    requiresGpu: true,
  },
  development: {
    capabilityType: "DevelopmentCompilation",
    gpuWeight: 0,
    cpuWeight: 0.45,
    ramWeight: 0.35,
    storageWeight: 0.2,
    baseRamGb: 32,
    baseStorageGb: 512,
    requiresGpu: false,
  },
  dataProcessing: {
    capabilityType: "DataProcessing",
    gpuWeight: 0.1,
    cpuWeight: 0.35,
    ramWeight: 0.4,
    storageWeight: 0.15,
    baseRamGb: 64,
    baseStorageGb: 1_024,
    requiresGpu: false,
  },
  hosting: {
    capabilityType: "WebBackendHosting",
    gpuWeight: 0,
    cpuWeight: 0.4,
    ramWeight: 0.35,
    storageWeight: 0.25,
    baseRamGb: 16,
    baseStorageGb: 512,
    requiresGpu: false,
  },
  general: {
    capabilityType: "GeneralCompute",
    gpuWeight: 0.05,
    cpuWeight: 0.4,
    ramWeight: 0.35,
    storageWeight: 0.2,
    baseRamGb: 16,
    baseStorageGb: 512,
    requiresGpu: false,
  },
};

const intensityMultiplier: Record<FinderIntensity, number> = {
  light: 0.75,
  moderate: 1,
  heavy: 1.5,
};

const priorityWeights: Record<FinderPriority, { capability: number; cost: number }> = {
  value: { capability: 0.58, cost: 0.42 },
  balanced: { capability: 0.78, cost: 0.22 },
  performance: { capability: 0.93, cost: 0.07 },
};

export function hasDedicatedGpu(server: Pick<Server, "gpu">): boolean {
  return server.gpu.trim().toLowerCase() !== "none";
}

export function parseCapacityGb(value: string): number {
  const match = value.match(/([\d.]+)\s*(TB|GB)/i);
  if (!match) {
    return 0;
  }

  const amount = Number(match[1]);
  return match[2]?.toUpperCase() === "TB" ? amount * 1_024 : amount;
}

export function filterAndSortServers(servers: Server[], query: CatalogQuery): Server[] {
  const normalizedSearch = query.search.trim().toLowerCase();
  const normalizedFilters = Object.fromEntries(
    Object.entries(query.filters).map(([key, value]) => [key, value?.trim().toLowerCase()]),
  ) as Record<keyof ServerFilters, string | undefined>;

  const filtered = servers.filter((server) => {
    if (!server.isActive) {
      return false;
    }

    const dedicatedGpu = hasDedicatedGpu(server);
    if (query.compute === "gpu" && !dedicatedGpu) {
      return false;
    }
    if (query.compute === "cpu" && dedicatedGpu) {
      return false;
    }

    if (
      normalizedSearch &&
      !`${server.cpu} ${server.gpu} ${server.ram} ${server.storage} ${server.os}`
        .toLowerCase()
        .includes(normalizedSearch)
    ) {
      return false;
    }

    return (Object.keys(normalizedFilters) as Array<keyof ServerFilters>).every((key) => {
      const expected = normalizedFilters[key];
      return !expected || server[key].toLowerCase().includes(expected);
    });
  });

  return [...filtered].sort((left, right) => {
    if (query.sort === "priceDesc") {
      return right.pricePerHour - left.pricePerHour || left.id - right.id;
    }
    if (query.sort === "ramDesc") {
      return parseCapacityGb(right.ram) - parseCapacityGb(left.ram)
        || left.pricePerHour - right.pricePerHour
        || left.id - right.id;
    }

    return left.pricePerHour - right.pricePerHour || left.id - right.id;
  });
}

export function estimateReservationCost(server: Pick<Server, "pricePerHour" | "pricePerDay">, durationHours: number): number {
  const safeHours = Math.max(0, durationHours);
  if (safeHours < 24) {
    return Math.round(safeHours * server.pricePerHour);
  }

  const days = Math.floor(safeHours / 24);
  const remainingHours = safeHours - days * 24;
  return Math.round(days * server.pricePerDay + remainingHours * server.pricePerHour);
}

export function inferCustomWorkload(description: string): Exclude<FinderWorkload, "custom"> {
  const normalized = description.trim().toLowerCase();

  if (/(inference|serving|\u0627\u0633\u062a\u0646\u062a\u0627\u062c|\u0627\u062c\u0631\u0627\u06cc \u0645\u062f\u0644)/i.test(normalized)) {
    return "aiInference";
  }
  if (/(fine[- ]?tun|train|machine learning|\bai\b|\bml\b|llm|\u06cc\u0627\u062f\u06af\u06cc\u0631\u06cc|\u0645\u062f\u0644|\u0622\u0645\u0648\u0632\u0634)/i.test(normalized)) {
    return "aiTraining";
  }
  if (/(render|blender|3d|\u0631\u0646\u062f\u0631|\u0628\u0644\u0646\u062f\u0631)/i.test(normalized)) {
    return "rendering";
  }
  if (/(data|dataset|analytics|etl|\u062f\u0627\u062f\u0647|\u062a\u062d\u0644\u06cc\u0644)/i.test(normalized)) {
    return "dataProcessing";
  }
  if (/(web|backend|hosting|website|api|\u0648\u0628|\u0647\u0627\u0633\u062a|\u0633\u0627\u06cc\u062a)/i.test(normalized)) {
    return "hosting";
  }
  if (/(develop|compile|build|software|\u062a\u0648\u0633\u0639\u0647|\u06a9\u0627\u0645\u067e\u0627\u06cc\u0644|\u0646\u0631\u0645.?\u0627\u0641\u0632\u0627\u0631)/i.test(normalized)) {
    return "development";
  }

  return "general";
}

export function recommendServers(servers: Server[], preferences: FinderPreferences): ServerRecommendation[] {
  const resolvedWorkload = preferences.workload === "custom"
    ? inferCustomWorkload(preferences.customWorkload)
    : preferences.workload;
  const profile = workloadProfiles[resolvedWorkload];
  const multiplier = intensityMultiplier[preferences.intensity];
  const targetRamGb = Math.max(preferences.minimumRamGb, Math.round(profile.baseRamGb * multiplier));
  const targetStorageGb = Math.round(profile.baseStorageGb * multiplier);
  const gpuRequired = preferences.gpuPreference === "required"
    || (preferences.gpuPreference === "automatic" && profile.requiresGpu);

  const eligible = servers.filter((server) => {
    if (
      !server.isActive
      || server.operationalStatus !== "Available"
      || !server.finderEligible
      || parseCapacityGb(server.ram) < preferences.minimumRamGb
    ) {
      return false;
    }

    return !gpuRequired || hasDedicatedGpu(server);
  });

  if (eligible.length === 0) {
    return [];
  }

  const costs = eligible.map((server) => estimateReservationCost(server, preferences.durationHours));
  const minimumCost = Math.min(...costs);
  const maximumCost = Math.max(...costs);
  const priority = priorityWeights[preferences.priority];

  const candidates: RankedCandidate[] = eligible.map((server, index) => {
    const gpuScore = server.gpuCapabilityLevel;
    const cpuScore = server.cpuCapabilityLevel;
    const workloadScore = getManagedWorkloadScore(server, profile.capabilityType);
    const ramGb = parseCapacityGb(server.ram);
    const storageGb = parseCapacityGb(server.storage);
    const ramScore = targetFitScore(ramGb, targetRamGb);
    const storageScore = targetFitScore(storageGb, targetStorageGb);
    const hardwareScore = clamp(
      gpuScore * profile.gpuWeight
        + cpuScore * profile.cpuWeight
        + ramScore * profile.ramWeight
        + storageScore * profile.storageWeight,
      0,
      100,
    );
    const capabilityScore = clamp(hardwareScore * 0.45 + workloadScore * 0.55, 0, 100);
    const estimatedCost = costs[index] ?? 0;
    const costScore = maximumCost === minimumCost
      ? 100
      : 100 - ((estimatedCost - minimumCost) / (maximumCost - minimumCost)) * 100;
    let weightedScore = capabilityScore * priority.capability + costScore * priority.cost;

    if (preferences.gpuPreference === "notNeeded" && hasDedicatedGpu(server)) {
      weightedScore -= 8;
    }

    return {
      server,
      estimatedCost,
      capabilityScore,
      fitScore: roundFitScore(weightedScore),
      reasons: getRecommendationReasons({
        server,
        gpuScore,
        cpuScore,
        ramGb,
        targetRamGb,
        estimatedCost,
        minimumCost,
        profile,
      }),
    };
  });

  const shortlist = candidates
    .filter((candidate) => candidate.fitScore >= 40)
    .sort((left, right) =>
      right.fitScore - left.fitScore
        || right.capabilityScore - left.capabilityScore
        || left.estimatedCost - right.estimatedCost
        || left.server.id - right.server.id,
    )
    .slice(0, 3);

  if (shortlist.length === 0) {
    return [];
  }

  const performanceId = [...shortlist].sort((left, right) =>
    right.capabilityScore - left.capabilityScore || right.fitScore - left.fitScore,
  )[0]?.server.id;
  const valueId = shortlist
    .filter((candidate) => candidate.server.id !== performanceId)
    .sort((left, right) => left.estimatedCost - right.estimatedCost || right.fitScore - left.fitScore)[0]
    ?.server.id;

  return shortlist.map((candidate) => ({
    ...candidate,
    tradeoff: candidate.server.id === performanceId
      ? "performance"
      : candidate.server.id === valueId
        ? "value"
        : "balanced",
    resolvedWorkload,
  }));
}

function targetFitScore(actual: number, target: number): number {
  if (target <= 0) {
    return 100;
  }
  if (actual >= target) {
    return Math.min(100, 82 + ((actual - target) / target) * 18);
  }
  return Math.max(0, (actual / target) * 82);
}

function getManagedWorkloadScore(
  server: Server,
  workloadType: Server["workloadCapabilities"][number]["workloadType"],
): number {
  const capability = server.workloadCapabilities.find((item) => item.workloadType === workloadType);
  return capability ? clamp(capability.suitabilityLevel * 20, 0, 100) : 0;
}

function getRecommendationReasons(input: {
  server: Server;
  gpuScore: number;
  cpuScore: number;
  ramGb: number;
  targetRamGb: number;
  estimatedCost: number;
  minimumCost: number;
  profile: WorkloadProfile;
}): RecommendationReason[] {
  const reasons: RecommendationReason[] = [];

  if (input.profile.gpuWeight >= 0.4 && input.gpuScore >= 78) {
    reasons.push("strongGpu");
  } else if (input.profile.gpuWeight > 0 && hasDedicatedGpu(input.server)) {
    reasons.push("gpuReady");
  }
  if (input.profile.cpuWeight >= 0.35 && input.cpuScore >= 78) {
    reasons.push("strongCpu");
  }
  if (input.ramGb >= input.targetRamGb * 1.5) {
    reasons.push("memoryHeadroom");
  } else if (input.ramGb >= input.targetRamGb) {
    reasons.push("meetsMemory");
  }
  if (input.estimatedCost <= input.minimumCost * 1.2) {
    reasons.push("costEfficient");
  }
  if (reasons.length < 2) {
    reasons.push("balancedResources");
  }

  return [...new Set(reasons)].slice(0, 2);
}

function roundFitScore(value: number): number {
  return clamp(Math.round(value / 5) * 5, 0, 95);
}

function clamp(value: number, minimum: number, maximum: number): number {
  return Math.min(maximum, Math.max(minimum, value));
}
