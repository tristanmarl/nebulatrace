FROM python:3.12-slim
WORKDIR /app
COPY rpc-target/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY proto ./proto
RUN python -m grpc_tools.protoc -I proto --python_out=. --grpc_python_out=. proto/hyperdrive.proto
COPY otel_setup.py .
COPY rpc-target/server.py .
EXPOSE 50051
CMD ["python", "server.py"]
