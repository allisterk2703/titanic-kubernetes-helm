.PHONY: cluster-status clean-k8s clean-helm clean-argocd clean-cluster

# ==========================================================================
#  Cluster reset
#
#  Start from a clean slate before redeploying, whichever method was used
#  previously. clean-cluster removes the ArgoCD Application first, otherwise
#  selfHeal would recreate what the other targets delete.
# ==========================================================================

cluster-status:  ## What is currently deployed, whichever method was used
	echo "--- Namespace ---"
	$(KUBECTL_CLUSTER) get namespace $(K8S_NAMESPACE) --ignore-not-found || true
	echo "--- Resources ---"
	if $(KUBECTL_CLUSTER) get namespace $(K8S_NAMESPACE) > /dev/null 2>&1; then \
		$(KUBECTL) get all; \
	else \
		echo "namespace is gone"; \
	fi
	echo "--- Helm release ---"
	helm list --kube-context $(K8S_CONTEXT) --all-namespaces --filter '^$(HELM_RELEASE)$$'
	echo "--- ArgoCD Application ---"
	$(KUBECTL_CLUSTER) -n $(ARGOCD_NAMESPACE) get applications 2>/dev/null || echo "none"
	echo "--- ArgoCD pods ---"
	$(KUBECTL_CLUSTER) -n $(ARGOCD_NAMESPACE) get pods --no-headers 2>/dev/null | wc -l | xargs echo "running pods:"

clean-k8s:  ## Delete the namespace and everything inside it (pods, jobs, services...)
	$(KUBECTL_CLUSTER) delete namespace $(K8S_NAMESPACE) --ignore-not-found --timeout=120s
	echo "✅ Namespace $(K8S_NAMESPACE) is gone"

clean-helm:  ## Uninstall the Helm release
	helm uninstall $(HELM_RELEASE) --kube-context $(K8S_CONTEXT) --ignore-not-found > /dev/null 2>&1 || true
	echo "✅ No Helm release '$(HELM_RELEASE)' left"

clean-argocd:  ## Delete the ArgoCD Application (handles ArgoCD being stopped)
	if $(KUBECTL_CLUSTER) -n $(ARGOCD_NAMESPACE) get application $(ARGOCD_APP) > /dev/null 2>&1; then \
		$(KUBECTL_CLUSTER) -n $(ARGOCD_NAMESPACE) delete application $(ARGOCD_APP) --timeout=45s \
		|| ( echo "⚠️  Deletion stuck (ArgoCD controller stopped?) - removing the finalizer" \
			&& $(KUBECTL_CLUSTER) -n $(ARGOCD_NAMESPACE) patch application $(ARGOCD_APP) \
				--type=merge -p '{"metadata":{"finalizers":null}}' > /dev/null \
			&& echo "ℹ️  Deployed resources are not pruned by ArgoCD: 'make clean-k8s' takes care of them" ); \
	fi
	echo "✅ No ArgoCD Application left"

clean-cluster: clean-argocd clean-helm clean-k8s  ## Clean slate: Kubernetes, Helm and ArgoCD
	echo "🧹 Cluster cleaned - ready for a new deployment"
