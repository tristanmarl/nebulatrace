import json
import os
import time

import pika
import psycopg
import requests
from opentelemetry import trace
from opentelemetry.sdk.resources import Resource
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.exporter.otlp.proto.http.trace_exporter import OTLPSpanExporter

trace.set_tracer_provider(TracerProvider(resource=Resource.create({"service.name": "drone-worker"})))
if os.getenv("OTEL_EXPORTER_OTLP_ENDPOINT") or os.getenv("OTEL_EXPORTER_OTLP_TRACES_ENDPOINT"):
    trace.get_tracer_provider().add_span_processor(BatchSpanProcessor(OTLPSpanExporter()))
tracer = trace.get_tracer(__name__)

DATABASE_URL = os.getenv("DATABASE_URL", "postgresql://nebulatrace:nebulatrace@postgres.nebulatrace-data:5432/nebulatrace")
RABBITMQ_URL = os.getenv("RABBITMQ_URL", "amqp://nebulatrace:nebulatrace@rabbitmq.nebulatrace-data:5672/")
MAINTENANCE_URL = os.getenv("MAINTENANCE_URL", "http://maintenance-api:8080")


def handle(channel, method, properties, body):
    message = json.loads(body)
    mission_id = message["mission_id"]
    with tracer.start_as_current_span("drone.fulfill") as span:
        span.set_attribute("mission.id", mission_id)
        if os.getenv("ENTROPY_MODE") == "queue-backlog":
            time.sleep(3)
        try:
            requests.post(f"{MAINTENANCE_URL}/repairs", json={"mission_id": mission_id}, timeout=2)
            with psycopg.connect(DATABASE_URL) as conn:
                conn.execute("update missions set status = %s where id = %s", ("fulfilled", mission_id))
                conn.execute(
                    "insert into drone_jobs(mission_id, status, created_at) values (%s, %s, now())",
                    (mission_id, "fulfilled"),
                )
            channel.basic_ack(delivery_tag=method.delivery_tag)
        except Exception as exc:
            span.record_exception(exc)
            channel.basic_nack(delivery_tag=method.delivery_tag, requeue=False)


def main():
    params = pika.URLParameters(RABBITMQ_URL)
    connection = None
    for _ in range(30):
        try:
            connection = pika.BlockingConnection(params)
            break
        except pika.exceptions.AMQPConnectionError:
            time.sleep(2)
    if connection is None:
        raise RuntimeError("RabbitMQ did not become reachable")
    channel = connection.channel()
    channel.exchange_declare(exchange="ship.missions", exchange_type="topic", durable=True)
    channel.queue_declare(queue="drone.jobs", durable=True)
    channel.queue_bind(queue="drone.jobs", exchange="ship.missions", routing_key="mission.created")
    channel.basic_qos(prefetch_count=1)
    channel.basic_consume(queue="drone.jobs", on_message_callback=handle)
    channel.start_consuming()


if __name__ == "__main__":
    main()
