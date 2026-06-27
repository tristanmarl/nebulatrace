FROM python:3.12-slim
WORKDIR /app
COPY faas-trigger/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY otel_setup.py .
COPY faas-trigger/trigger.py .
CMD ["python", "trigger.py"]
