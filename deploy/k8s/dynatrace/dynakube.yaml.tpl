apiVersion: v1
kind: Secret
metadata:
  name: "${DYNAKUBE_NAME}"
  namespace: dynatrace
type: Opaque
stringData:
  apiToken: "${DT_API_TOKEN}"
  dataIngestToken: "${DT_DATA_INGEST_TOKEN}"
---
apiVersion: dynatrace.com/v1beta6
kind: DynaKube
metadata:
  name: "${DYNAKUBE_NAME}"
  namespace: dynatrace
  annotations:
    feature.dynatrace.com/automatic-injection: "false"
spec:
  apiUrl: "${DT_API_URL}/api"
  tokens: "${DYNAKUBE_NAME}"
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
    resources:
      requests:
        cpu: 500m
        memory: 1.5Gi
      limits:
        cpu: 1000m
        memory: 1.5Gi
  otlpExporterConfiguration:
    namespaceSelector:
      matchLabels:
        nebulatrace.dev/otel: "true"
    signals:
      metrics: {}
      traces: {}
      logs: {}
