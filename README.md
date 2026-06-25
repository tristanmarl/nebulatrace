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
