#!/usr/bin/env bash
set -euo pipefail

kubectl -n nebulatrace set env deployment/cargo-api ENTROPY_MODE=slow-db
kubectl -n nebulatrace rollout restart deployment/cargo-api
echo "Gravity well enabled: cargo-api now runs a slow PostgreSQL call."
