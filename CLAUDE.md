# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

NebulaTrace is a Kubernetes observability demo for Dynatrace — a sci-fi starship app that demonstrates OneAgent, OpenTelemetry, Istio mesh tracing, ActiveMQ, and AI telemetry. Keep it simple enough to understand in one sitting.

## Commands

All builds happen inside Docker. No local Node, Go, Maven, Java, or Python required.

```bash
make build-images          # build all service images (nebulatrace/<service>:dev)
make k3s-deploy            # build + load into k3s + deploy (local workflow)
make deploy                # deploy to current kubectl context
make install-istio
make install-dynatrace
make app-url               # show ingress gateway external IP
make status                # pod/deployment status across namespaces
make restart               # rolling restart of all workloads
make stop / make start     # scale app workloads to 0/1 (leaves infra running)
make reset                 # undo all entropy injections
```

Entropy (fault injection):
```bash
make entropy-slow-db
make entropy-queue-backlog
make entropy-credit-errors
make entropy-wormhole-route
make entropy-ai-anomaly
```

After app code changes, rebuild and push affected GHCR images, then regenerate the dist manifest:
```bash
./scripts/render-install-yaml.sh --no-env   # regenerate deploy/dist/nebulatrace.yaml
```

## Architecture

Two namespaces:
- `nebulatrace` — app workloads, Istio sidecar injection enabled
- `nebulatrace-data` — PostgreSQL, ActiveMQ Classic, Redis; Istio disabled, OneAgent enabled for ActiveMQ JMX visibility

Traffic flow:
```
[load-generator / faas-trigger] --> command-api --> cargo-api (Java/PostgreSQL)
                                               --> mission-api (Python/PostgreSQL/ActiveMQ)
                                               --> credits-api (Go/Redis)
                                               --> orbit-ai (Python) --> mock-llm (Python)

mission-api --> ActiveMQ drone.jobs --> drone-worker --> maintenance-api

rpc-probe --> rpc-target  (gRPC, intentional mixed status codes)
```

Service runtimes and telemetry method:

| Service | Runtime | Telemetry |
|---|---|---|
| `bridge-ui` | React + NGINX | OneAgent optional |
| `command-api` | Node.js | OneAgent |
| `cargo-api` | Java Spring Boot | OneAgent |
| `mission-api` | Python FastAPI | OpenTelemetry |
| `credits-api` | Go | OneAgent |
| `drone-worker` | Python | OpenTelemetry |
| `maintenance-api` | Node.js | OneAgent |
| `orbit-ai` | Python FastAPI | OpenTelemetry |
| `mock-llm` | Python FastAPI | OpenTelemetry |
| `faas-trigger` | Python | OpenTelemetry |
| `rpc-probe` / `rpc-target` | Python | OpenTelemetry |

## Key Conventions

**OTel auto-config:** The `nebulatrace` namespace is labeled `nebulatrace.dev/otel=true`. OTel pods are annotated `otlp-exporter-configuration.dynatrace.com/inject=true`. The Dynatrace Operator injects OTLP endpoints and tokens — never hardcode them in app code.

**`OTEL_RESOURCE_ATTRIBUTES`:** Shared release/env context for all containers. Comes from `.env`. Do not include `service.name` here; that's per-workload via `metadata.dynatrace.com/service` and OTel SDK config.

**Trace stitching:** FastAPI services must use OTel FastAPI + `requests` instrumentation. ActiveMQ paths must propagate W3C context in STOMP headers. Don't break the stitched chains above.

**Istio tracing:** Uses OTel extension provider `dynatrace-otel`. Envoy sends spans to `${DYNAKUBE_NAME}-telemetry-ingest.dynatrace.svc.cluster.local:4318/v1/traces`. Do not route through a generic collector when this endpoint is available.

**`DT_API_TOKEN`:** Must be an environment Access Token (`dt0c01.*`), not a Platform Token (`dt0s16.*`). Required scopes: `DataExport`, `activeGateTokenManagement.create`, `InstallerDownload`.

## Secret Hygiene

Before committing, check for leaked tokens:
```bash
git grep -n dt0 -- . ':!.env'
git grep -n live.dynatrace.com -- . ':!.env'
```

Never commit `.env`, real tokens, kubeconfigs, or tenant-specific values. `.env.example` must contain placeholders only.

## Avoid

- Do not reintroduce RabbitMQ.
- Do not switch back to Classic Istio monitoring as the primary Istio story.
- Do not add new deps when stdlib suffices.
- Do not return HTTP 200 from proxy/facade routes when downstream failed.
- Do not add dashboards before telemetry shape is stable.
