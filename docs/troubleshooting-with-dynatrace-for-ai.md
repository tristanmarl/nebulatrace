# Troubleshooting With dynatrace-for-ai

NebulaTrace includes prompts for the `dynatrace-for-ai` project so an operator
can ask an AI agent to inspect a Dynatrace incident.

Install the skills:

```bash
npx skills add dynatrace/dynatrace-for-ai
```

Use the prompts in `ai/prompts/` after triggering a scenario. The prompts are
written to point the agent at Dynatrace entities, traces, logs, metrics, and
service relationships instead of guessing from app symptoms alone.

Project:

- https://github.com/Dynatrace/dynatrace-for-ai
