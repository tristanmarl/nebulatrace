# NebulaTrace

Sci-fi Kubernetes observability demo for Dynatrace. The starship **CSS Observable** runs cargo, mission, drone-repair, credit, and AI services. The ship AI **ORBIT** helps investigate incidents while the **Entropy Drive** injects faults.

**Demonstrates:** Dynatrace OneAgent · OpenTelemetry (OTLP auto-config) · Istio mesh tracing · PostgreSQL / ActiveMQ / Redis · gRPC · FaaS telemetry · AI incident investigation

## Prerequisites

- Docker, `kubectl`, `helm`, `istioctl`
- A Kubernetes cluster
- A Dynatrace tenant with an environment Access Token (`dt0c01.*`) scoped for `DataExport`, `activeGateTokenManagement.create`, `InstallerDownload`

No local Node, Go, Java, or Python needed — everything builds inside Docker.

## Deploy

### Option A — one-line install (cluster already has Istio + Dynatrace Operator)

```bash
kubectl apply -f https://raw.githubusercontent.com/tristanmarl/nebulatrace/main/deploy/dist/nebulatrace.yaml
```

Images are public on GHCR (`ghcr.io/tristanmarl/nebulatrace/<service>:latest`).

### Option B — full setup from scratch

```bash
cp .env.example .env
# Edit .env: set DT_TENANT_URL, DT_API_TOKEN, K8S_CLUSTER_NAME
make install-istio
make install-dynatrace
make deploy
make app-url
```

### Option C — local k3s (no registry needed)

```bash
make k3s-deploy   # builds images, loads into k3s containerd, installs Istio, deploys app
make app-url
```

To add Dynatrace: set `DT_TENANT_URL` and `DT_API_TOKEN` in `.env`, then `make install-dynatrace`.

## Configuration

All settings live in `.env` (copy from `.env.example`). Key variables:

| Variable | Purpose |
|---|---|
| `DT_TENANT_URL` | `https://<id>.live.dynatrace.com` |
| `DT_API_TOKEN` | Environment Access Token (`dt0c01.*`) |
| `K8S_CLUSTER_NAME` | Name shown in Dynatrace |
| `OTEL_RESOURCE_ATTRIBUTES` | Shared release/env context for all workloads |
| `LOADGEN_DELAY_MS` | Load generator request interval (default 750) |
| `IMAGE_REGISTRY` | Registry for built images (default `ghcr.io/tristanmarl/nebulatrace`) |

## Day-Two

```bash
make status           # pod/deployment status
make restart          # rolling restart of all workloads
make stop / start     # scale app to 0/1 (leaves Dynatrace + Istio running)
make set-owner OWNER=service-monitoring
```

## Entropy (fault injection)

```bash
./scripts/entropy-slow-db.sh
./scripts/entropy-queue-backlog.sh
./scripts/entropy-credit-errors.sh
./scripts/entropy-wormhole-route.sh
./scripts/entropy-ai-anomaly.sh
make reset            # undo all entropy
```

## Publishing Images

CI builds and pushes on every push to `main`. To publish manually:

```bash
gh auth token | docker login ghcr.io -u tristanmarl --password-stdin
make publish          # build + push all images + re-render deploy/dist/nebulatrace.yaml
```

To regenerate only the dist manifest:

```bash
./scripts/render-install-yaml.sh --no-env   # uses public GHCR refs
./scripts/render-install-yaml.sh            # uses your local .env
```

## Architecture

```
[load-generator / faas-trigger] → command-api → cargo-api    (Java/PostgreSQL/OneAgent)
                                              → mission-api   (Python/ActiveMQ/OTel)
                                              → credits-api   (Go/Redis/OneAgent)
                                              → orbit-ai      (Python/OTel) → mock-llm

mission-api → ActiveMQ drone.jobs → drone-worker → maintenance-api

rpc-probe → rpc-target   (gRPC, mixed status codes)
```

Two namespaces: `nebulatrace` (app, Istio sidecar) · `nebulatrace-data` (PostgreSQL, ActiveMQ, Redis)

## Dynatrace Token Scopes

`DT_API_TOKEN` must be an environment Access Token (`dt0c01.*`), **not** a Platform Token (`dt0s16.*`).

Required: `DataExport`, `activeGateTokenManagement.create`, `InstallerDownload`

Optional separate `DT_DATA_INGEST_TOKEN`: `openTelemetryTrace.ingest`, `logs.ingest`, `metrics.ingest`

Operator troubleshooting:
```bash
kubectl get dynakubes -n dynatrace
kubectl exec deploy/dynatrace-operator -n dynatrace -- dynatrace-operator troubleshoot
kubectl -n dynatrace logs deploy/dynatrace-operator --tail=200
```
