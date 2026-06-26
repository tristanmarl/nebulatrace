# AGENTS.md

Guidance for coding agents working on NebulaTrace.

## Project Intent

NebulaTrace is a beginner-friendly Dynatrace Kubernetes observability demo. Keep
it realistic enough to run, but small enough to understand in one sitting.

The demo should show:

- Kubernetes app/service topology
- Dynatrace Operator, OneAgent, standalone Log Agent, and OTLP auto-config
- OpenTelemetry traces, metrics, and logs
- Istio mesh traffic and Envoy OTLP tracing
- ActiveMQ Classic monitored through OneAgent/JVM/JMX-style visibility
- Constant demo load with some successful and failing requests
- Mocked FaaS-style trigger telemetry through `faas-trigger`
- AI-themed telemetry through `orbit-ai` and `mock-llm`

## Style

- Prefer the simplest thing that works.
- Avoid framework churn, platform rewrites, and speculative abstractions.
- Keep services small and explicit.
- Favor standard library code where it is clear enough.
- Use Dockerfiles as the build boundary. Do not require local Node, Go, Maven,
  Java, or Python packages for normal build/test flows.
- Keep docs practical: commands that work, expected results, and short
  troubleshooting notes.

## Security

- Never commit `.env`, real Dynatrace tokens, GHCR tokens, tenant-specific
  secrets, or kubeconfigs.
- Before committing, run a quick secret check such as:

  ```bash
  git grep -n dt0 -- . ':!.env'
  git grep -n dynatracelabs -- . ':!.env'
  git grep -n live.dynatrace.com -- . ':!.env'
  ```

- `.env.example` must contain placeholders only.
- If a token was exposed during debugging, tell the user to rotate it.

## Architecture Choices

- Queue: ActiveMQ Classic, not RabbitMQ.
- Database: PostgreSQL.
- Cache: Redis.
- Mesh: Istio sidecars for app services in `nebulatrace`.
- Data namespace: `nebulatrace-data`, Istio disabled, OneAgent enabled for
  ActiveMQ.
- Constant load: `load-generator` runs in Kubernetes by default.
- Mocked FaaS trigger: `faas-trigger` emits OTel spans with `faas.trigger`
  attributes for AWS Lambda, Azure Functions, and Google Cloud Functions, then
  calls `command-api`.
- Failing traffic: the load generator intentionally emits some 500s and 404s.

## Dynatrace Choices

- Dynatrace Operator is installed from the OCI chart.
- OneAgent application monitoring is used for selected workloads.
- Standalone Log Agent is enabled with `spec.logMonitoring`.
- OTel workloads rely on Dynatrace Operator OTLP auto-configuration.
- Do not hardcode OTLP endpoints or tokens in application code.
- Shared release/environment context is a plain comma-separated
  `OTEL_RESOURCE_ATTRIBUTES` value from `.env`, passed to every container
  without mapping logic. Do not set `service.name` in this shared value.
- Istio traces use an OpenTelemetry extension provider that sends Envoy spans to
  the Dynatrace Operator telemetry ingest service:
  `nebulatrace-telemetry-ingest.dynatrace.svc.cluster.local:4318/v1/traces`.
- ActiveMQ is OneAgent-injected so the Dynatrace Apache ActiveMQ Classic/JMX
  extension can be enabled in the tenant.

## Trace Stitching

Topology depends on stitched traces. Preserve these rules:

- FastAPI services should use OpenTelemetry FastAPI instrumentation.
- Python HTTP clients should use OpenTelemetry `requests` instrumentation.
- ActiveMQ publish/consume should propagate W3C context through STOMP headers.
- Normal mission traffic should stitch as:

  ```text
  command-api -> mission-api -> ActiveMQ drone.jobs -> drone-worker -> maintenance-api
  ```

- AI traffic should stitch as:

  ```text
  command-api -> orbit-ai -> mock-llm
  ```

- Mock FaaS traffic should start as:

  ```text
  faas-trigger -> command-api -> mission-api
  ```

## Custom Metrics

Keep service metrics domain-specific and demo-friendly. Current examples:

- `nebulatrace.missions.created`
- `nebulatrace.missions.failures`
- `nebulatrace.missions.db.latency_ms`
- `nebulatrace.missions.activemq.publish.latency_ms`
- `nebulatrace.missions.activemq.published`
- `nebulatrace.drone.jobs.consumed`
- `nebulatrace.drone.jobs.failed`
- `nebulatrace.drone.job.latency_ms`
- `nebulatrace.drone.maintenance.latency_ms`
- `nebulatrace.orbit.recommendations`
- `nebulatrace.orbit.llm.latency_ms`
- `nebulatrace.llm.calls`
- `nebulatrace.llm.tokens`
- `nebulatrace.llm.hallucinations`
- `nebulatrace.faas.triggered`
- `nebulatrace.faas.failures`
- `nebulatrace.faas.downstream.latency_ms`

## Local Verification

For k3s/local work, prefer:

```bash
make k3s-load-images
IMAGE_REGISTRY=nebulatrace IMAGE_TAG=dev ./scripts/deploy-demo.sh
kubectl -n nebulatrace get pods
kubectl -n nebulatrace-data get pods
kubectl -n dynatrace get dynakube nebulatrace
```

Useful runtime checks:

```bash
kubectl -n nebulatrace logs deploy/load-generator -c load-generator --tail=50
kubectl -n nebulatrace logs deploy/faas-trigger -c faas-trigger --tail=50
kubectl -n dynatrace logs statefulset/nebulatrace-otel-collector --tail=80
kubectl -n dynatrace logs daemonset/nebulatrace-logmonitoring --tail=80
kubectl -n nebulatrace-data describe pod activemq-0
```

ActiveMQ queue counter check:

```bash
kubectl -n nebulatrace-data exec activemq-0 -- wget -qO- \
  --header='Origin: http://localhost:8161' \
  --user=admin --password=admin \
  'http://localhost:8161/api/jolokia/read/org.apache.activemq:type=Broker,brokerName=localhost,destinationType=Queue,destinationName=drone.jobs/QueueSize,EnqueueCount,DequeueCount,ConsumerCount'
```

Istio trace provider check:

```bash
python3 -c "import subprocess; data=subprocess.check_output(['istioctl','proxy-config','listeners','deployment/command-api.nebulatrace','-o','json'], text=True); print('\\n'.join(n for n in ['opentelemetry','telemetry-ingest','dynatrace'] if n in data.lower()))"
```

## Git And Images

- Commit cohesive changes with clear messages.
- Push repo changes to `main` when requested.
- If app code changes, rebuild and push affected GHCR images.
- GHCR package visibility is separate from repository visibility. If packages
  are private, users need an image pull secret.

## Avoid

- Do not reintroduce RabbitMQ unless explicitly requested.
- Do not switch back to Classic Istio monitoring as the primary story.
- Do not route Istio traces through a generic collector when the Operator
  telemetry ingest endpoint is available.
- Do not add a new dependency just for convenience if a tiny standard-library
  solution is clear.
- Do not add dashboards before telemetry shape is stable.
- Do not hide errors by returning HTTP 200 from proxy/facade routes when the
  downstream failed.
