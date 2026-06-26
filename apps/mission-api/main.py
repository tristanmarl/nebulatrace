import json
import os
import time
import uuid

import psycopg
import stomp
from fastapi import FastAPI
from opentelemetry import metrics, propagate, trace
from opentelemetry.exporter.otlp.proto.http.metric_exporter import OTLPMetricExporter
from opentelemetry.trace import SpanKind
from opentelemetry.instrumentation.fastapi import FastAPIInstrumentor
from opentelemetry.sdk.metrics import MeterProvider
from opentelemetry.sdk.metrics.export import PeriodicExportingMetricReader
from opentelemetry.sdk.resources import Resource
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.exporter.otlp.proto.http.trace_exporter import OTLPSpanExporter

trace.set_tracer_provider(TracerProvider(resource=Resource.create({"service.name": "mission-api"})))
if os.getenv("OTEL_EXPORTER_OTLP_ENDPOINT") or os.getenv("OTEL_EXPORTER_OTLP_TRACES_ENDPOINT"):
    trace.get_tracer_provider().add_span_processor(BatchSpanProcessor(OTLPSpanExporter()))
metric_readers = []
if os.getenv("OTEL_EXPORTER_OTLP_ENDPOINT") or os.getenv("OTEL_EXPORTER_OTLP_METRICS_ENDPOINT"):
    metric_readers.append(PeriodicExportingMetricReader(OTLPMetricExporter()))
metrics.set_meter_provider(MeterProvider(resource=Resource.create({"service.name": "mission-api"}), metric_readers=metric_readers))
tracer = trace.get_tracer(__name__)
meter = metrics.get_meter(__name__)
missions_created = meter.create_counter("nebulatrace.missions.created")
mission_failures = meter.create_counter("nebulatrace.missions.failures")
db_latency = meter.create_histogram("nebulatrace.missions.db.latency_ms")
publish_latency = meter.create_histogram("nebulatrace.missions.activemq.publish.latency_ms")
published_messages = meter.create_counter("nebulatrace.missions.activemq.published")
app = FastAPI(title="mission-api")
FastAPIInstrumentor.instrument_app(app)

DATABASE_URL = os.getenv("DATABASE_URL", "postgresql://nebulatrace:nebulatrace@postgres.nebulatrace-data:5432/nebulatrace")
ACTIVEMQ_HOST = os.getenv("ACTIVEMQ_HOST", "activemq.nebulatrace-data")
ACTIVEMQ_STOMP_PORT = int(os.getenv("ACTIVEMQ_STOMP_PORT", "61613"))
ACTIVEMQ_USER = os.getenv("ACTIVEMQ_USER", "admin")
ACTIVEMQ_PASSWORD = os.getenv("ACTIVEMQ_PASSWORD", "admin")
DRONE_QUEUE = os.getenv("DRONE_QUEUE", "/queue/drone.jobs")


@app.get("/healthz")
def healthz():
    return {"ok": True, "service": "mission-api"}


@app.post("/missions")
def create_mission():
    mission_id = f"mission-{uuid.uuid4().hex[:8]}"
    with tracer.start_as_current_span("mission.create") as span:
        span.set_attribute("mission.id", mission_id)
        span.set_attribute("messaging.destination.name", "drone.jobs")
        created = time.time()
        try:
            started = time.time()
            with psycopg.connect(DATABASE_URL) as conn:
                conn.execute(
                    "insert into missions(id, title, status, created_at) values (%s, %s, %s, now())",
                    (mission_id, "Survey the Andromeda debugging corridor", "queued"),
                )
            db_latency.record((time.time() - started) * 1000, {"db.system": "postgresql"})
        except Exception as exc:
            mission_failures.add(1, {"failure.stage": "database"})
            span.record_exception(exc)
        with tracer.start_as_current_span("activemq publish drone.jobs", kind=SpanKind.PRODUCER) as publish_span:
            publish_span.set_attribute("messaging.system", "activemq")
            publish_span.set_attribute("messaging.destination.name", "drone.jobs")
            publish_span.set_attribute("messaging.operation", "publish")
            publish_span.set_attribute("messaging.message.id", mission_id)
            headers = {"persistent": "true", "mission_id": mission_id}
            propagate.inject(headers)
            try:
                started = time.time()
                connection = stomp.Connection12([(ACTIVEMQ_HOST, ACTIVEMQ_STOMP_PORT)])
                connection.connect(ACTIVEMQ_USER, ACTIVEMQ_PASSWORD, wait=True)
                connection.send(
                    destination=DRONE_QUEUE,
                    body=json.dumps({"mission_id": mission_id, "created": created}),
                    headers=headers,
                )
                connection.disconnect()
                publish_latency.record((time.time() - started) * 1000, {"messaging.system": "activemq"})
                published_messages.add(1, {"messaging.destination.name": "drone.jobs"})
            except Exception as exc:
                mission_failures.add(1, {"failure.stage": "activemq"})
                publish_span.record_exception(exc)
                span.record_exception(exc)
                return {"missionId": mission_id, "queued": False, "error": str(exc)}
    missions_created.add(1, {"mission.priority": "3"})
    return {"missionId": mission_id, "queued": True}
