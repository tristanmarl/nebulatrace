# Summarize ORBIT AI Incident

Use Dynatrace to summarize an ORBIT AI anomaly.

Focus on:

- `orbit-ai`
- `mock-llm`
- spans named `orbit.recommend_mission` and `llm.call`
- AI token metrics
- `ai.response.status`

Return a concise incident summary, evidence, and whether the failure was model
latency, model output quality, or service availability.
