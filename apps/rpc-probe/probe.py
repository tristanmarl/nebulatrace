import json
import os
import random
import time
import uuid

import grpc
import otel_setup
from opentelemetry import trace
from opentelemetry.instrumentation.grpc import GrpcInstrumentorClient

import hyperdrive_pb2
import hyperdrive_pb2_grpc

TARGET = os.getenv("RPC_TARGET", "rpc-target:50051")
DELAY_MS = int(os.getenv("RPC_PROBE_DELAY_MS", "2500"))
MODES = ["ok", "ok", "not_found", "invalid", "internal", "deadline"]

otel_setup.setup("rpc-probe")
GrpcInstrumentorClient().instrument()


def call(stub, mode):
    mission_id = f"rpc-{uuid.uuid4().hex[:8]}"
    timeout = 0.4 if mode == "deadline" else 3
    started = time.time()
    try:
        response = stub.Align(hyperdrive_pb2.AlignRequest(mission_id=mission_id, mode=mode), timeout=timeout)
        status = "OK"
        message = response.message
    except grpc.RpcError as exc:
        status = exc.code().name
        message = exc.details()
    latency_ms = int((time.time() - started) * 1000)
    print(
        json.dumps(
            {
                "event": "rpc-probe.call",
                "mode": mode,
                "grpc_status": status,
                "mission_id": mission_id,
                "latency_ms": latency_ms,
                "message": message,
            }
        ),
        flush=True,
    )


def main():
    print(json.dumps({"event": "rpc-probe.start", "target": TARGET, "delay_ms": DELAY_MS}), flush=True)
    while True:
        try:
            with grpc.insecure_channel(TARGET) as channel:
                stub = hyperdrive_pb2_grpc.HyperdriveStub(channel)
                call(stub, random.choice(MODES))
        except Exception as exc:
            print(json.dumps({"event": "rpc-probe.error", "error": str(exc)}), flush=True)
        time.sleep(max(DELAY_MS, 0) / 1000)


if __name__ == "__main__":
    main()
