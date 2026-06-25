#!/usr/bin/env bash
set -euo pipefail

kubectl -n nebulatrace set env deployment/drone-worker ENTROPY_MODE=queue-backlog
kubectl -n nebulatrace scale deployment/drone-worker --replicas=1
kubectl -n nebulatrace rollout restart deployment/drone-worker
echo "Drone bay congestion enabled: worker sleeps before acknowledging jobs."
