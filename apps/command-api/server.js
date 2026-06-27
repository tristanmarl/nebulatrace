import Fastify from "fastify";
import k8s from "@kubernetes/client-node";

const app = Fastify({ logger: true });
const port = Number(process.env.PORT || 8080);
const urls = {
  cargo: process.env.CARGO_URL || "http://cargo-api:8080",
  mission: process.env.MISSION_URL || "http://mission-api:8080",
  credits: process.env.CREDITS_URL || "http://credits-api:8080",
  orbit: process.env.ORBIT_URL || "http://orbit-ai:8080"
};

const NS = "nebulatrace";
const STRATEGIC = { headers: { "Content-Type": "application/strategic-merge-patch+json" } };
const MERGE = { headers: { "Content-Type": "application/merge-patch+json" } };

const kc = new k8s.KubeConfig();
try { kc.loadFromCluster(); } catch { kc.loadFromDefault(); }
const appsApi = kc.makeApiClient(k8s.AppsV1Api);
const customApi = kc.makeApiClient(k8s.CustomObjectsApi);

function envPatch(containerName, envValue) {
  return {
    spec: {
      template: {
        metadata: { annotations: { "kubectl.kubernetes.io/restartedAt": new Date().toISOString() } },
        spec: { containers: [{ name: containerName, env: [{ name: "ENTROPY_MODE", value: envValue }] }] }
      }
    }
  };
}

async function patchDeployment(name, envValue) {
  await appsApi.patchNamespacedDeployment(name, NS, envPatch(name, envValue),
    undefined, undefined, undefined, undefined, undefined, STRATEGIC);
}

async function patchVirtualService(spec) {
  await customApi.patchNamespacedCustomObject(
    "networking.istio.io", "v1", NS, "virtualservices", "credits-api",
    { spec }, undefined, undefined, undefined, MERGE
  );
}

const STABLE_VS_SPEC = {
  hosts: ["credits-api.nebulatrace.svc.cluster.local"],
  http: [{ route: [{ destination: { host: "credits-api.nebulatrace.svc.cluster.local", subset: "stable", port: { number: 8080 } } }] }]
};

const WORMHOLE_VS_SPEC = {
  hosts: ["credits-api.nebulatrace.svc.cluster.local"],
  http: [{
    fault: { abort: { percentage: { value: 50 }, httpStatus: 503 } },
    route: [{ destination: { host: "credits-api.nebulatrace.svc.cluster.local", subset: "stable", port: { number: 8080 } } }]
  }]
};

const ENTROPY_HANDLERS = {
  "slow-db":          () => patchDeployment("cargo-api", "slow-db"),
  "queue-backlog":    () => patchDeployment("drone-worker", "queue-backlog"),
  "credit-errors":    () => patchDeployment("credits-api", "credit-errors"),
  "wormhole-route":   () => patchVirtualService(WORMHOLE_VS_SPEC),
  "ai-anomaly":       () => patchDeployment("mock-llm", "ai-anomaly"),
  "job-failures":     () => patchDeployment("drone-worker", "job-failures"),
  "mission-errors":   () => patchDeployment("mission-api", "mission-errors"),
  "cascade": async () => {
    await Promise.all([
      patchDeployment("cargo-api", "slow-db"),
      patchDeployment("credits-api", "credit-errors"),
      patchDeployment("drone-worker", "job-failures"),
      patchDeployment("mock-llm", "ai-anomaly"),
      patchDeployment("mission-api", "mission-errors"),
      patchVirtualService(WORMHOLE_VS_SPEC),
    ]);
  },
  "reset": async () => {
    await Promise.all([
      patchDeployment("cargo-api", "stable"),
      patchDeployment("credits-api", "stable"),
      patchDeployment("drone-worker", "stable"),
      patchDeployment("mock-llm", "stable"),
      patchDeployment("mission-api", "stable"),
      patchVirtualService(STABLE_VS_SPEC)
    ]);
  }
};

async function getJson(url, options) {
  const res = await fetch(url, options);
  const body = await res.text();
  let parsed;
  try { parsed = JSON.parse(body); } catch { parsed = { body }; }
  return { statusCode: res.status, body: parsed };
}

app.get("/healthz", async () => ({ ok: true, service: "command-api" }));

app.get("/api/status", async () => ({
  ship: "CSS Observable",
  orbit: "online",
  entropyDrive: process.env.ENTROPY_MODE || "stable"
}));

async function proxy(reply, call) {
  const result = await call();
  reply.code(result.statusCode);
  return result.body;
}

app.get("/api/cargo", async (_req, reply) => proxy(reply, () => getJson(`${urls.cargo}/cargo`)));
app.get("/api/credits/authorize", async (_req, reply) => proxy(reply, () => getJson(`${urls.credits}/authorize`)));
app.get("/api/credits/fail", async (_req, reply) => proxy(reply, () => getJson(`${urls.credits}/authorize?force_error=true`)));
app.get("/api/orbit/recommend", async (_req, reply) => proxy(reply, () => getJson(`${urls.orbit}/recommend`)));
app.post("/api/missions", async (_req, reply) => proxy(reply, () => getJson(`${urls.mission}/missions`, { method: "POST" })));

app.post("/api/entropy/:mode", async (request, reply) => {
  const { mode } = request.params;
  const handler = ENTROPY_HANDLERS[mode];
  if (!handler) {
    reply.code(400);
    return { error: `unknown entropy mode: ${mode}` };
  }
  try {
    await handler();
    return { ok: true, mode };
  } catch (err) {
    reply.code(500);
    return { error: err.message };
  }
});

app.listen({ port, host: "0.0.0.0" });
