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
  try {
    return JSON.parse(body);
  } catch {
    return { status: res.status, body };
  }
}

app.get("/healthz", async () => ({ ok: true, service: "command-api" }));

app.get("/api/status", async () => ({
  ship: "CSS Observable",
  orbit: "online",
  entropyDrive: process.env.ENTROPY_MODE || "stable"
}));

app.get("/api/cargo", async () => getJson(`${urls.cargo}/cargo`));
app.get("/api/credits/authorize", async () => getJson(`${urls.credits}/authorize`));
app.get("/api/orbit/recommend", async () => getJson(`${urls.orbit}/recommend`));
app.post("/api/missions", async () => getJson(`${urls.mission}/missions`, { method: "POST" }));

app.listen({ port, host: "0.0.0.0" });
