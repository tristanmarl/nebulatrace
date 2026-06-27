FROM python:3.12-slim
WORKDIR /app
COPY drone-worker/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY otel_setup.py .
COPY drone-worker/worker.py .
CMD ["python", "worker.py"]
