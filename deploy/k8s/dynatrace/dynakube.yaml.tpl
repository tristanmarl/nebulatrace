apiVersion: v1
kind: Secret
metadata:
  name: dynakube
  namespace: dynatrace
type: Opaque
stringData:
  apiToken: "${DT_API_TOKEN}"
  dataIngestToken: "${DT_DATA_INGEST_TOKEN}"
---
apiVersion: dynatrace.com/v1beta6
kind: DynaKube
metadata:
  name: nebulatrace
  namespace: dynatrace
  annotations:
    feature.dynatrace.com/automatic-injection: "false"
spec:
  apiUrl: "${DT_API_URL}/api"
  tokens: dynakube
  enableIstio: true
  metadataEnrichment:
    enabled: true
  logMonitoring: {}
  telemetryIngest:
    protocols:
      - otlp
  templates:
    logMonitoring:
      imageRef:
        repository: "${LOGMONITORING_IMAGE_REPOSITORY}"
        tag: "${LOGMONITORING_IMAGE_TAG}"
    otelCollector:
      imageRef:
        repository: "${OTEL_COLLECTOR_IMAGE_REPOSITORY}"
        tag: "${OTEL_COLLECTOR_IMAGE_TAG}"
  oneAgent:
    applicationMonitoring:
      namespaceSelector:
        matchLabels:
          nebulatrace.dev/oneagent: "true"
  activeGate:
    image: "${ACTIVEGATE_IMAGE}"
    capabilities:
      - kubernetes-monitoring
      - routing
      - dynatrace-api
  otlpExporterConfiguration:
    namespaceSelector:
      matchLabels:
        nebulatrace.dev/otel: "true"
    signals:
      metrics: {}
      traces: {}
      logs: {}
