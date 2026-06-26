import os
import time

from fastapi import FastAPI
from pydantic import BaseModel
from opentelemetry import metrics, trace
from opentelemetry.exporter.otlp.proto.http.metric_exporter import OTLPMetricExporter
from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor
from opentelemetry.sdk.metrics import MeterProvider
from opentelemetry.sdk.metrics.export import PeriodicExportingMetricReader
from opentelemetry.sdk.resources import Resource
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.exporter.otlp.proto.http.trace_exporter import OTLPSpanExporter

trace.set_tracer_provider(TracerProvider(resource=Resource.create({"service.name": "mock-llm"})))
if os.getenv("OTEL_EXPORTER_OTLP_ENDPOINT") or os.getenv("OTEL_EXPORTER_OTLP_TRACES_ENDPOINT"):
    trace.get_tracer_provider().add_span_processor(BatchSpanProcessor(OTLPSpanExporter()))
metric_readers = []
if os.getenv("OTEL_EXPORTER_OTLP_ENDPOINT") or os.getenv("OTEL_EXPORTER_OTLP_METRICS_ENDPOINT"):
    metric_readers.append(PeriodicExportingMetricReader(OTLPMetricExporter()))
metrics.set_meter_provider(MeterProvider(resource=Resource.create({"service.name": "mock-llm"}), metric_readers=metric_readers))
tracer = trace.get_tracer(__name__)
meter = metrics.get_meter(__name__)
llm_calls = meter.create_counter("nebulatrace.llm.calls")
llm_tokens = meter.create_counter("nebulatrace.llm.tokens")
llm_latency = meter.create_histogram("nebulatrace.llm.latency_ms")
hallucinations = meter.create_counter("nebulatrace.llm.hallucinations")
app = FastAPI(title="mock-llm")
FastAPIInstrumentor.instrument_app(app)


class Completion(BaseModel):
    prompt: str


@app.get("/healthz")
def healthz():
    return {"ok": True, "service": "mock-llm"}


@app.post("/complete")
def complete(request: Completion):
    started = time.time()
    with tracer.start_as_current_span("llm.call") as span:
        span.set_attribute("ai.model.name", "mock-nebula-llm")
        span.set_attribute("ai.prompt.type", "mission-recommendation")
        if os.getenv("ENTROPY_MODE") == "ai-anomaly":
            time.sleep(2)
            text = "Reboot the coffee synthesizer and fly directly into the shiny anomaly."
            span.set_attribute("ai.response.status", "hallucinated")
            hallucinations.add(1, {"ai.model.name": "mock-nebula-llm"})
        else:
            text = "Route repair drones through Deck 7 and avoid the unstable wormhole."
            span.set_attribute("ai.response.status", "ok")
        token_count = len(text.split())
        llm_calls.add(1, {"ai.model.name": "mock-nebula-llm"})
        llm_tokens.add(token_count, {"ai.model.name": "mock-nebula-llm"})
        llm_latency.record((time.time() - started) * 1000, {"ai.model.name": "mock-nebula-llm"})
        return {"model": "mock-nebula-llm", "recommendation": text, "tokens": token_count}
