import Fastify from "fastify";

const app = Fastify({ logger: true });
const port = Number(process.env.PORT || 8080);

app.get("/healthz", async () => ({ ok: true, service: "maintenance-api" }));
app.post("/repairs", async () => ({
  repairId: `repair-${Date.now()}`,
  status: "sealed with quantum tape"
}));

app.listen({ port, host: "0.0.0.0" });
