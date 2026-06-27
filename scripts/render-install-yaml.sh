#!/usr/bin/env bash
set -euo pipefail

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

USE_ENV=1
if [ "${1:-}" = "--no-env" ]; then
  USE_ENV=0
fi

if [ "$USE_ENV" -eq 1 ] && [ -f .env ]; then
  load_env_file .env
fi

export IMAGE_REGISTRY="${IMAGE_REGISTRY:-ghcr.io/example-org/nebulatrace}"
export IMAGE_TAG="${IMAGE_TAG:-latest}"
export OTEL_RESOURCE_ATTRIBUTES="${OTEL_RESOURCE_ATTRIBUTES:-deployment.release_stage=demo,primary_tags.env=demo,deployment.release_version=0.1.0,primary_tags.version=0.1.0,primary_tags.app=nebulatrace,k8s.namespace.label.team=service-monitoring,dt.owner=service-monitoring}"
export LOADGEN_DELAY_MS="${LOADGEN_DELAY_MS:-750}"
export LOADGEN_BURST="${LOADGEN_BURST:-1}"
export FAAS_TRIGGER_DELAY_MS="${FAAS_TRIGGER_DELAY_MS:-5000}"
export RPC_PROBE_DELAY_MS="${RPC_PROBE_DELAY_MS:-2500}"

if ! command -v envsubst >/dev/null 2>&1; then
  echo "envsubst is required. Install gettext-base."
  exit 1
fi

mkdir -p deploy/dist

{
  cat <<'YAML'
# NebulaTrace application demo.
# Prerequisites:
# - Dynatrace Operator and a healthy DynaKube already installed.
# - Istio already installed. The nebulatrace namespace enables sidecar injection.
# - Public container images under your configured IMAGE_REGISTRY.
# - A default StorageClass for PostgreSQL and ActiveMQ PVCs.
YAML
  cat deploy/k8s/namespaces.yaml
  echo "---"
  cat deploy/k8s/data/postgres-init.yaml
  echo "---"
  envsubst < deploy/k8s/data/data.yaml
  echo "---"
  envsubst < deploy/k8s/app/app.yaml.tpl
  echo "---"
  cat deploy/k8s/istio/istio.yaml
} > deploy/dist/nebulatrace.yaml

echo "Rendered deploy/dist/nebulatrace.yaml"
