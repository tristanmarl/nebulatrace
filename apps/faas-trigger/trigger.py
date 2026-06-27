import json
import os
import random
import time
import urllib.error
import urllib.request
import uuid

import otel_setup
from opentelemetry import metrics, propagate, trace
from opentelemetry.trace import SpanKind, Status, StatusCode

COMMAND_URL = os.getenv("COMMAND_URL", "http://command-api:8080").rstrip("/")
DELAY_MS = int(os.getenv("FAAS_TRIGGER_DELAY_MS", "5000"))
TIMEOUT = float(os.getenv("FAAS_TRIGGER_TIMEOUT_SECONDS", "5"))
FUNCTION_NAME = os.getenv("FAAS_FUNCTION_NAME", "orion-signal-decoder")
TRIGGER_NAME = os.getenv("FAAS_TRIGGER_NAME", "nebula.distress.signal")

PROVIDERS = [
    {
        "span_name": "aws.lambda sqs trigger",
        "function": "aws-orion-signal-decoder",
        "provider": "aws",
        "region": "us-east-1",
        "trigger": "pubsub",
        "event_source": "arn:aws:sqs:us-east-1:424242424242:nebula-distress-signal",
        "destination": "aws.sqs.nebula-distress-signal",
    },
    {
        "span_name": "azure.functions queue trigger",
        "function": "azure-orion-signal-decoder",
        "provider": "azure",
        "region": "westeurope",
        "trigger": "pubsub",
        "event_source": "/subscriptions/mock/resourceGroups/nebulatrace/providers/Microsoft.Storage/storageAccounts/nebulatrace/queues/nebula-distress-signal",
        "destination": "azure.storage.queue.nebula-distress-signal",
    },
    {
        "span_name": "gcp.cloudfunctions pubsub trigger",
        "function": "gcp-orion-signal-decoder",
        "provider": "gcp",
        "region": "europe-west3",
        "trigger": "pubsub",
        "event_source": "//pubsub.googleapis.com/projects/nebulatrace/topics/nebula-distress-signal",
        "destination": "gcp.pubsub.nebula-distress-signal",
    },
]

otel_setup.setup("faas-trigger", extra={
    "service.namespace": "nebulatrace",
    "faas.name": FUNCTION_NAME,
    "faas.version": "v42",
})

tracer = trace.get_tracer(__name__)
meter = metrics.get_meter(__name__)
triggered = meter.create_counter("nebulatrace.faas.triggered")
trigger_failures = meter.create_counter("nebulatrace.faas.failures")
trigger_latency = meter.create_histogram("nebulatrace.faas.downstream.latency_ms")


def invoke_mission(headers):
    body = json.dumps(
        {
            "commander": "mock-faas",
            "destination": random.choice(["M42", "Kepler-186f", "Trappist relay"]),
            "priority": random.choice([2, 3, 5]),
        }
    ).encode()
    request = urllib.request.Request(
        f"{COMMAND_URL}/api/missions",
        data=body,
        method="POST",
        headers={"content-type": "application/json", **headers},
    )
    started = time.time()
    with urllib.request.urlopen(request, timeout=TIMEOUT) as response:
        response.read()
        return response.status, int((time.time() - started) * 1000)


def main():
    print(json.dumps({"event": "faas-trigger.start", "command_url": COMMAND_URL, "delay_ms": DELAY_MS}), flush=True)
    while True:
        provider = random.choice(PROVIDERS)
        invocation_id = f"faas-{uuid.uuid4().hex[:12]}"
        attributes = {
            "faas.trigger": provider["trigger"],
            "faas.name": provider["function"],
            "faas.execution": invocation_id,
            "faas.invoked_name": provider["function"],
            "faas.invoked_provider": provider["provider"],
            "faas.invoked_region": provider["region"],
            "cloud.provider": provider["provider"],
            "cloud.region": provider["region"],
            "cloud.resource_id": provider["event_source"],
            "messaging.system": f"{provider['provider']}.mock-faas",
            "messaging.destination.name": provider["destination"],
            "messaging.operation": "process",
            "messaging.message.id": invocation_id,
            "nebulatrace.mock_faas.provider": provider["provider"],
            "nebulatrace.mock_faas.event_source": provider["event_source"],
        }
        with tracer.start_as_current_span(provider["span_name"], kind=SpanKind.CONSUMER, attributes=attributes) as span:
            headers = {}
            propagate.inject(headers)
            try:
                status, latency_ms = invoke_mission(headers)
                span.set_attribute("http.response.status_code", status)
                span.set_attribute("nebulatrace.downstream.route", "/api/missions")
                trigger_latency.record(
                    latency_ms,
                    {"faas.trigger": provider["trigger"], "cloud.provider": provider["provider"], "http.status_code": str(status)},
                )
                triggered.add(1, {"faas.trigger": provider["trigger"], "cloud.provider": provider["provider"]})
                print(
                    json.dumps(
                        {
                            "event": "faas-trigger.invoke",
                            "provider": provider["provider"],
                            "function": provider["function"],
                            "invocation_id": invocation_id,
                            "status": status,
                            "latency_ms": latency_ms,
                        }
                    ),
                    flush=True,
                )
            except urllib.error.HTTPError as exc:
                trigger_failures.add(1, {"faas.trigger": provider["trigger"], "cloud.provider": provider["provider"], "failure.type": "http"})
                span.set_status(Status(StatusCode.ERROR, str(exc)))
                span.record_exception(exc)
                print(json.dumps({"event": "faas-trigger.http_error", "provider": provider["provider"], "status": exc.code}), flush=True)
            except Exception as exc:
                trigger_failures.add(1, {"faas.trigger": provider["trigger"], "cloud.provider": provider["provider"], "failure.type": "exception"})
                span.set_status(Status(StatusCode.ERROR, str(exc)))
                span.record_exception(exc)
                print(json.dumps({"event": "faas-trigger.error", "provider": provider["provider"], "error": str(exc)}), flush=True)
        time.sleep(max(DELAY_MS, 0) / 1000)


if __name__ == "__main__":
    main()
