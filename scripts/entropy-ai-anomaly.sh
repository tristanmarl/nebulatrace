#!/usr/bin/env bash
set -euo pipefail

kubectl -n nebulatrace set env deployment/mock-llm ENTROPY_MODE=ai-anomaly
kubectl -n nebulatrace rollout restart deployment/mock-llm
echo "ORBIT anomaly enabled: mock-llm returns slow, questionable advice."
