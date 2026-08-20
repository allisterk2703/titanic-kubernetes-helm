.PHONY: argo-run-training argo-logs-training argo-status-training argo-delete-training pipeline-argo-training

# ==========================================================================
#  Argo Workflows
#
#  Submits the training Job to an Argo Workflows instance already running
#  in the cluster (deployed separately, e.g. by the infra-k8s project).
#  Same image and hostPath volumes as k8s-run-training, just orchestrated
#  as a Workflow instead of a plain Job. Requires the 'argo' CLI.
# ==========================================================================

argo-run-training: build-training  ## Build + submit the training Job as an Argo Workflow
	$(K8S_EXPORT) envsubst '$$IMAGE_NAME $$ARCH $$PROJECT_NAME $$PROJECT_DIR $$ARGO_NAMESPACE' \
		< $(K8S_MANIFESTS_DIR)/training-workflow.yaml | \
		argo submit --context $(K8S_CONTEXT) -n $(ARGO_NAMESPACE) - --watch
	echo "✅ Training Workflow submitted to Argo Workflows"

argo-logs-training:  ## Stream logs from the latest titanic training Workflow
	argo logs --context $(K8S_CONTEXT) -n $(ARGO_NAMESPACE) @latest --follow

argo-status-training:  ## Show the status of the latest titanic training Workflow
	argo get --context $(K8S_CONTEXT) -n $(ARGO_NAMESPACE) @latest

argo-delete-training:  ## Delete the latest titanic training Workflow
	argo delete --context $(K8S_CONTEXT) -n $(ARGO_NAMESPACE) @latest

pipeline-argo-training: build-training argo-run-training  ## Build the image + submit training Workflow to Argo Workflows
