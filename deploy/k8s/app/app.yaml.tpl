apiVersion: v1
kind: ConfigMap
metadata:
  name: nebulatrace-config
  namespace: nebulatrace
data:
  DATABASE_URL: postgresql://nebulatrace:nebulatrace@postgres.nebulatrace-data:5432/nebulatrace
  ACTIVEMQ_HOST: activemq.nebulatrace-data
  ACTIVEMQ_STOMP_PORT: "61613"
  ACTIVEMQ_USER: admin
  ACTIVEMQ_PASSWORD: admin
  DRONE_QUEUE: /queue/drone.jobs
  REDIS_URL: redis://redis.nebulatrace-data:6379
  CARGO_URL: http://cargo-api:8080
  MISSION_URL: http://mission-api:8080
  CREDITS_URL: http://credits-api:8080
  ORBIT_URL: http://orbit-ai:8080
  LLM_URL: http://mock-llm:8080
  MAINTENANCE_URL: http://maintenance-api:8080
  COMMAND_URL: http://command-api:8080
  LOADGEN_DELAY_MS: "${LOADGEN_DELAY_MS}"
  LOADGEN_BURST: "${LOADGEN_BURST}"
  FAAS_TRIGGER_DELAY_MS: "${FAAS_TRIGGER_DELAY_MS}"
  FAAS_FUNCTION_NAME: orion-signal-decoder
  FAAS_TRIGGER_NAME: nebula.distress.signal
  RPC_TARGET: rpc-target:50051
  RPC_PROBE_DELAY_MS: "${RPC_PROBE_DELAY_MS}"
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
          env:
            - name: OTEL_RESOURCE_ATTRIBUTES
              value: "${OTEL_RESOURCE_ATTRIBUTES}"
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
          env:
            - name: OTEL_RESOURCE_ATTRIBUTES
              value: "${OTEL_RESOURCE_ATTRIBUTES}"
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
            - name: OTEL_RESOURCE_ATTRIBUTES
              value: "${OTEL_RESOURCE_ATTRIBUTES}"
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
            - name: OTEL_RESOURCE_ATTRIBUTES
              value: "${OTEL_RESOURCE_ATTRIBUTES}"
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
          env:
            - name: OTEL_RESOURCE_ATTRIBUTES
              value: "${OTEL_RESOURCE_ATTRIBUTES}"
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
          env:
            - name: OTEL_RESOURCE_ATTRIBUTES
              value: "${OTEL_RESOURCE_ATTRIBUTES}"
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
            - name: OTEL_RESOURCE_ATTRIBUTES
              value: "${OTEL_RESOURCE_ATTRIBUTES}"
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
          env:
            - name: OTEL_RESOURCE_ATTRIBUTES
              value: "${OTEL_RESOURCE_ATTRIBUTES}"
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
            - name: OTEL_RESOURCE_ATTRIBUTES
              value: "${OTEL_RESOURCE_ATTRIBUTES}"
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
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: load-generator
  namespace: nebulatrace
spec:
  replicas: 1
  selector:
    matchLabels:
      app: load-generator
  template:
    metadata:
      labels:
        app: load-generator
      annotations:
        oneagent.dynatrace.com/inject: "true"
        metadata.dynatrace.com/service: load-generator
    spec:
      containers:
        - name: load-generator
          image: ${IMAGE_REGISTRY}/load-generator:${IMAGE_TAG}
          env:
            - name: OTEL_RESOURCE_ATTRIBUTES
              value: "${OTEL_RESOURCE_ATTRIBUTES}"
          envFrom:
            - configMapRef:
                name: nebulatrace-config
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: faas-trigger
  namespace: nebulatrace
spec:
  replicas: 1
  selector:
    matchLabels:
      app: faas-trigger
  template:
    metadata:
      labels:
        app: faas-trigger
      annotations:
        otlp-exporter-configuration.dynatrace.com/inject: "true"
        metadata.dynatrace.com/service: faas-trigger
    spec:
      containers:
        - name: faas-trigger
          image: ${IMAGE_REGISTRY}/faas-trigger:${IMAGE_TAG}
          imagePullPolicy: IfNotPresent
          env:
            - name: OTEL_RESOURCE_ATTRIBUTES
              value: "${OTEL_RESOURCE_ATTRIBUTES}"
          envFrom:
            - configMapRef:
                name: nebulatrace-config
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: rpc-target
  namespace: nebulatrace
spec:
  replicas: 1
  selector:
    matchLabels:
      app: rpc-target
  template:
    metadata:
      labels:
        app: rpc-target
      annotations:
        otlp-exporter-configuration.dynatrace.com/inject: "true"
        metadata.dynatrace.com/service: rpc-target
    spec:
      containers:
        - name: rpc-target
          image: ${IMAGE_REGISTRY}/rpc-target:${IMAGE_TAG}
          imagePullPolicy: IfNotPresent
          ports:
            - containerPort: 50051
          env:
            - name: OTEL_RESOURCE_ATTRIBUTES
              value: "${OTEL_RESOURCE_ATTRIBUTES}"
---
apiVersion: v1
kind: Service
metadata:
  name: rpc-target
  namespace: nebulatrace
spec:
  selector:
    app: rpc-target
  ports:
    - name: grpc
      port: 50051
      targetPort: 50051
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: rpc-probe
  namespace: nebulatrace
spec:
  replicas: 1
  selector:
    matchLabels:
      app: rpc-probe
  template:
    metadata:
      labels:
        app: rpc-probe
      annotations:
        otlp-exporter-configuration.dynatrace.com/inject: "true"
        metadata.dynatrace.com/service: rpc-probe
    spec:
      containers:
        - name: rpc-probe
          image: ${IMAGE_REGISTRY}/rpc-probe:${IMAGE_TAG}
          imagePullPolicy: IfNotPresent
          env:
            - name: OTEL_RESOURCE_ATTRIBUTES
              value: "${OTEL_RESOURCE_ATTRIBUTES}"
          envFrom:
            - configMapRef:
                name: nebulatrace-config
