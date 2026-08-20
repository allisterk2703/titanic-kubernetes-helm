.PHONY: argocd-start argocd-deploy argocd-ui argocd-status argocd-delete argocd-stop

# ==========================================================================
#  ArgoCD (GitOps)
#
#  ArgoCD watches the main branch of this repo and applies the Helm chart.
#  It synchronises manifests, not images: build the image first.
# ==========================================================================

argocd-start:  ## Start ArgoCD again
	$(KUBECTL_CLUSTER) -n $(ARGOCD_NAMESPACE) scale statefulset argocd-application-controller --replicas=1
	$(KUBECTL_CLUSTER) -n $(ARGOCD_NAMESPACE) scale deployment --all --replicas=1
	$(KUBECTL_CLUSTER) -n $(ARGOCD_NAMESPACE) rollout status deployment/argocd-server
	echo "▶️  ArgoCD started"

argocd-deploy:  ## Create or update the ArgoCD Application
	$(KUBECTL_CLUSTER) apply -f argocd/application.yaml
	echo "✅ ArgoCD Application '$(ARGOCD_APP)' applied"

argocd-ui:  ## Print the ArgoCD UI URL and admin password (LoadBalancer Service)
	echo "🔗 http://$$($(KUBECTL_CLUSTER) -n $(ARGOCD_NAMESPACE) get svc argocd-server -o jsonpath='{.status.loadBalancer.ingress[0].ip}') (user: admin, password: $$($(KUBECTL_CLUSTER) -n $(ARGOCD_NAMESPACE) get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d))"

argocd-status:  ## Sync status of the Application
	$(KUBECTL_CLUSTER) -n $(ARGOCD_NAMESPACE) get application $(ARGOCD_APP) \
		-o custom-columns=NAME:.metadata.name,SYNC:.status.sync.status,HEALTH:.status.health.status,REVISION:.status.sync.revision

argocd-delete:  ## Delete the ArgoCD Application and the resources it deployed
	$(KUBECTL_CLUSTER) delete -f argocd/application.yaml --ignore-not-found
	echo "✅ ArgoCD Application deleted"

argocd-stop:  ## Stop ArgoCD (scale to 0) to deploy by hand without interference
	$(KUBECTL_CLUSTER) -n $(ARGOCD_NAMESPACE) scale statefulset argocd-application-controller --replicas=0
	$(KUBECTL_CLUSTER) -n $(ARGOCD_NAMESPACE) scale deployment --all --replicas=0
	echo "⏸️  ArgoCD stopped (make argocd-start to bring it back)"
