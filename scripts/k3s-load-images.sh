#!/usr/bin/env bash
set -euo pipefail

IMAGE_REGISTRY="${IMAGE_REGISTRY:-nebulatrace}"
IMAGE_TAG="${IMAGE_TAG:-dev}"
SERVICES="bridge-ui command-api cargo-api mission-api credits-api drone-worker maintenance-api orbit-ai mock-llm"

for service in $SERVICES; do
  image="${IMAGE_REGISTRY}/${service}:${IMAGE_TAG}"
  echo "Loading ${image} into k3s..."
  docker save "$image" | sudo k3s ctr -n k8s.io images import -
done
