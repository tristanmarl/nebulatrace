import json
import os
import time
from concurrent import futures

import grpc
import otel_setup
from opentelemetry import trace
from opentelemetry.instrumentation.grpc import GrpcInstrumentorServer

import hyperdrive_pb2
import hyperdrive_pb2_grpc

PORT = int(os.getenv("RPC_PORT", "50051"))

otel_setup.setup("rpc-target")
GrpcInstrumentorServer().instrument()


class Hyperdrive(hyperdrive_pb2_grpc.HyperdriveServicer):
    def Align(self, request, context):
        mode = request.mode or "ok"
        print(json.dumps({"event": "rpc-target.align", "mode": mode, "mission_id": request.mission_id}), flush=True)

        if mode == "not_found":
            context.abort(grpc.StatusCode.NOT_FOUND, "starlane not found")
        if mode == "invalid":
            context.abort(grpc.StatusCode.INVALID_ARGUMENT, "unstable coordinates")
        if mode == "internal":
            context.abort(grpc.StatusCode.INTERNAL, "hyperdrive plasma backflow")
        if mode == "deadline":
            time.sleep(2)

        return hyperdrive_pb2.AlignReply(
            mission_id=request.mission_id,
            status="aligned",
            message="Hyperdrive alignment nominal",
        )


def main():
    server = grpc.server(futures.ThreadPoolExecutor(max_workers=8))
    hyperdrive_pb2_grpc.add_HyperdriveServicer_to_server(Hyperdrive(), server)
    server.add_insecure_port(f"[::]:{PORT}")
    server.start()
    print(json.dumps({"event": "rpc-target.start", "port": PORT}), flush=True)
    server.wait_for_termination()


if __name__ == "__main__":
    main()
