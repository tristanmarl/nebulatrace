# Architecture

NebulaTrace is a small starship operations app. It uses deliberately mixed
languages so Dynatrace can show different instrumentation paths without adding
extra architecture.

```mermaid
flowchart LR
  User[Mission Commander] --> GW[Istio IngressGateway]
  GW --> FE[bridge-ui]
  FE --> API[command-api]
  API --> CARGO[cargo-api]
  API --> MISSION[mission-api]
  API --> CREDITS[credits-api]
  API --> ORBIT[orbit-ai]
  CARGO --> PG[(PostgreSQL)]
  MISSION --> PG
  MISSION --> MQ[(RabbitMQ)]
  CREDITS --> REDIS[(Redis)]
  DRONE[drone-worker] --> MQ
  DRONE --> PG
  DRONE --> MAINT[maintenance-api]
  ORBIT --> LLM[mock-llm]
```

## Services

| Service | Runtime | Role | Telemetry |
|---|---|---|---|
| `bridge-ui` | React + NGINX | Starship console | OneAgent optional |
| `command-api` | Node.js | API facade | OneAgent |
| `cargo-api` | Java Spring Boot | Cargo inventory and slow SQL | OneAgent |
| `mission-api` | Python FastAPI | Mission creation and RabbitMQ publish | OpenTelemetry |
| `credits-api` | Go | Fake credits authorization | OneAgent |
| `drone-worker` | Python | Async job consumer | OpenTelemetry |
| `maintenance-api` | Node.js | Repair status | OneAgent |
| `orbit-ai` | Python FastAPI | AI mission recommendations | OpenTelemetry |
| `mock-llm` | Python FastAPI | Local fake LLM | OpenTelemetry |
PostgreSQL, RabbitMQ, and Redis live in `nebulatrace-data` without Istio
sidecars. App workloads live in `nebulatrace` with Istio injection enabled.
