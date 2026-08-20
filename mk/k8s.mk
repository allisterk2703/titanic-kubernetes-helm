.PHONY: k8s-create-context k8s-set-context k8s-delete-context k8s-create-namespace k8s-set-namespace k8s-delete-namespace k8s-run-training k8s-wait-training k8s-logs-training k8s-status-training k8s-delete-training k8s-deploy-inference k8s-url-inference k8s-status-inference k8s-logs-inference k8s-delete-inference pipeline-k8s-training pipeline-k8s-inference

# ==========================================================================
#  Kubernetes with kubectl only
#
#  The k8s/ manifests use envsubst for variable injection, and the images
#  are read from the local Docker daemon (imagePullPolicy: Never).
#  $(KUBECTL) is namespace-scoped, $(KUBECTL_CLUSTER) is not (see Makefile).
# ==========================================================================

# --- Context -----------------------------------------------------------------

k8s-create-context:  ## Create or update the kubectl context (cluster/user/namespace)
	kubectl config set-context $(K8S_CONTEXT) --cluster=$(K8S_CLUSTER) --user=$(K8S_USER) --namespace=$(K8S_NAMESPACE)

k8s-set-context:  ## Switch kubectl to the context (must already exist, see k8s-create-context)
	$(KUBECTL_CLUSTER) config use-context $(K8S_CONTEXT)

k8s-delete-context:  ## Delete the kubectl context (does not remove the underlying cluster/user entries)
	kubectl config delete-context $(K8S_CONTEXT)


# --- Namespace -----------------------------------------------------------------

k8s-create-namespace:  ## Create the Kubernetes namespace (idempotent)
	$(K8S_EXPORT) envsubst '$$K8S_NAMESPACE' < $(K8S_MANIFESTS_DIR)/namespace.yaml | $(KUBECTL_CLUSTER) apply -f -

k8s-set-namespace:  ## Set the default namespace for the current kubectl context, so 'kubectl get pods' works without -n
	$(KUBECTL_CLUSTER) config set-context --current --namespace=$(K8S_NAMESPACE)

k8s-delete-namespace:  ## Delete the namespace and all its resources
	$(KUBECTL_CLUSTER) delete namespace $(K8S_NAMESPACE) --ignore-not-found


# --- Training ---------------------------------------------------------------

k8s-run-training: k8s-create-namespace  ## Run the training Job on Kubernetes (always deletes the previous job first, whatever its state)
	$(K8S_EXPORT) envsubst '$$IMAGE_NAME $$ARCH $$PROJECT_NAME $$PROJECT_DIR $$K8S_NAMESPACE' < $(K8S_MANIFESTS_DIR)/training-job.yaml | $(KUBECTL) apply -f -

k8s-logs-training:  ## Stream logs from the training Job
	$(KUBECTL) logs job/$(PROJECT_NAME)-training-job --follow

k8s-delete-training:  ## Delete the training Job and its pods
	$(KUBECTL) delete job $(PROJECT_NAME)-training-job --ignore-not-found


# --- Inference ---------------------------------------------------------------

k8s-deploy-inference: k8s-create-namespace  ## Deploy the inference API (Deployment + LoadBalancer Service)
	$(K8S_EXPORT) envsubst '$$IMAGE_NAME $$ARCH $$PROJECT_NAME $$K8S_NAMESPACE' < $(K8S_MANIFESTS_DIR)/inference-deployment.yaml | $(KUBECTL) apply -f -
	$(K8S_EXPORT) envsubst '$$PROJECT_NAME $$K8S_NAMESPACE' < $(K8S_MANIFESTS_DIR)/inference-service.yaml | $(KUBECTL) apply -f -
	$(KUBECTL) rollout status deployment/$(PROJECT_NAME)-inference

k8s-get-url-inference:  ## Show the inference service Swagger UI URL (LoadBalancer)
	echo "http://$$($(KUBECTL) get svc $(PROJECT_NAME)-inference-svc -o jsonpath='{.status.loadBalancer.ingress[0].ip}:{.spec.ports[0].port}')/docs"

k8s-logs-inference:  ## Stream logs from the inference pod
	$(KUBECTL) logs deployment/$(PROJECT_NAME)-inference --follow

k8s-delete-inference:  ## Delete the inference Deployment and Service
	$(KUBECTL) delete deployment $(PROJECT_NAME)-inference --ignore-not-found
	$(KUBECTL) delete svc $(PROJECT_NAME)-inference-svc --ignore-not-found


# --- Pipelines ---------------------------------------------------------------

pipeline-k8s-training: build-training k8s-run-training  ## Build the image + run training Job on Kubernetes

pipeline-k8s-inference: build-inference k8s-deploy-inference  ## Build the image + deploy inference on Kubernetes
