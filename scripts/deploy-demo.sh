#!/usr/bin/env bash
set -euo pipefail

IMAGE_REGISTRY_OVERRIDE="${IMAGE_REGISTRY:-}"
IMAGE_TAG_OVERRIDE="${IMAGE_TAG:-}"

load_env_file() {
  local line key value
  while IFS= read -r line || [ -n "$line" ]; do
    line="${line%$'\r'}"
    case "$line" in
      ""|\#*) continue ;;
    esac
    key="${line%%=*}"
    value="${line#*=}"
    if [[ "$key" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
      export "$key=$value"
    fi
  done < "$1"
}

if [ -f .env ]; then
  load_env_file .env
fi

export IMAGE_REGISTRY="${IMAGE_REGISTRY:-nebulatrace}"
export IMAGE_TAG="${IMAGE_TAG:-dev}"
export OTEL_RESOURCE_ATTRIBUTES="${OTEL_RESOURCE_ATTRIBUTES:-deployment.release_stage=demo,primary_tags.env=demo,deployment.release_version=0.1.0,primary_tags.version=0.1.0,primary_tags.app=nebulatrace,k8s.namespace.label.team=service-monitoring,dt.owner=service-monitoring}"
export DT_CUSTOM_PROP="${DT_CUSTOM_PROP:-dt.owner=service-monitoring}"
export LOADGEN_DELAY_MS="${LOADGEN_DELAY_MS:-750}"
export LOADGEN_BURST="${LOADGEN_BURST:-1}"
export FAAS_TRIGGER_DELAY_MS="${FAAS_TRIGGER_DELAY_MS:-5000}"
export RPC_PROBE_DELAY_MS="${RPC_PROBE_DELAY_MS:-2500}"

if [ -n "$IMAGE_REGISTRY_OVERRIDE" ]; then
  export IMAGE_REGISTRY="$IMAGE_REGISTRY_OVERRIDE"
fi

if [ -n "$IMAGE_TAG_OVERRIDE" ]; then
  export IMAGE_TAG="$IMAGE_TAG_OVERRIDE"
fi

if ! command -v envsubst >/dev/null 2>&1; then
  echo "envsubst is required. Install gettext-base."
  exit 1
fi

kubectl apply -f deploy/k8s/namespaces.yaml
kubectl apply -f deploy/k8s/data/postgres-init.yaml
envsubst < deploy/k8s/data/data.yaml | kubectl apply -f -
envsubst < deploy/k8s/app/app.yaml.tpl | kubectl apply -f -
kubectl apply -f deploy/k8s/istio/istio.yaml

kubectl -n nebulatrace rollout status deployment/command-api --timeout=180s || true
kubectl -n nebulatrace get pods
