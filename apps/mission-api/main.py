import json
import os
import time
import uuid

import pika
import psycopg
from fastapi import FastAPI
from opentelemetry import trace
from opentelemetry.sdk.resources import Resource
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.exporter.otlp.proto.http.trace_exporter import OTLPSpanExporter

trace.set_tracer_provider(TracerProvider(resource=Resource.create({"service.name": "mission-api"})))
if os.getenv("OTEL_EXPORTER_OTLP_ENDPOINT") or os.getenv("OTEL_EXPORTER_OTLP_TRACES_ENDPOINT"):
    trace.get_tracer_provider().add_span_processor(BatchSpanProcessor(OTLPSpanExporter()))
tracer = trace.get_tracer(__name__)
app = FastAPI(title="mission-api")

DATABASE_URL = os.getenv("DATABASE_URL", "postgresql://nebulatrace:nebulatrace@postgres.nebulatrace-data:5432/nebulatrace")
RABBITMQ_URL = os.getenv("RABBITMQ_URL", "amqp://nebulatrace:nebulatrace@rabbitmq.nebulatrace-data:5672/")


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
            with psycopg.connect(DATABASE_URL) as conn:
                conn.execute(
                    "insert into missions(id, title, status, created_at) values (%s, %s, %s, now())",
                    (mission_id, "Survey the Andromeda debugging corridor", "queued"),
                )
        except Exception as exc:
            span.record_exception(exc)
        try:
            params = pika.URLParameters(RABBITMQ_URL)
            connection = pika.BlockingConnection(params)
            channel = connection.channel()
            channel.exchange_declare(exchange="ship.missions", exchange_type="topic", durable=True)
            channel.queue_declare(queue="drone.jobs", durable=True)
            channel.queue_bind(queue="drone.jobs", exchange="ship.missions", routing_key="mission.created")
            channel.basic_publish(
                exchange="ship.missions",
                routing_key="mission.created",
                body=json.dumps({"mission_id": mission_id, "created": created}),
                properties=pika.BasicProperties(delivery_mode=2),
            )
            connection.close()
        except Exception as exc:
            span.record_exception(exc)
            return {"missionId": mission_id, "queued": False, "error": str(exc)}
    return {"missionId": mission_id, "queued": True}
