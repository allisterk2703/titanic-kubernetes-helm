.PHONY: check-index build-training build-inference run-training-docker run-inference-docker stop-training stop-inference test-inference-docker pipeline-local-training pipeline-local-inference clean-images clean-images-dangling push-training push-inference

# ==========================================================================
#  Docker
#
#  Images stay in the local Docker daemon: nothing is pushed to a registry.
#    make build-training              arm64, Dockerfile.training (default)
#    make build-inference ARCH=amd64  amd64, Dockerfile.inference.amd64
# ==========================================================================

check-index:  ## Check whether PIP_INDEX_URL is required and set for the current ARCH
	if [ -n "$(DOCKERFILE_SUFFIX)" ] && [ -z "$(PIP_INDEX_URL)" ]; then \
		echo "⚠️  ARCH=amd64 but PIP_INDEX_URL is empty: falling back to the public PyPI."; \
		echo "   Set it in $(ENV_FILE) (cp .env.tmp .env) to use the private index."; \
	else \
		echo "✅ Package index OK for ARCH=$(ARCH)$(if $(DOCKERFILE_SUFFIX), (PIP_INDEX_URL set), (public PyPI))"; \
	fi

build-training: check-index  ## Build the training Docker image (ARCH=arm64|amd64)
	PIP_INDEX_URL='$(PIP_INDEX_URL)' docker build --platform linux/$(ARCH) $(DOCKER_BUILD_ARGS) \
		-t $(TRAINING_IMAGE_NAME) -f Dockerfile.training$(DOCKERFILE_SUFFIX) .
	echo "✅ Training Docker image built for $(ARCH) from Dockerfile.training$(DOCKERFILE_SUFFIX): '$(TRAINING_IMAGE_NAME)'"

build-inference: check-index  ## Build the inference Docker image (ARCH=arm64|amd64)
	PIP_INDEX_URL='$(PIP_INDEX_URL)' docker build --platform linux/$(ARCH) $(DOCKER_BUILD_ARGS) \
		-t $(INFERENCE_IMAGE_NAME) -f Dockerfile.inference$(DOCKERFILE_SUFFIX) .
	echo "✅ Inference Docker image built for $(ARCH) from Dockerfile.inference$(DOCKERFILE_SUFFIX): '$(INFERENCE_IMAGE_NAME)'"

run-training-docker: build-training  ## Build and run the training Docker container locally
	docker run --platform linux/$(ARCH) --rm \
		-e TRAINING_DATA_DIR=/opt/ml/input/data/training \
		-e MODEL_DIR=/opt/ml/model \
		-e OUTPUT_DIR=/opt/ml/output \
		-v $(PWD)/input/data/training:/opt/ml/input/data/training \
		-v $(PWD)/models:/opt/ml/model \
		-v $(PWD)/predictions:/opt/ml/output \
		$(TRAINING_IMAGE_NAME) \
		titanic-train
	echo "✅ Training Docker container executed"

run-inference-docker: build-inference  ## Build and run the inference Docker container locally
	echo "⏳ Running inference Docker container..."
	echo "🔗 http://localhost:8080/docs#/"
	docker run --platform linux/$(ARCH) --rm -p 8080:8080 \
		--name $(INFERENCE_CONTAINER) $(INFERENCE_IMAGE_NAME)

stop-training:  ## Stop the training Docker container
	docker stop $(TRAINING_CONTAINER) || true
	echo "✅ Training Docker container stopped"

stop-inference:  ## Stop the inference Docker container
	docker stop $(INFERENCE_CONTAINER) || true
	echo "✅ Inference Docker container stopped"

test-inference-docker:  ## Test inference server running in Docker container
	docker ps --filter "name=$(INFERENCE_CONTAINER)" --filter "status=running" | grep -q "$(INFERENCE_CONTAINER)" \
		|| (echo "❌ Container '$(INFERENCE_CONTAINER)' is not running" && exit 1)
	curl -sf http://127.0.0.1:8080/openapi.json > /dev/null \
		&& echo "✅ Docker inference server is up (http://localhost:8080)" \
		|| (echo "❌ Docker inference server is not responding" && docker logs --tail 20 $(INFERENCE_CONTAINER) && exit 1)

pipeline-local-training: build-training run-training-docker  ## Build image + run training locally

pipeline-local-inference: build-inference run-inference-docker  ## Build image + run inference locally

push-training: build-training  ## Tag and push the training image to GHCR (docker login ghcr.io first)
	docker tag $(TRAINING_IMAGE_NAME) $(GHCR_TRAINING_IMAGE):$(GHCR_TAG)
	docker push $(GHCR_TRAINING_IMAGE):$(GHCR_TAG)
	echo "✅ Pushed $(GHCR_TRAINING_IMAGE):$(GHCR_TAG)"

push-inference: build-inference  ## Tag and push the inference image to GHCR (docker login ghcr.io first)
	docker tag $(INFERENCE_IMAGE_NAME) $(GHCR_INFERENCE_IMAGE):$(GHCR_TAG)
	docker push $(GHCR_INFERENCE_IMAGE):$(GHCR_TAG)
	echo "✅ Pushed $(GHCR_INFERENCE_IMAGE):$(GHCR_TAG)"

clean-images:  ## Remove the project Docker images, both architectures
	docker rmi -f $(IMAGE_NAME)-training-arm64 $(IMAGE_NAME)-inference-arm64 \
		$(IMAGE_NAME)-training-amd64 $(IMAGE_NAME)-inference-amd64 2>/dev/null || true
	echo "✅ Project Docker images removed"

clean-images-dangling:  ## Remove untagged image layers left behind by rebuilds
	docker image prune -f
	echo "✅ Dangling image layers removed"
