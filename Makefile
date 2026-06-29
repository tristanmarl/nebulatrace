-include .env
export

KUBECTL ?= kubectl
IMAGE_REGISTRY ?= nebulatrace
IMAGE_TAG ?= dev

SERVICES := bridge-ui command-api cargo-api credits-api maintenance-api load-generator
SHARED_CTX_SERVICES := drone-worker faas-trigger orbit-ai mission-api mock-llm rpc-probe rpc-target
ALL_SERVICES := $(SERVICES) $(SHARED_CTX_SERVICES)

.PHONY: build-images build test run-local stop-local push-images publish k3s-load-images k3s-deploy install-istio install-dynatrace deploy app-url status restart start stop set-owner reset

build-images:
	@for service in $(SERVICES); do docker build -t $(IMAGE_REGISTRY)/$$service:$(IMAGE_TAG) apps/$$service; done
	@for service in $(SHARED_CTX_SERVICES); do docker build -f apps/$$service/Dockerfile -t $(IMAGE_REGISTRY)/$$service:$(IMAGE_TAG) apps; done

build: build-images

test: build-images

run-local: build-images
	./scripts/run-local-docker.sh

stop-local:
	./scripts/stop-local-docker.sh

push-images:
	@test "$(IMAGE_REGISTRY)" != "nebulatrace" || (echo "Set IMAGE_REGISTRY to a registry your cluster can pull from before pushing."; exit 1)
	@for service in $(ALL_SERVICES); do docker push $(IMAGE_REGISTRY)/$$service:$(IMAGE_TAG); done

publish: IMAGE_REGISTRY=ghcr.io/tristanmarl/nebulatrace
publish: IMAGE_TAG=latest
publish: build-images push-images
	./scripts/render-install-yaml.sh --no-env

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

set-owner:
	@test -n "$(OWNER)" || (echo "Usage: make set-owner OWNER=service-monitoring"; exit 1)
	./scripts/set-owner.sh "$(OWNER)"

reset:
	./scripts/reset-demo.sh
