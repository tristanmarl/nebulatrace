#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

./scripts/stop-local-docker.sh >/dev/null 2>&1 || true
docker network create nebulatrace >/dev/null

python3 - <<'PY' >/tmp/nebulatrace-init.sql
from pathlib import Path

text = Path("deploy/k8s/data/postgres-init.yaml").read_text()
start = text.index("    create table")
print("\n".join(line[4:] if line.startswith("    ") else line for line in text[start:].splitlines()))
PY

docker run -d --name nebulatrace-postgres --network nebulatrace \
  --network-alias postgres \
  -e POSTGRES_USER=nebulatrace \
  -e POSTGRES_PASSWORD=nebulatrace \
  -e POSTGRES_DB=nebulatrace \
  -v /tmp/nebulatrace-init.sql:/docker-entrypoint-initdb.d/001-schema.sql:ro \
  postgres:16-alpine >/dev/null

docker run -d --name nebulatrace-activemq --network nebulatrace \
  --network-alias activemq \
  apache/activemq-classic:6.1.7 >/dev/null

docker run -d --name nebulatrace-redis --network nebulatrace \
  --network-alias redis \
  redis:7-alpine >/dev/null

for _ in $(seq 1 40); do
  docker exec nebulatrace-postgres pg_isready -U nebulatrace >/dev/null 2>&1 && break
  sleep 1
done

for _ in $(seq 1 60); do
  docker exec nebulatrace-activemq bash -lc 'test -S /tmp/activemq/activemq.pid || pgrep -f activemq' >/dev/null 2>&1 && break
  sleep 1
done

otel_env=(-e OTEL_TRACES_EXPORTER=none -e OTEL_METRICS_EXPORTER=none -e OTEL_LOGS_EXPORTER=none)

docker run -d --name nebulatrace-maintenance-api --network nebulatrace \
  --network-alias maintenance-api \
  "${IMAGE_REGISTRY:-nebulatrace}/maintenance-api:${IMAGE_TAG:-dev}" >/dev/null

docker run -d --name nebulatrace-cargo-api --network nebulatrace \
  --network-alias cargo-api \
  -e SPRING_DATASOURCE_URL=jdbc:postgresql://postgres:5432/nebulatrace \
  -e SPRING_DATASOURCE_USERNAME=nebulatrace \
  -e SPRING_DATASOURCE_PASSWORD=nebulatrace \
  "${IMAGE_REGISTRY:-nebulatrace}/cargo-api:${IMAGE_TAG:-dev}" >/dev/null

docker run -d --name nebulatrace-credits-api --network nebulatrace \
  --network-alias credits-api \
  -e REDIS_URL=redis://redis:6379 \
  "${IMAGE_REGISTRY:-nebulatrace}/credits-api:${IMAGE_TAG:-dev}" >/dev/null

docker run -d --name nebulatrace-mock-llm --network nebulatrace \
  --network-alias mock-llm \
  "${otel_env[@]}" \
  "${IMAGE_REGISTRY:-nebulatrace}/mock-llm:${IMAGE_TAG:-dev}" >/dev/null

docker run -d --name nebulatrace-orbit-ai --network nebulatrace \
  --network-alias orbit-ai \
  "${otel_env[@]}" \
  -e LLM_URL=http://mock-llm:8080 \
  "${IMAGE_REGISTRY:-nebulatrace}/orbit-ai:${IMAGE_TAG:-dev}" >/dev/null

docker run -d --name nebulatrace-mission-api --network nebulatrace \
  --network-alias mission-api \
  "${otel_env[@]}" \
  -e DATABASE_URL=postgresql://nebulatrace:nebulatrace@postgres:5432/nebulatrace \
  -e ACTIVEMQ_HOST=activemq \
  -e ACTIVEMQ_STOMP_PORT=61613 \
  "${IMAGE_REGISTRY:-nebulatrace}/mission-api:${IMAGE_TAG:-dev}" >/dev/null

docker run -d --name nebulatrace-drone-worker --network nebulatrace \
  --network-alias drone-worker \
  "${otel_env[@]}" \
  -e DATABASE_URL=postgresql://nebulatrace:nebulatrace@postgres:5432/nebulatrace \
  -e ACTIVEMQ_HOST=activemq \
  -e ACTIVEMQ_STOMP_PORT=61613 \
  -e MAINTENANCE_URL=http://maintenance-api:8080 \
  "${IMAGE_REGISTRY:-nebulatrace}/drone-worker:${IMAGE_TAG:-dev}" >/dev/null

docker run -d --name nebulatrace-command-api --network nebulatrace \
  --network-alias command-api \
  -e CARGO_URL=http://cargo-api:8080 \
  -e MISSION_URL=http://mission-api:8080 \
  -e CREDITS_URL=http://credits-api:8080 \
  -e ORBIT_URL=http://orbit-ai:8080 \
  "${IMAGE_REGISTRY:-nebulatrace}/command-api:${IMAGE_TAG:-dev}" >/dev/null

docker run -d --name nebulatrace-load-generator --network nebulatrace \
  -e COMMAND_URL=http://command-api:8080 \
  -e LOADGEN_DELAY_MS="${LOADGEN_DELAY_MS:-750}" \
  -e LOADGEN_BURST="${LOADGEN_BURST:-1}" \
  "${IMAGE_REGISTRY:-nebulatrace}/load-generator:${IMAGE_TAG:-dev}" >/dev/null

docker run -d --name nebulatrace-bridge-ui --network nebulatrace \
  -p 18000:8080 \
  "${IMAGE_REGISTRY:-nebulatrace}/bridge-ui:${IMAGE_TAG:-dev}" >/dev/null

ready=false
for _ in $(seq 1 30); do
  if [ "$(curl -s -o /dev/null -w "%{http_code}" http://localhost:18000/api/status)" = "200" ]; then
    ready=true
    break
  fi
  sleep 1
done

if [ "$ready" != true ]; then
  echo "NebulaTrace did not become ready. Check logs with: docker logs nebulatrace-bridge-ui" >&2
  exit 1
fi

echo "NebulaTrace is running: http://localhost:18000"
