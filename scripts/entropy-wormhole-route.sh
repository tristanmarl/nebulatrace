#!/usr/bin/env bash
set -euo pipefail

kubectl apply -f - <<'YAML'
apiVersion: networking.istio.io/v1
kind: VirtualService
metadata:
  name: credits-api
  namespace: nebulatrace
spec:
  hosts:
    - credits-api.nebulatrace.svc.cluster.local
  http:
    - fault:
        abort:
          percentage:
            value: 50
          httpStatus: 503
      route:
        - destination:
            host: credits-api.nebulatrace.svc.cluster.local
            subset: stable
            port:
              number: 8080
YAML
echo "Wormhole route enabled: Istio aborts roughly half of credits-api calls."
