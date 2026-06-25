# Istio And Unified Services

NebulaTrace uses the newer Dynatrace service-detection direction:

- Application traces come from OneAgent and OpenTelemetry SDKs.
- W3C trace context flows through Istio sidecars with normal HTTP traffic.
- OpenTelemetry resource attributes are enriched by Dynatrace Operator.
- Dynatrace can model OTel-ingested services as Unified services / SDv2.

ActiveGate Prometheus scraping is supplemental. It is useful for Envoy/Istio
metrics, but the demo does not treat Classic Istio metric scraping as the main
service model.

Optional advanced branch: Envoy 1.30+ can export traces through OpenTelemetry,
but that needs mesh-level Envoy configuration and carries an OSS integration
support caveat in Dynatrace docs. Keep it out of the beginner path.

Relevant docs:

- https://docs.dynatrace.com/docs/observe/application-observability/services/service-detection/service-detection-v1/service-types/unified-service
- https://docs.dynatrace.com/docs/ingest-from/opentelemetry/integrations/envoy
