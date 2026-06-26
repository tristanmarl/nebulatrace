#!/usr/bin/env bash
set -euo pipefail

source <(sed 's/\r$//' .env)

if [[ "${DT_API_TOKEN:-}" == dt0s16* ]]; then
  echo "DT_API_TOKEN looks like a Dynatrace Platform Token (dt0s16...)."
  echo "Use an environment Access Token from Access Tokens with the Kubernetes: Dynatrace Operator template."
  exit 1
fi

export DT_DATA_INGEST_TOKEN="${DT_DATA_INGEST_TOKEN:-$DT_API_TOKEN}"

DT_API_URL="${DT_TENANT_URL%/}"
DT_API_URL="${DT_API_URL/.apps./.}"
export DT_API_URL

kubectl apply -f deploy/k8s/namespaces.yaml
helm repo add dynatrace https://raw.githubusercontent.com/Dynatrace/dynatrace-operator/main/config/helm/repos/stable
helm repo update dynatrace
helm upgrade --install dynatrace-operator dynatrace/dynatrace-operator \
  --namespace dynatrace \
  --create-namespace \
  --atomic

if ! command -v envsubst >/dev/null 2>&1; then
  echo "envsubst is required. Install gettext-base."
  exit 1
fi

envsubst < deploy/k8s/dynatrace/dynakube.yaml.tpl | kubectl apply -f -
