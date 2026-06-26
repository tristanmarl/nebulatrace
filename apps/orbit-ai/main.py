import os
import time

import requests
from fastapi import FastAPI
from opentelemetry import metrics, trace
from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor
from opentelemetry.instrumentation.requests import RequestsInstrumentor
from opentelemetry.sdk.metrics import MeterProvider
from opentelemetry.sdk.metrics.export import PeriodicExportingMetricReader
from opentelemetry.exporter.otlp.proto.http.metric_exporter import OTLPMetricExporter
from opentelemetry.sdk.resources import Resource
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.exporter.otlp.proto.http.trace_exporter import OTLPSpanExporter

resource = Resource.create({"service.name": "orbit-ai"})
trace.set_tracer_provider(TracerProvider(resource=resource))
if os.getenv("OTEL_EXPORTER_OTLP_ENDPOINT") or os.getenv("OTEL_EXPORTER_OTLP_TRACES_ENDPOINT"):
    trace.get_tracer_provider().add_span_processor(BatchSpanProcessor(OTLPSpanExporter()))
metric_readers = []
if os.getenv("OTEL_EXPORTER_OTLP_ENDPOINT") or os.getenv("OTEL_EXPORTER_OTLP_METRICS_ENDPOINT"):
    metric_readers.append(PeriodicExportingMetricReader(OTLPMetricExporter()))
metrics.set_meter_provider(MeterProvider(resource=resource, metric_readers=metric_readers))
tracer = trace.get_tracer(__name__)
meter = metrics.get_meter(__name__)
tokens = meter.create_counter("nebulatrace.orbit.tokens")
failures = meter.create_counter("nebulatrace.orbit.failures")
recommendations = meter.create_counter("nebulatrace.orbit.recommendations")
llm_latency = meter.create_histogram("nebulatrace.orbit.llm.latency_ms")
app = FastAPI(title="orbit-ai")
FastAPIInstrumentor.instrument_app(app)
RequestsInstrumentor().instrument()

LLM_URL = os.getenv("LLM_URL", "http://mock-llm:8080")


@app.get("/healthz")
def healthz():
    return {"ok": True, "service": "orbit-ai"}


@app.get("/recommend")
def recommend():
    prompt = "Recommend the next safe mission for CSS Observable."
    with tracer.start_as_current_span("orbit.recommend_mission") as span:
        span.set_attribute("ai.model.name", "mock-nebula-llm")
        span.set_attribute("ai.prompt.type", "mission-recommendation")
        start = time.time()
        try:
            res = requests.post(f"{LLM_URL}/complete", json={"prompt": prompt}, timeout=3)
            data = res.json()
            output_tokens = int(data.get("tokens", 0))
            tokens.add(output_tokens, {"ai.model.name": "mock-nebula-llm"})
            recommendations.add(1, {"ai.model.name": "mock-nebula-llm", "ai.response.status": "ok"})
            llm_latency.record((time.time() - start) * 1000, {"ai.model.name": "mock-nebula-llm"})
            span.set_attribute("ai.tokens.input", len(prompt.split()))
            span.set_attribute("ai.tokens.output", output_tokens)
            span.set_attribute("ai.response.status", "ok")
            span.set_attribute("ai.latency_ms", int((time.time() - start) * 1000))
            return data
        except Exception as exc:
            failures.add(1)
            recommendations.add(1, {"ai.model.name": "mock-nebula-llm", "ai.response.status": "failed"})
            span.set_attribute("ai.response.status", "failed")
            span.record_exception(exc)
            return {"recommendation": "ORBIT is recalibrating the coffee synthesizer.", "error": str(exc)}
