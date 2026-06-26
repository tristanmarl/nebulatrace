# NebulaTrace

NebulaTrace is a sci-fi Kubernetes observability demo for Dynatrace. The starship
**CSS Observable** runs cargo, mission, drone-repair, credit, and AI services.
The ship AI, **ORBIT**, helps investigate incidents while the **Entropy Drive**
creates slow SQL, queue backlogs, failed requests, Istio routing faults, and AI
anomalies.

## What It Demonstrates

- Kubernetes multi-service application
- Istio ingress, mesh traffic, routing, and fault injection
- PostgreSQL, ActiveMQ Classic, and Redis dependencies
- Dynatrace Operator and OneAgent-monitored workloads
- OpenTelemetry workloads using Dynatrace Operator OTLP auto-configuration
- Istio service detection through propagated trace context, Envoy OTLP tracing,
  and Unified services / SDv2, with supplemental Envoy/Istio metrics
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
containerd, installs Istio with a Dynatrace OTLP tracing provider, and deploys
the app.

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

For local/dev tenants where the tenant registry ActiveGate image is unavailable,
the demo pins `ACTIVEGATE_IMAGE` to a public Docker Hub ActiveGate image.

Kubernetes container log collection uses the Dynatrace Operator standalone Log
module. The demo enables `spec.logMonitoring` in the `DynaKube` and pins the
public Log module image with:

```bash
LOGMONITORING_IMAGE_REPOSITORY=public.ecr.aws/dynatrace/dynatrace-logmodule
LOGMONITORING_IMAGE_TAG=1.339.51.20260603-143443
```

Istio service mesh traces use the Dynatrace Operator telemetry ingest endpoint.
The demo enables `spec.telemetryIngest.protocols: [otlp]` in the `DynaKube`.
This creates the Operator-managed telemetry ingest service that Envoy sends
OTLP/HTTP traces to:

```text
nebulatrace-telemetry-ingest.dynatrace.svc.cluster.local:4318/v1/traces
```

The demo pins the telemetry ingest collector image with:

```bash
OTEL_COLLECTOR_IMAGE_REPOSITORY=public.ecr.aws/dynatrace/dynatrace-otel-collector
OTEL_COLLECTOR_IMAGE_TAG=latest
```

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

GitHub repository visibility and GHCR package visibility are separate. If the
packages are public, Kubernetes can usually pull without an image pull secret.
If the packages are private, create an image pull secret in the app namespace:

```bash
kubectl -n nebulatrace create secret docker-registry ghcr-pull \
  --docker-server=ghcr.io \
  --docker-username=tristanmarl \
  --docker-password="$GHCR_TOKEN"
```

Then attach it to the default service account:

```bash
kubectl -n nebulatrace patch serviceaccount default \
  -p '{"imagePullSecrets":[{"name":"ghcr-pull"}]}'
```

## Demo Curses

```bash
make entropy-slow-db
make entropy-queue-backlog
make entropy-credit-errors
make entropy-wormhole-route
make entropy-ai-anomaly
make reset
```

## Constant Load

The Kubernetes deploy includes `load-generator`, a small Python service that
continuously calls `command-api` so Dynatrace always has fresh traffic, traces,
logs, queue work, and database activity to observe.

It also includes `faas-trigger`, a mocked serverless trigger workload. It emits
OpenTelemetry spans with `faas.trigger=pubsub`, W3C trace context, and rotating
mock provider attributes for AWS Lambda, Azure Functions, and Google Cloud
Functions before calling `command-api` to create missions. There is no real FaaS
platform dependency; it is just demo telemetry shaped like serverless triggers.

Tune it in `.env`:

```bash
LOADGEN_DELAY_MS=750
LOADGEN_BURST=1
FAAS_TRIGGER_DELAY_MS=5000
```

Useful controls:

```bash
kubectl -n nebulatrace logs deploy/load-generator -f
kubectl -n nebulatrace logs deploy/faas-trigger -f
kubectl -n nebulatrace scale deployment/load-generator --replicas=0
kubectl -n nebulatrace scale deployment/load-generator --replicas=1
kubectl -n nebulatrace scale deployment/faas-trigger --replicas=0
kubectl -n nebulatrace scale deployment/faas-trigger --replicas=1
```

## OTLP Auto-Configuration

The app namespace is labeled `nebulatrace.dev/otel=true`. OpenTelemetry pods are
annotated with `otlp-exporter-configuration.dynatrace.com/inject=true`. The
Dynatrace Operator injects OTLP endpoints, headers, token access, and Kubernetes
resource attributes into those pods. Application code only uses standard OTel
environment variables.

## Environment And Version Attributes

All demo containers set `OTEL_RESOURCE_ATTRIBUTES` explicitly so OneAgent and
OpenTelemetry workloads get the same release context. Configure the exact
comma-separated key/value list in `.env`:

```bash
OTEL_RESOURCE_ATTRIBUTES=deployment.release_stage=demo,primary_tags.env=demo,deployment.release_version=0.1.0,primary_tags.version=0.1.0,primary_tags.app=nebulatrace,k8s.namespace.label.team=service-monitoring
```

The Dynatrace Operator OTLP auto-configuration preserves these attributes and
adds its own Kubernetes/Dynatrace resource attributes to OTel pods. Avoid
putting `service.name` in this shared list; service naming is handled per
workload through `metadata.dynatrace.com/service` and each service's OTel
resource configuration.

## Trace Stitching And Metrics

The OTel Python services use FastAPI and HTTP client instrumentation so incoming
`traceparent` headers from OneAgent/Istio are extracted and outgoing calls
continue the same distributed trace. The ActiveMQ path carries W3C trace context
in STOMP headers, so mission creation should stitch as:

```text
command-api -> mission-api -> ActiveMQ drone.jobs -> drone-worker -> maintenance-api
```

Custom metrics include:

```text
nebulatrace.missions.created
nebulatrace.missions.failures
nebulatrace.missions.db.latency_ms
nebulatrace.missions.activemq.publish.latency_ms
nebulatrace.missions.activemq.published
nebulatrace.drone.jobs.consumed
nebulatrace.drone.jobs.failed
nebulatrace.drone.job.latency_ms
nebulatrace.drone.maintenance.latency_ms
nebulatrace.orbit.recommendations
nebulatrace.orbit.llm.latency_ms
nebulatrace.llm.calls
nebulatrace.llm.tokens
nebulatrace.llm.hallucinations
nebulatrace.faas.triggered
nebulatrace.faas.failures
nebulatrace.faas.downstream.latency_ms
```

The mocked FaaS spans use names and attributes such as:

```text
aws.lambda sqs trigger
azure.functions queue trigger
gcp.cloudfunctions pubsub trigger
cloud.provider=aws|azure|gcp
faas.trigger=pubsub
faas.invoked_name=<mock provider function>
```

## ActiveMQ

NebulaTrace uses ActiveMQ Classic for async drone jobs. The `activemq` broker
runs in `nebulatrace-data` with OneAgent injection enabled, which makes it a JVM
workload suitable for Dynatrace's Apache ActiveMQ Classic/JMX extension. Enable
the extension in Dynatrace for broker-level queue, enqueue/dequeue, consumer,
and memory metrics.

The producer and worker also emit OpenTelemetry messaging spans with:

```text
messaging.system=activemq
messaging.destination.name=drone.jobs
messaging.operation=publish|consume
```

## Newer Istio Method

NebulaTrace does not use Classic Istio monitoring as the primary story. Istio is
installed with an OpenTelemetry extension provider named `dynatrace-otel`.
Envoy sends mesh spans directly to the Dynatrace Operator telemetry ingest
service at `nebulatrace-telemetry-ingest.dynatrace.svc.cluster.local:4318` with
HTTP path `/v1/traces` and Dynatrace resource detection enabled.

App spans from OneAgent and OpenTelemetry still carry trace context through the
mesh and are modeled as Dynatrace services, including Unified services / SDv2
for OTel-ingested workloads. Envoy/Istio metric scraping is supplemental.
