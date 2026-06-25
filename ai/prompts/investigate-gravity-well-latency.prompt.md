# Investigate Gravity Well Latency

Use Dynatrace to investigate a NebulaTrace latency incident.

Focus on:

- service `cargo-api`
- PostgreSQL dependency spans
- slow SQL around `pg_sleep`
- impacted upstream service `command-api`
- related logs with the same trace IDs

Return the likely root cause, evidence, and one operator-safe remediation.
