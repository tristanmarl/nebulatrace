#!/usr/bin/env bash
set -euo pipefail

kubectl -n nebulatrace set env deployment/cargo-api ENTROPY_MODE=stable
kubectl -n nebulatrace set env deployment/credits-api ENTROPY_MODE=stable
kubectl -n nebulatrace set env deployment/drone-worker ENTROPY_MODE=stable
kubectl -n nebulatrace set env deployment/mock-llm ENTROPY_MODE=stable
kubectl apply -f deploy/k8s/istio/istio.yaml
kubectl -n nebulatrace rollout restart deployment/cargo-api deployment/credits-api deployment/drone-worker deployment/mock-llm
