#!/usr/bin/env bash
set -euo pipefail

for container in \
  nebulatrace-bridge-ui \
  nebulatrace-command-api \
  nebulatrace-cargo-api \
  nebulatrace-mission-api \
  nebulatrace-credits-api \
  nebulatrace-maintenance-api \
  nebulatrace-orbit-ai \
  nebulatrace-mock-llm \
  nebulatrace-drone-worker \
  nebulatrace-postgres \
  nebulatrace-rabbitmq \
  nebulatrace-redis
do
  docker rm -f "$container" >/dev/null 2>&1 || true
done

docker network rm nebulatrace >/dev/null 2>&1 || true
