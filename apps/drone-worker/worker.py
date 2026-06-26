import json
import os
import time

import psycopg
import requests
import stomp
from opentelemetry import metrics, propagate, trace
from opentelemetry.exporter.otlp.proto.http.metric_exporter import OTLPMetricExporter
from opentelemetry.instrumentation.requests import RequestsInstrumentor
from opentelemetry.sdk.metrics import MeterProvider
from opentelemetry.sdk.metrics.export import PeriodicExportingMetricReader
from opentelemetry.sdk.resources import Resource
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.exporter.otlp.proto.http.trace_exporter import OTLPSpanExporter
from opentelemetry.trace import SpanKind

trace.set_tracer_provider(TracerProvider(resource=Resource.create({"service.name": "drone-worker"})))
if os.getenv("OTEL_EXPORTER_OTLP_ENDPOINT") or os.getenv("OTEL_EXPORTER_OTLP_TRACES_ENDPOINT"):
    trace.get_tracer_provider().add_span_processor(BatchSpanProcessor(OTLPSpanExporter()))
metric_readers = []
if os.getenv("OTEL_EXPORTER_OTLP_ENDPOINT") or os.getenv("OTEL_EXPORTER_OTLP_METRICS_ENDPOINT"):
    metric_readers.append(PeriodicExportingMetricReader(OTLPMetricExporter()))
metrics.set_meter_provider(MeterProvider(resource=Resource.create({"service.name": "drone-worker"}), metric_readers=metric_readers))
RequestsInstrumentor().instrument()
tracer = trace.get_tracer(__name__)
meter = metrics.get_meter(__name__)
jobs_consumed = meter.create_counter("nebulatrace.drone.jobs.consumed")
jobs_failed = meter.create_counter("nebulatrace.drone.jobs.failed")
job_latency = meter.create_histogram("nebulatrace.drone.job.latency_ms")
maintenance_latency = meter.create_histogram("nebulatrace.drone.maintenance.latency_ms")

DATABASE_URL = os.getenv("DATABASE_URL", "postgresql://nebulatrace:nebulatrace@postgres.nebulatrace-data:5432/nebulatrace")
MAINTENANCE_URL = os.getenv("MAINTENANCE_URL", "http://maintenance-api:8080")
ACTIVEMQ_HOST = os.getenv("ACTIVEMQ_HOST", "activemq.nebulatrace-data")
ACTIVEMQ_STOMP_PORT = int(os.getenv("ACTIVEMQ_STOMP_PORT", "61613"))
ACTIVEMQ_USER = os.getenv("ACTIVEMQ_USER", "admin")
ACTIVEMQ_PASSWORD = os.getenv("ACTIVEMQ_PASSWORD", "admin")
DRONE_QUEUE = os.getenv("DRONE_QUEUE", "/queue/drone.jobs")


class DroneListener(stomp.ConnectionListener):
    def __init__(self, connection):
        self.connection = connection

    def on_message(self, frame):
        message = json.loads(frame.body)
        mission_id = message["mission_id"]
        context = propagate.extract(dict(frame.headers))
        started = time.time()
        with tracer.start_as_current_span("activemq consume drone.jobs", context=context, kind=SpanKind.CONSUMER) as span:
            span.set_attribute("messaging.system", "activemq")
            span.set_attribute("messaging.destination.name", "drone.jobs")
            span.set_attribute("messaging.operation", "consume")
            span.set_attribute("messaging.message.id", mission_id)
            span.set_attribute("mission.id", mission_id)
            if os.getenv("ENTROPY_MODE") == "queue-backlog":
                time.sleep(3)
            try:
                maintenance_started = time.time()
                requests.post(f"{MAINTENANCE_URL}/repairs", json={"mission_id": mission_id}, timeout=2)
                maintenance_latency.record((time.time() - maintenance_started) * 1000)
                with psycopg.connect(DATABASE_URL) as conn:
                    conn.execute("update missions set status = %s where id = %s", ("fulfilled", mission_id))
                    conn.execute(
                        "insert into drone_jobs(mission_id, status, created_at) values (%s, %s, now())",
                        (mission_id, "fulfilled"),
                    )
                self.connection.ack(id=frame.headers["ack"], subscription="drone-worker")
                jobs_consumed.add(1, {"messaging.destination.name": "drone.jobs"})
                job_latency.record((time.time() - started) * 1000)
            except Exception as exc:
                jobs_failed.add(1, {"messaging.destination.name": "drone.jobs"})
                span.record_exception(exc)
                self.connection.nack(id=frame.headers["ack"], subscription="drone-worker")


def main():
    connection = stomp.Connection12([(ACTIVEMQ_HOST, ACTIVEMQ_STOMP_PORT)])
    connection.set_listener("drone-worker", DroneListener(connection))
    for attempt in range(30):
        try:
            connection.connect(ACTIVEMQ_USER, ACTIVEMQ_PASSWORD, wait=True)
            break
        except Exception:
            if attempt == 29:
                raise
            time.sleep(2)
    connection.subscribe(destination=DRONE_QUEUE, id="drone-worker", ack="client-individual")
    while True:
        time.sleep(60)


if __name__ == "__main__":
    main()
