apiVersion: v1
kind: ConfigMap
metadata:
  name: nebulatrace-config
  namespace: nebulatrace
data:
  DATABASE_URL: postgresql://nebulatrace:nebulatrace@postgres.nebulatrace-data:5432/nebulatrace
  RABBITMQ_URL: amqp://nebulatrace:nebulatrace@rabbitmq.nebulatrace-data:5672/
  REDIS_URL: redis://redis.nebulatrace-data:6379
  CARGO_URL: http://cargo-api:8080
  MISSION_URL: http://mission-api:8080
  CREDITS_URL: http://credits-api:8080
  ORBIT_URL: http://orbit-ai:8080
  LLM_URL: http://mock-llm:8080
  MAINTENANCE_URL: http://maintenance-api:8080
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: bridge-ui
  namespace: nebulatrace
spec:
  replicas: 1
  selector:
    matchLabels:
      app: bridge-ui
  template:
    metadata:
      labels:
        app: bridge-ui
      annotations:
        oneagent.dynatrace.com/inject: "true"
        metadata.dynatrace.com/service: bridge-ui
    spec:
      containers:
        - name: bridge-ui
          image: ${IMAGE_REGISTRY}/bridge-ui:${IMAGE_TAG}
          ports:
            - containerPort: 8080
---
apiVersion: v1
kind: Service
metadata:
  name: bridge-ui
  namespace: nebulatrace
spec:
  selector:
    app: bridge-ui
  ports:
    - name: http
      port: 8080
      targetPort: 8080
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: command-api
  namespace: nebulatrace
spec:
  replicas: 1
  selector:
    matchLabels:
      app: command-api
  template:
    metadata:
      labels:
        app: command-api
      annotations:
        oneagent.dynatrace.com/inject: "true"
        metadata.dynatrace.com/service: command-api
    spec:
      containers:
        - name: command-api
          image: ${IMAGE_REGISTRY}/command-api:${IMAGE_TAG}
          ports:
            - containerPort: 8080
          envFrom:
            - configMapRef:
                name: nebulatrace-config
---
apiVersion: v1
kind: Service
metadata:
  name: command-api
  namespace: nebulatrace
spec:
  selector:
    app: command-api
  ports:
    - name: http
      port: 8080
      targetPort: 8080
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cargo-api
  namespace: nebulatrace
spec:
  replicas: 1
  selector:
    matchLabels:
      app: cargo-api
  template:
    metadata:
      labels:
        app: cargo-api
      annotations:
        oneagent.dynatrace.com/inject: "true"
        metadata.dynatrace.com/service: cargo-api
    spec:
      containers:
        - name: cargo-api
          image: ${IMAGE_REGISTRY}/cargo-api:${IMAGE_TAG}
          ports:
            - containerPort: 8080
          env:
            - name: SPRING_DATASOURCE_URL
              value: jdbc:postgresql://postgres.nebulatrace-data:5432/nebulatrace
            - name: SPRING_DATASOURCE_USERNAME
              value: nebulatrace
            - name: SPRING_DATASOURCE_PASSWORD
              value: nebulatrace
            - name: ENTROPY_MODE
              value: stable
---
apiVersion: v1
kind: Service
metadata:
  name: cargo-api
  namespace: nebulatrace
spec:
  selector:
    app: cargo-api
  ports:
    - name: http
      port: 8080
      targetPort: 8080
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: credits-api
  namespace: nebulatrace
spec:
  replicas: 1
  selector:
    matchLabels:
      app: credits-api
      version: stable
  template:
    metadata:
      labels:
        app: credits-api
        version: stable
      annotations:
        oneagent.dynatrace.com/inject: "true"
        metadata.dynatrace.com/service: credits-api
    spec:
      containers:
        - name: credits-api
          image: ${IMAGE_REGISTRY}/credits-api:${IMAGE_TAG}
          ports:
            - containerPort: 8080
          env:
            - name: REDIS_URL
              valueFrom:
                configMapKeyRef:
                  name: nebulatrace-config
                  key: REDIS_URL
            - name: ENTROPY_MODE
              value: stable
---
apiVersion: v1
kind: Service
metadata:
  name: credits-api
  namespace: nebulatrace
spec:
  selector:
    app: credits-api
  ports:
    - name: http
      port: 8080
      targetPort: 8080
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: maintenance-api
  namespace: nebulatrace
spec:
  replicas: 1
  selector:
    matchLabels:
      app: maintenance-api
  template:
    metadata:
      labels:
        app: maintenance-api
      annotations:
        oneagent.dynatrace.com/inject: "true"
        metadata.dynatrace.com/service: maintenance-api
    spec:
      containers:
        - name: maintenance-api
          image: ${IMAGE_REGISTRY}/maintenance-api:${IMAGE_TAG}
          ports:
            - containerPort: 8080
---
apiVersion: v1
kind: Service
metadata:
  name: maintenance-api
  namespace: nebulatrace
spec:
  selector:
    app: maintenance-api
  ports:
    - name: http
      port: 8080
      targetPort: 8080
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mission-api
  namespace: nebulatrace
spec:
  replicas: 1
  selector:
    matchLabels:
      app: mission-api
  template:
    metadata:
      labels:
        app: mission-api
      annotations:
        otlp-exporter-configuration.dynatrace.com/inject: "true"
        metadata.dynatrace.com/service: mission-api
    spec:
      containers:
        - name: mission-api
          image: ${IMAGE_REGISTRY}/mission-api:${IMAGE_TAG}
          ports:
            - containerPort: 8080
          envFrom:
            - configMapRef:
                name: nebulatrace-config
---
apiVersion: v1
kind: Service
metadata:
  name: mission-api
  namespace: nebulatrace
spec:
  selector:
    app: mission-api
  ports:
    - name: http
      port: 8080
      targetPort: 8080
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: drone-worker
  namespace: nebulatrace
spec:
  replicas: 1
  selector:
    matchLabels:
      app: drone-worker
  template:
    metadata:
      labels:
        app: drone-worker
      annotations:
        otlp-exporter-configuration.dynatrace.com/inject: "true"
        metadata.dynatrace.com/service: drone-worker
    spec:
      containers:
        - name: drone-worker
          image: ${IMAGE_REGISTRY}/drone-worker:${IMAGE_TAG}
          env:
            - name: ENTROPY_MODE
              value: stable
          envFrom:
            - configMapRef:
                name: nebulatrace-config
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: orbit-ai
  namespace: nebulatrace
spec:
  replicas: 1
  selector:
    matchLabels:
      app: orbit-ai
  template:
    metadata:
      labels:
        app: orbit-ai
      annotations:
        otlp-exporter-configuration.dynatrace.com/inject: "true"
        metadata.dynatrace.com/service: orbit-ai
    spec:
      containers:
        - name: orbit-ai
          image: ${IMAGE_REGISTRY}/orbit-ai:${IMAGE_TAG}
          ports:
            - containerPort: 8080
          envFrom:
            - configMapRef:
                name: nebulatrace-config
---
apiVersion: v1
kind: Service
metadata:
  name: orbit-ai
  namespace: nebulatrace
spec:
  selector:
    app: orbit-ai
  ports:
    - name: http
      port: 8080
      targetPort: 8080
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mock-llm
  namespace: nebulatrace
spec:
  replicas: 1
  selector:
    matchLabels:
      app: mock-llm
  template:
    metadata:
      labels:
        app: mock-llm
      annotations:
        otlp-exporter-configuration.dynatrace.com/inject: "true"
        metadata.dynatrace.com/service: mock-llm
    spec:
      containers:
        - name: mock-llm
          image: ${IMAGE_REGISTRY}/mock-llm:${IMAGE_TAG}
          ports:
            - containerPort: 8080
          env:
            - name: ENTROPY_MODE
              value: stable
---
apiVersion: v1
kind: Service
metadata:
  name: mock-llm
  namespace: nebulatrace
spec:
  selector:
    app: mock-llm
  ports:
    - name: http
      port: 8080
      targetPort: 8080
