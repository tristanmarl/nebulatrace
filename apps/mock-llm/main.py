import os
import time

from fastapi import FastAPI
from pydantic import BaseModel
from opentelemetry import trace
from opentelemetry.sdk.resources import Resource
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.exporter.otlp.proto.http.trace_exporter import OTLPSpanExporter

trace.set_tracer_provider(TracerProvider(resource=Resource.create({"service.name": "mock-llm"})))
trace.get_tracer_provider().add_span_processor(BatchSpanProcessor(OTLPSpanExporter()))
tracer = trace.get_tracer(__name__)
app = FastAPI(title="mock-llm")


class Completion(BaseModel):
    prompt: str


@app.get("/healthz")
def healthz():
    return {"ok": True, "service": "mock-llm"}


@app.post("/complete")
def complete(request: Completion):
    with tracer.start_as_current_span("llm.call") as span:
        span.set_attribute("ai.model.name", "mock-nebula-llm")
        span.set_attribute("ai.prompt.type", "mission-recommendation")
        if os.getenv("ENTROPY_MODE") == "ai-anomaly":
            time.sleep(2)
            text = "Reboot the coffee synthesizer and fly directly into the shiny anomaly."
            span.set_attribute("ai.response.status", "hallucinated")
        else:
            text = "Route repair drones through Deck 7 and avoid the unstable wormhole."
            span.set_attribute("ai.response.status", "ok")
        return {"model": "mock-nebula-llm", "recommendation": text, "tokens": len(text.split())}
