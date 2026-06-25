#!/usr/bin/env bash
set -euo pipefail

kubectl -n nebulatrace set env deployment/credits-api ENTROPY_MODE=credit-errors
kubectl -n nebulatrace rollout restart deployment/credits-api
echo "Credits core instability enabled: credits-api returns frequent 500s."
