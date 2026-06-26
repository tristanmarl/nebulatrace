# NebulaTrace

NebulaTrace is a sci-fi Kubernetes observability demo for Dynatrace. The starship
**CSS Observable** runs cargo, mission, drone-repair, credit, and AI services.
The ship AI, **ORBIT**, helps investigate incidents while the **Entropy Drive**
creates slow SQL, queue backlogs, failed requests, Istio routing faults, and AI
anomalies.

## What It Demonstrates

- Kubernetes multi-service application
- Istio ingress, mesh traffic, routing, and fault injection
- PostgreSQL, RabbitMQ, and Redis dependencies
- Dynatrace Operator and OneAgent-monitored workloads
- OpenTelemetry workloads using Dynatrace Operator OTLP auto-configuration
- Newer Istio service detection direction through propagated trace context and
  Unified services / SDv2, with supplemental Envoy/Istio metrics
- AI incident investigation prompts for `dynatrace-for-ai`

## Quick Start

Prerequisites:

- Docker
- `kubectl`, `helm`, and `istioctl`
- a Kubernetes cluster
- a Dynatrace tenant token

You do not need local Node, Go, Maven, Java, or Python packages. Each service
builds inside its Dockerfile.

## Build Locally

```bash
make build-images
```

This builds local images like `nebulatrace/command-api:dev`.

## Deploy

### Local k3s

For a local k3s cluster, no container registry is required:

```bash
kubectl get nodes
make k3s-deploy
make app-url
```

This builds images as `nebulatrace/<service>:dev`, imports them into k3s
containerd, installs Istio, and deploys the app.

Dynatrace is optional for this local smoke test. To include Dynatrace, create
`.env` from `.env.example`, set `DT_TENANT_URL` and `DT_API_TOKEN`, then run:

```bash
make install-dynatrace
kubectl rollout restart deployment -n nebulatrace
```

If your Dynatrace URL contains `.apps.`, the install script removes that segment
for the Operator API URL.

The install script uses the Dynatrace Operator OCI chart pinned to
`1.10.0-rc.0`.

`DT_API_TOKEN` must be a Dynatrace environment Access Token, not a Platform
Token. A token starting with `dt0s16` is a Platform Token and the Operator will
report `Token does not exist` against the environment API.

For this DynaKube profile, `DT_API_TOKEN` must include at least:

- `DataExport`
- `activeGateTokenManagement.create`
- `InstallerDownload`

`DT_DATA_INGEST_TOKEN` is optional. If omitted, `DT_API_TOKEN` is reused. If you
provide a separate ingest token, it must include:

- `openTelemetryTrace.ingest`
- `logs.ingest`
- `metrics.ingest`

The Operator may also warn about optional `settings.read` and `settings.write`
scopes.

Useful Operator checks:

```bash
kubectl get dynakubes -n dynatrace
kubectl exec deploy/dynatrace-operator -n dynatrace -- dynatrace-operator troubleshoot
kubectl -n dynatrace describe dynakube nebulatrace
kubectl -n dynatrace logs deploy/dynatrace-operator --tail=200
```

### Registry-backed cluster

```bash
cp .env.example .env
# Edit .env with DT_TENANT_URL, DT_API_TOKEN, IMAGE_REGISTRY, and IMAGE_TAG.
make build-images
make push-images
make install-istio
make install-dynatrace
make deploy
make app-url
```

Set `IMAGE_REGISTRY` to a registry your Kubernetes cluster can pull from before
running `make push-images`.

## Using GHCR

For GitHub Container Registry, use this in `.env`:

```bash
IMAGE_REGISTRY=ghcr.io/tristanmarl/nebulatrace
IMAGE_TAG=latest
```

The build creates one image per service, for example:

```text
ghcr.io/tristanmarl/nebulatrace/bridge-ui:latest
ghcr.io/tristanmarl/nebulatrace/command-api:latest
ghcr.io/tristanmarl/nebulatrace/cargo-api:latest
```

Before pushing from your machine, log Docker into GHCR:

```bash
gh auth token | docker login ghcr.io -u tristanmarl --password-stdin
```

Your GitHub token must be allowed to write packages. If `docker push` returns a
permission error, create a GitHub token with `write:packages` and run:

```bash
echo "YOUR_TOKEN" | docker login ghcr.io -u tristanmarl --password-stdin
```

For public images, Kubernetes can usually pull without an image pull secret.

## Demo Curses

```bash
make entropy-slow-db
make entropy-queue-backlog
make entropy-credit-errors
make entropy-wormhole-route
make entropy-ai-anomaly
make reset
```

## OTLP Auto-Configuration

The app namespace is labeled `nebulatrace.dev/otel=true`. OpenTelemetry pods are
annotated with `otlp-exporter-configuration.dynatrace.com/inject=true`. The
Dynatrace Operator injects OTLP endpoints, headers, token access, and Kubernetes
resource attributes into those pods. Application code only uses standard OTel
environment variables.

## Newer Istio Method

NebulaTrace does not use Classic Istio monitoring as the primary story. App
spans from OneAgent and OpenTelemetry carry trace context through the mesh and
are modeled as Dynatrace services, including Unified services / SDv2 for
OTel-ingested workloads. Envoy/Istio metric scraping is supplemental.
