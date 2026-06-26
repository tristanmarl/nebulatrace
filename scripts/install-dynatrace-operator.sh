#!/usr/bin/env bash
set -euo pipefail

source <(sed 's/\r$//' .env)

if [[ "${DT_API_TOKEN:-}" == dt0s16* ]]; then
  echo "DT_API_TOKEN looks like a Dynatrace Platform Token (dt0s16...)."
  echo "Use an environment Access Token from Access Tokens with the Kubernetes: Dynatrace Operator template."
  exit 1
fi

export DT_DATA_INGEST_TOKEN="${DT_DATA_INGEST_TOKEN:-$DT_API_TOKEN}"
export ACTIVEGATE_IMAGE="${ACTIVEGATE_IMAGE:-docker.io/dynatrace/dynatrace-activegate:1.339.39.20260605-153224}"
export LOGMONITORING_IMAGE_REPOSITORY="${LOGMONITORING_IMAGE_REPOSITORY:-public.ecr.aws/dynatrace/dynatrace-logmodule}"
export LOGMONITORING_IMAGE_TAG="${LOGMONITORING_IMAGE_TAG:-1.339.51.20260603-143443}"

DT_API_URL="${DT_TENANT_URL%/}"
DT_API_URL="${DT_API_URL/.apps./.}"
export DT_API_URL

kubectl apply -f deploy/k8s/namespaces.yaml
helm upgrade --install dynatrace-operator oci://public.ecr.aws/dynatrace/dynatrace-operator \
  --version 1.10.0-rc.0 \
  --namespace dynatrace \
  --create-namespace \
  --atomic

if ! command -v envsubst >/dev/null 2>&1; then
  echo "envsubst is required. Install gettext-base."
  exit 1
fi

envsubst < deploy/k8s/dynatrace/dynakube.yaml.tpl | kubectl apply -f -
