import assert from "node:assert/strict";
import test from "node:test";
import type { Server } from "../src/types/api.ts";
import {
  estimateReservationCost,
  filterAndSortServers,
  inferCustomWorkload,
  recommendServers,
  type FinderPreferences,
} from "../src/utils/serverDiscovery.ts";

function server(overrides: Partial<Server> & Pick<Server, "id" | "cpu" | "gpu">): Server {
  return {
    ram: "64GB",
    storage: "1TB NVMe",
    os: "Ubuntu 24.04",
    pricePerHour: 50_000,
    pricePerDay: 900_000,
    isActive: true,
    operationalStatus: "Available",
    finderEligible: true,
    cpuCapabilityLevel: 60,
    gpuCapabilityLevel: 60,
    performanceTier: "Standard",
    workloadCapabilities: [
      { workloadType: "GeneralCompute", suitabilityLevel: 3 },
      { workloadType: "ModelTraining", suitabilityLevel: 3 },
      { workloadType: "Inference", suitabilityLevel: 3 },
      { workloadType: "Rendering", suitabilityLevel: 3 },
      { workloadType: "DevelopmentCompilation", suitabilityLevel: 3 },
      { workloadType: "DataProcessing", suitabilityLevel: 3 },
      { workloadType: "WebBackendHosting", suitabilityLevel: 3 },
    ],
    ...overrides,
  };
}

const inventory: Server[] = [
  server({ id: 1, cpu: "AMD EPYC 9654", gpu: "NVIDIA H100 80GB", ram: "256GB", storage: "4TB NVMe", pricePerHour: 520_000, pricePerDay: 9_360_000, cpuCapabilityLevel: 100, gpuCapabilityLevel: 100, performanceTier: "Extreme", workloadCapabilities: [{ workloadType: "ModelTraining", suitabilityLevel: 5 }, { workloadType: "Inference", suitabilityLevel: 5 }, { workloadType: "Rendering", suitabilityLevel: 4 }] }),
  server({ id: 2, cpu: "AMD EPYC 7513", gpu: "NVIDIA A100 40GB", ram: "128GB", storage: "2TB NVMe", pricePerHour: 260_000, pricePerDay: 4_680_000, cpuCapabilityLevel: 82, gpuCapabilityLevel: 94, performanceTier: "Extreme", workloadCapabilities: [{ workloadType: "ModelTraining", suitabilityLevel: 5 }, { workloadType: "Inference", suitabilityLevel: 5 }, { workloadType: "Rendering", suitabilityLevel: 4 }] }),
  server({ id: 3, cpu: "Intel Xeon Gold 6330", gpu: "NVIDIA T4 16GB", pricePerHour: 55_000, pricePerDay: 990_000, cpuCapabilityLevel: 80, gpuCapabilityLevel: 65, workloadCapabilities: [{ workloadType: "ModelTraining", suitabilityLevel: 3 }, { workloadType: "Inference", suitabilityLevel: 4 }, { workloadType: "Rendering", suitabilityLevel: 3 }] }),
  server({ id: 4, cpu: "AMD Ryzen 9 7950X", gpu: "NVIDIA RTX 4070 Ti 12GB", pricePerHour: 85_000, pricePerDay: 1_530_000, cpuCapabilityLevel: 86, gpuCapabilityLevel: 84, performanceTier: "High", workloadCapabilities: [{ workloadType: "ModelTraining", suitabilityLevel: 4 }, { workloadType: "Inference", suitabilityLevel: 5 }, { workloadType: "Rendering", suitabilityLevel: 5 }] }),
  server({ id: 5, cpu: "AMD EPYC 7302", gpu: "None", ram: "16GB", storage: "512GB SSD", pricePerHour: 12_000, pricePerDay: 216_000, cpuCapabilityLevel: 72, gpuCapabilityLevel: 0 }),
  server({ id: 6, cpu: "Intel Xeon Silver 4314", gpu: "None", ram: "32GB", storage: "1TB SSD", pricePerHour: 24_000, pricePerDay: 432_000, cpuCapabilityLevel: 62, gpuCapabilityLevel: 0 }),
  server({ id: 7, cpu: "AMD EPYC 9654", gpu: "NVIDIA H100 80GB", ram: "256GB", isActive: false, pricePerHour: 1, pricePerDay: 18 }),
];

const preferences: FinderPreferences = {
  workload: "aiTraining",
  customWorkload: "",
  intensity: "heavy",
  gpuPreference: "automatic",
  minimumRamGb: 64,
  durationHours: 24,
  priority: "performance",
};

test("filters active inventory and sorts by price, RAM, and compute type", () => {
  const cheapest = filterAndSortServers(inventory, {
    search: "",
    filters: {},
    compute: "all",
    sort: "priceAsc",
  });
  assert.deepEqual(cheapest.map((item) => item.id), [5, 6, 3, 4, 2, 1]);

  const gpuByRam = filterAndSortServers(inventory, {
    search: "",
    filters: {},
    compute: "gpu",
    sort: "ramDesc",
  });
  assert.deepEqual(gpuByRam.map((item) => item.id), [1, 2, 3, 4]);

  const searched = filterAndSortServers(inventory, {
    search: "EPYC 7302",
    filters: { os: "Ubuntu" },
    compute: "cpu",
    sort: "priceAsc",
  });
  assert.deepEqual(searched.map((item) => item.id), [5]);
});

test("performance-first AI training ranks the strongest active GPU first", () => {
  const recommendations = recommendServers(inventory, preferences);
  assert.equal(recommendations[0]?.server.id, 1);
  assert.equal(recommendations[0]?.tradeoff, "performance");
  assert.ok(recommendations.every((item) => item.server.isActive));
  assert.ok(recommendations.every((item) => item.server.gpu !== "None"));
});

test("value preference changes inference ranking toward the lower-cost fit", () => {
  const performanceResults = recommendServers(inventory, {
    ...preferences,
    workload: "aiInference",
    intensity: "moderate",
    minimumRamGb: 32,
    priority: "performance",
  });
  const valueResults = recommendServers(inventory, {
    ...preferences,
    workload: "aiInference",
    intensity: "moderate",
    minimumRamGb: 32,
    priority: "value",
  });

  assert.equal(performanceResults[0]?.server.id, 1);
  assert.notEqual(valueResults[0]?.server.id, performanceResults[0]?.server.id);
  assert.ok((valueResults[0]?.estimatedCost ?? Infinity) < (performanceResults[0]?.estimatedCost ?? 0));
});

test("custom Blender description resolves to rendering and favors an RTX configuration", () => {
  assert.equal(inferCustomWorkload("I need a server for Blender rendering"), "rendering");

  const recommendations = recommendServers(inventory, {
    ...preferences,
    workload: "custom",
    customWorkload: "I need a server for Blender rendering",
    intensity: "moderate",
    minimumRamGb: 32,
  });

  assert.equal(recommendations[0]?.resolvedWorkload, "rendering");
  assert.match(recommendations[0]?.server.gpu ?? "", /RTX/);
});

test("unavailable inventory and impossible minimum RAM produce no recommendation", () => {
  const recommendations = recommendServers(inventory, {
    ...preferences,
    minimumRamGb: 512,
  });
  assert.deepEqual(recommendations, []);

  const inactiveOnly = recommendServers(inventory.filter((item) => !item.isActive), preferences);
  assert.deepEqual(inactiveOnly, []);

  const maintenanceOnly = recommendServers(
    inventory.filter((item) => item.isActive).map((item) => ({ ...item, operationalStatus: "Maintenance" })),
    preferences,
  );
  assert.deepEqual(maintenanceOnly, []);
});

test("managed workload suitability changes recommendation ranking without model-name rules", () => {
  const first = server({ id: 20, cpu: "Managed CPU A", gpu: "Managed GPU A", cpuCapabilityLevel: 80, gpuCapabilityLevel: 80, workloadCapabilities: [{ workloadType: "ModelTraining", suitabilityLevel: 5 }] });
  const second = server({ id: 21, cpu: "Managed CPU B", gpu: "Managed GPU B", cpuCapabilityLevel: 80, gpuCapabilityLevel: 80, workloadCapabilities: [{ workloadType: "ModelTraining", suitabilityLevel: 2 }] });

  assert.equal(recommendServers([first, second], preferences)[0]?.server.id, 20);

  first.workloadCapabilities = [{ workloadType: "ModelTraining", suitabilityLevel: 1 }];
  second.workloadCapabilities = [{ workloadType: "ModelTraining", suitabilityLevel: 5 }];
  assert.equal(recommendServers([first, second], preferences)[0]?.server.id, 21);
});

test("cost estimate mirrors the backend hourly and daily pricing boundaries", () => {
  const pricedServer = server({
    id: 10,
    cpu: "CPU",
    gpu: "None",
    pricePerHour: 75_000,
    pricePerDay: 1_350_000,
  });

  assert.equal(estimateReservationCost(pricedServer, 4), 300_000);
  assert.equal(estimateReservationCost(pricedServer, 24), 1_350_000);
  assert.equal(estimateReservationCost(pricedServer, 30), 1_800_000);
  assert.equal(estimateReservationCost(pricedServer, 120), 6_750_000);
});
