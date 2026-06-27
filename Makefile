-include .env
export

KUBECTL ?= kubectl
IMAGE_REGISTRY ?= nebulatrace
IMAGE_TAG ?= dev

SERVICES := bridge-ui command-api cargo-api mission-api credits-api drone-worker maintenance-api orbit-ai mock-llm load-generator faas-trigger rpc-target rpc-probe

.PHONY: build-images build test run-local stop-local push-images k3s-load-images k3s-deploy install-istio install-dynatrace deploy app-url status restart start stop reset entropy-slow-db entropy-queue-backlog entropy-credit-errors entropy-wormhole-route entropy-ai-anomaly

build-images:
	@for service in $(SERVICES); do docker build -t $(IMAGE_REGISTRY)/$$service:$(IMAGE_TAG) apps/$$service; done

build: build-images

test: build-images

run-local: build-images
	./scripts/run-local-docker.sh

stop-local:
	./scripts/stop-local-docker.sh

push-images:
	@test "$(IMAGE_REGISTRY)" != "nebulatrace" || (echo "Set IMAGE_REGISTRY to a registry your cluster can pull from before pushing."; exit 1)
	@for service in $(SERVICES); do docker push $(IMAGE_REGISTRY)/$$service:$(IMAGE_TAG); done

k3s-load-images: IMAGE_REGISTRY=nebulatrace
k3s-load-images: IMAGE_TAG=dev
k3s-load-images: build-images
	./scripts/k3s-load-images.sh

k3s-deploy: IMAGE_REGISTRY=nebulatrace
k3s-deploy: IMAGE_TAG=dev
k3s-deploy: k3s-load-images install-istio deploy

install-istio:
	./scripts/install-istio.sh

install-dynatrace:
	./scripts/install-dynatrace-operator.sh

deploy:
	./scripts/deploy-demo.sh

app-url:
	$(KUBECTL) -n istio-system get svc istio-ingressgateway

status:
	./scripts/status.sh

restart:
	./scripts/restart-workloads.sh

start:
	./scripts/scale-demo.sh start

stop:
	./scripts/scale-demo.sh stop

reset:
	./scripts/reset-demo.sh

entropy-slow-db:
	./scripts/entropy-slow-db.sh

entropy-queue-backlog:
	./scripts/entropy-queue-backlog.sh

entropy-credit-errors:
	./scripts/entropy-credit-errors.sh

entropy-wormhole-route:
	./scripts/entropy-wormhole-route.sh

entropy-ai-anomaly:
	./scripts/entropy-ai-anomaly.sh
