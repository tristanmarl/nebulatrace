import Fastify from "fastify";

const app = Fastify({ logger: true });
const port = Number(process.env.PORT || 8080);
const urls = {
  cargo: process.env.CARGO_URL || "http://cargo-api:8080",
  mission: process.env.MISSION_URL || "http://mission-api:8080",
  credits: process.env.CREDITS_URL || "http://credits-api:8080",
  orbit: process.env.ORBIT_URL || "http://orbit-ai:8080"
};

async function getJson(url, options) {
  const res = await fetch(url, options);
  const body = await res.text();
  let parsed;
  try {
    parsed = JSON.parse(body);
  } catch {
    parsed = { body };
  }
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

app.get("/api/cargo", async (_request, reply) => proxy(reply, () => getJson(`${urls.cargo}/cargo`)));
app.get("/api/credits/authorize", async (_request, reply) => proxy(reply, () => getJson(`${urls.credits}/authorize`)));
app.get("/api/credits/fail", async (_request, reply) => proxy(reply, () => getJson(`${urls.credits}/authorize?force_error=true`)));
app.get("/api/orbit/recommend", async (_request, reply) => proxy(reply, () => getJson(`${urls.orbit}/recommend`)));
app.post("/api/missions", async (_request, reply) => proxy(reply, () => getJson(`${urls.mission}/missions`, { method: "POST" })));

app.listen({ port, host: "0.0.0.0" });
