# Telemetry

## Dynatrace Operator

`deploy/k8s/dynatrace/dynakube.yaml.tpl` uses `dynatrace.com/v1beta6`, the
recommended DynaKube API version for Dynatrace Operator 1.8+. The template
enables:

- application monitoring for OneAgent opt-in pods
- ActiveGate for Kubernetes monitoring and routing
- log monitoring
- OTLP exporter auto-configuration for traces, metrics, and logs

Docs:

- https://docs.dynatrace.com/docs/ingest-from/setup-on-k8s/extend-observability-k8s/otlp-auto-config
- https://docs.dynatrace.com/docs/ingest-from/setup-on-k8s/reference/dynakube-parameters

## OneAgent Workloads

The following pods opt into OneAgent with
`oneagent.dynatrace.com/inject: "true"`:

- `bridge-ui`
- `command-api`
- `cargo-api`
- `credits-api`
- `maintenance-api`

## OpenTelemetry Workloads

The following pods opt into OTLP auto-config with
`otlp-exporter-configuration.dynatrace.com/inject: "true"`:

- `mission-api`
- `drone-worker`
- `orbit-ai`
- `mock-llm`

The application code does not set OTLP endpoints or tokens. Dynatrace Operator
injects `DT_API_TOKEN`, signal-specific `OTEL_EXPORTER_OTLP_*` variables, and
Kubernetes-enriched `OTEL_RESOURCE_ATTRIBUTES`.

## AI Signals

`orbit-ai` and `mock-llm` emit:

- spans: `orbit.recommend_mission`, `llm.call`
- attributes: `ai.model.name`, `ai.prompt.type`, `ai.response.status`,
  `ai.tokens.input`, `ai.tokens.output`
- metrics: `nebulatrace.orbit.tokens`, `nebulatrace.orbit.failures`

The demo logs prompt category and trace context, not prompt bodies.
