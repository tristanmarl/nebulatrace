# Demo Scenarios

## Gravity Well SQL

```bash
make entropy-slow-db
```

`cargo-api` runs `select 1 from pg_sleep(2)`. Show the slow DB span and the
response-time increase in Dynatrace.

## Drone Queue Backlog

```bash
make entropy-queue-backlog
```

`drone-worker` sleeps before acknowledgements. Create several missions from the
UI and watch RabbitMQ backlog and worker latency.

## Credits Core Failure

```bash
make entropy-credit-errors
```

`credits-api` returns frequent 500s. Show failed requests, logs, and traces.

## Wormhole Route

```bash
make entropy-wormhole-route
```

Istio aborts about half of `credits-api` calls with 503. Show mesh-level failures
and affected service traces.

## ORBIT AI Anomaly

```bash
make entropy-ai-anomaly
```

`mock-llm` sleeps and returns bad advice. Show AI spans, token metrics, and logs.

## Reset

```bash
make reset
```
