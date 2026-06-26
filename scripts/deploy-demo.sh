#!/usr/bin/env bash
set -euo pipefail

IMAGE_REGISTRY_OVERRIDE="${IMAGE_REGISTRY:-}"
IMAGE_TAG_OVERRIDE="${IMAGE_TAG:-}"

if [ -f .env ]; then
  source <(sed 's/\r$//' .env)
fi

export IMAGE_REGISTRY="${IMAGE_REGISTRY:-nebulatrace}"
export IMAGE_TAG="${IMAGE_TAG:-dev}"
export LOADGEN_DELAY_MS="${LOADGEN_DELAY_MS:-750}"
export LOADGEN_BURST="${LOADGEN_BURST:-1}"

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
kubectl apply -f deploy/k8s/data/data.yaml
envsubst < deploy/k8s/app/app.yaml.tpl | kubectl apply -f -
kubectl apply -f deploy/k8s/istio/istio.yaml

kubectl -n nebulatrace rollout status deployment/command-api --timeout=180s || true
kubectl -n nebulatrace get pods
