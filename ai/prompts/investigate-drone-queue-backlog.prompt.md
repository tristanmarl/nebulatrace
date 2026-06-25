# Investigate Drone Queue Backlog

Use Dynatrace to investigate delayed NebulaTrace missions.

Focus on:

- `mission-api` publish spans
- `drone-worker` consume spans
- RabbitMQ queue depth and consumer behavior
- failed or delayed `drone.fulfill` spans

Return the likely bottleneck and the fastest safe reset.
