#!/usr/bin/env bash
set -euo pipefail

source .env

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
