#!/usr/bin/env bash
set -euo pipefail

kubectl apply -f deploy/k8s/namespaces.yaml

if ! command -v istioctl >/dev/null 2>&1; then
  echo "istioctl is required. Install it from https://istio.io/latest/docs/setup/getting-started/"
  exit 1
fi

istioctl install -y --set profile=demo
kubectl label namespace nebulatrace istio-injection=enabled --overwrite
