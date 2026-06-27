#!/usr/bin/env bash
set -euo pipefail

APP_NAMESPACE="${APP_NAMESPACE:-nebulatrace}"
DATA_NAMESPACE="${DATA_NAMESPACE:-nebulatrace-data}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [ "$#" -ne 1 ] || [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
  echo "Usage: scripts/set-owner.sh TEAM_IDENTIFIER"
  echo "Example: scripts/set-owner.sh service-monitoring"
  exit 1
fi

owner="$1"
custom_prop="dt.owner=${owner}"

if [ -f .env ]; then
  tmp="$(mktemp)"
  awk -v value="$custom_prop" '
    BEGIN { done = 0 }
    /^DT_CUSTOM_PROP=/ {
      if (!done) {
        print "DT_CUSTOM_PROP=" value
        done = 1
      }
      next
    }
    { print }
    END {
      if (!done) print "DT_CUSTOM_PROP=" value
    }
  ' .env > "$tmp"
  mv "$tmp" .env
fi

kubectl -n "$APP_NAMESPACE" set env deployment --all "DT_CUSTOM_PROP=$custom_prop"
kubectl -n "$DATA_NAMESPACE" set env deployment --all "DT_CUSTOM_PROP=$custom_prop"
kubectl -n "$DATA_NAMESPACE" set env statefulset --all "DT_CUSTOM_PROP=$custom_prop"

"$ROOT/scripts/restart-workloads.sh"
