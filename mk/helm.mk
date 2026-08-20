.PHONY: helm-lint helm-dry-run helm-run-training helm-deploy-inference helm-status helm-delete

# ==========================================================================
#  Helm
#
#  Same manifests, rendered from helm/titanic/ with values.yaml.
#    make helm-deploy-inference HELM_EXTRA="--set inference.replicaCount=2"
#    make helm-deploy-inference HELM_ENV=prod   (own namespace + own release)
# ==========================================================================

helm-lint:  ## Check the syntax of the Helm chart (default values + every environment)
	helm lint $(HELM_CHART_DIR)
	helm lint $(HELM_CHART_DIR) --values $(HELM_CHART_DIR)/values-preprod.yaml
	helm lint $(HELM_CHART_DIR) --values $(HELM_CHART_DIR)/values-prod.yaml

helm-dry-run:  ## Render the YAML manifests without applying them (debug)
	helm install $(HELM_RELEASE) $(HELM_CHART_DIR) \
		--kube-context $(K8S_CONTEXT) \
		--dry-run --debug \
		$(HELM_VALUES) \
		$(HELM_EXTRA)

helm-run-training: build-training  ## Build + run the training Job with Helm
	# Delete the previous job if any (Kubernetes Jobs cannot be updated)
	$(KUBECTL) delete job $(PROJECT_NAME)-training-job --ignore-not-found
	helm upgrade --install $(HELM_RELEASE) $(HELM_CHART_DIR) \
		--kube-context $(K8S_CONTEXT) \
		$(HELM_VALUES) \
		$(HELM_NAMES) \
		--set training.enabled=true \
		--set training.image=$(TRAINING_IMAGE_NAME) \
		--set training.hostPaths.trainingData=$(PWD)/input/data/training \
		--set training.hostPaths.modelOutput=$(PWD)/models \
		--set training.hostPaths.predictionsOutput=$(PWD)/predictions \
		$(HELM_EXTRA)
	echo "✅ Training Job started with Helm"

helm-deploy-inference: build-inference  ## Build + deploy the inference API with Helm (Deployment + Service + Namespace)
	helm upgrade --install $(HELM_RELEASE) $(HELM_CHART_DIR) \
		--kube-context $(K8S_CONTEXT) \
		$(HELM_VALUES) \
		$(HELM_NAMES) \
		--set inference.image=$(INFERENCE_IMAGE_NAME) \
		$(HELM_EXTRA)
	echo "✅ Helm release '$(HELM_RELEASE)' deployed"

helm-status:  ## Show the status of the Helm release
	helm status $(HELM_RELEASE) --kube-context $(K8S_CONTEXT)

helm-delete-release:  ## Delete the Helm release and all its resources
	helm uninstall $(HELM_RELEASE) --kube-context $(K8S_CONTEXT) --ignore-not-found
	echo "✅ Helm release '$(HELM_RELEASE)' deleted"
