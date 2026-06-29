#!/usr/bin/env bash
# NebulaTrace full setup: Istio + Dynatrace Operator + app
# Usage:
#   DT_TENANT_URL=https://abc123.live.dynatrace.com DT_API_TOKEN=dt0c01.xxx bash setup.sh
#   curl -sL https://raw.githubusercontent.com/tristanmarl/nebulatrace/main/setup.sh | DT_TENANT_URL=... DT_API_TOKEN=... bash
set -euo pipefail

# ── Config (all overridable via env) ─────────────────────────────────────────

: "${DT_TENANT_URL:?DT_TENANT_URL is required (e.g. https://abc123.live.dynatrace.com)}"
: "${DT_API_TOKEN:?DT_API_TOKEN is required (environment Access Token, dt0c01.*)}"

if [[ "${DT_API_TOKEN}" == dt0s16* ]]; then
  echo "ERROR: DT_API_TOKEN looks like a Platform Token (dt0s16.*). Use an environment Access Token (dt0c01.*)." >&2
  exit 1
fi

export DT_DATA_INGEST_TOKEN="${DT_DATA_INGEST_TOKEN:-$DT_API_TOKEN}"
export DYNAKUBE_NAME="${DYNAKUBE_NAME:-nebulatrace}"
export K8S_CLUSTER_NAME="${K8S_CLUSTER_NAME:-nebulatrace-demo}"
export ACTIVEGATE_IMAGE="${ACTIVEGATE_IMAGE:-docker.io/dynatrace/dynatrace-activegate:1.339.39.20260605-153224}"
export LOGMONITORING_IMAGE_REPOSITORY="${LOGMONITORING_IMAGE_REPOSITORY:-public.ecr.aws/dynatrace/dynatrace-logmodule}"
export LOGMONITORING_IMAGE_TAG="${LOGMONITORING_IMAGE_TAG:-1.339.51.20260603-143443}"
export OTEL_COLLECTOR_IMAGE_REPOSITORY="${OTEL_COLLECTOR_IMAGE_REPOSITORY:-public.ecr.aws/dynatrace/dynatrace-otel-collector}"
export OTEL_COLLECTOR_IMAGE_TAG="${OTEL_COLLECTOR_IMAGE_TAG:-latest}"
export IMAGE_REGISTRY="${IMAGE_REGISTRY:-ghcr.io/tristanmarl/nebulatrace}"
export IMAGE_TAG="${IMAGE_TAG:-latest}"
export OTEL_RESOURCE_ATTRIBUTES="${OTEL_RESOURCE_ATTRIBUTES:-deployment.release_stage=demo,primary_tags.env=demo,deployment.release_version=0.1.0,primary_tags.version=0.1.0,primary_tags.app=nebulatrace,k8s.namespace.label.team=service-monitoring,dt.owner=service-monitoring}"
export DT_CUSTOM_PROP="${DT_CUSTOM_PROP:-dt.owner=service-monitoring}"
export LOADGEN_DELAY_MS="${LOADGEN_DELAY_MS:-750}"
export LOADGEN_BURST="${LOADGEN_BURST:-1}"
export FAAS_TRIGGER_DELAY_MS="${FAAS_TRIGGER_DELAY_MS:-5000}"
export RPC_PROBE_DELAY_MS="${RPC_PROBE_DELAY_MS:-2500}"

DT_API_URL="${DT_TENANT_URL%/}"
DT_API_URL="${DT_API_URL/.apps./.}"
export DT_API_URL

# ── Helpers ───────────────────────────────────────────────────────────────────

need() { command -v "$1" >/dev/null 2>&1 || { echo "ERROR: $1 is required but not installed." >&2; exit 1; }; }

step() { echo; echo "==> $*"; }

# ── Preflight ─────────────────────────────────────────────────────────────────

need kubectl
need helm
need istioctl
need envsubst

step "Preflight: checking cluster access"
kubectl cluster-info --request-timeout=10s >/dev/null

# ── Namespaces ────────────────────────────────────────────────────────────────

step "Creating namespaces"
kubectl apply -f - <<YAML
apiVersion: v1
kind: Namespace
metadata:
  name: dynatrace
---
apiVersion: v1
kind: Namespace
metadata:
  name: nebulatrace
  labels:
    istio-injection: enabled
    nebulatrace.dev/otel: "true"
    nebulatrace.dev/oneagent: "true"
---
apiVersion: v1
kind: Namespace
metadata:
  name: nebulatrace-data
  labels:
    istio-injection: disabled
    nebulatrace.dev/oneagent: "true"
YAML

# ── Istio ─────────────────────────────────────────────────────────────────────

step "Installing Istio (profile: demo)"
meshconfig="$(mktemp)"
cat > "$meshconfig" <<YAML
apiVersion: install.istio.io/v1alpha1
kind: IstioOperator
spec:
  profile: demo
  meshConfig:
    defaultConfig:
      tracing:
        sampling: 100
    extensionProviders:
      - name: dynatrace-otel
        opentelemetry:
          service: ${DYNAKUBE_NAME}-telemetry-ingest.dynatrace.svc.cluster.local
          port: 4318
          http:
            path: /v1/traces
            timeout: 10s
          resource_detectors:
            dynatrace: {}
YAML
istioctl install -y -f "$meshconfig"
rm -f "$meshconfig"

# ── Dynatrace Operator ────────────────────────────────────────────────────────

step "Installing Dynatrace Operator (v1.10.0-rc.0)"
helm upgrade --install dynatrace-operator oci://public.ecr.aws/dynatrace/dynatrace-operator \
  --version 1.10.0-rc.0 \
  --namespace dynatrace \
  --create-namespace \
  --atomic

step "Applying DynaKube"
DYNAKUBE_MANIFEST="$(mktemp)"
cat > "$DYNAKUBE_MANIFEST" <<'YAML'
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
YAML
envsubst < "$DYNAKUBE_MANIFEST" | kubectl apply -f -
rm -f "$DYNAKUBE_MANIFEST"

# ── App ───────────────────────────────────────────────────────────────────────

step "Deploying NebulaTrace app"
MANIFEST_URL="https://raw.githubusercontent.com/tristanmarl/nebulatrace/main/deploy/dist/nebulatrace.yaml"
if [ -f "deploy/dist/nebulatrace.yaml" ]; then
  # Running from repo checkout — use local copy with env substitution
  envsubst < deploy/dist/nebulatrace.yaml | kubectl apply -f -
else
  # Running via curl — fetch and apply the pre-rendered public manifest
  curl -sL "$MANIFEST_URL" | kubectl apply -f -
fi

step "Waiting for app rollout"
kubectl -n nebulatrace rollout status deployment/command-api --timeout=180s || true

# ── Done ──────────────────────────────────────────────────────────────────────

echo
echo "Setup complete."
echo
echo "App URL:"
kubectl -n istio-system get svc istio-ingressgateway \
  --output=jsonpath='  http://{.status.loadBalancer.ingress[0].ip}{"\n"}' 2>/dev/null || \
  echo "  Run: kubectl -n istio-system get svc istio-ingressgateway"
echo
echo "Dynatrace Operator status:"
echo "  kubectl get dynakubes -n dynatrace"
