apiVersion: v1
kind: Secret
metadata:
  name: dynakube
  namespace: dynatrace
type: Opaque
stringData:
  apiToken: "${DT_API_TOKEN}"
  dataIngestToken: "${DT_API_TOKEN}"
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
  oneAgent:
    applicationMonitoring:
      namespaceSelector:
        matchLabels:
          nebulatrace.dev/oneagent: "true"
  activeGate:
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
