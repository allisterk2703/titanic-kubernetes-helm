# Recipes live in mk/*.mk, one file per domain. This root file only holds
# the shared variables, help/print-env, and the includes.

.PHONY: help print-env

MAKEFLAGS += --silent

# --- Project ---------------------------------------------------------------
PROJECT_NAME := $(shell basename $(PWD))
SRC_DIR      := src/titanic
TESTS_DIR    := tests

# --- Local environment file (carries PIP_INDEX_URL) ------------------------
ENV_FILE ?= .env
-include $(ENV_FILE)

# --- Docker ----------------------------------------------------------------
# := and not ?=: the command line still wins, but .env cannot change the default
ARCH := arm64
ifeq ($(filter $(ARCH),arm64 amd64),)
$(error ARCH must be 'arm64' or 'amd64' (got '$(ARCH)'))
endif

DOCKERFILE_SUFFIX := $(if $(filter amd64,$(ARCH)),.amd64,)

# Single-quoted: the URL carries ? & and credentials the shell would interpret
PIP_INDEX_URL ?=
# Comma as a variable: unescaped, it would split the $(if ...) call below
comma := ,
# BuildKit secret, not --build-arg: an ARG's value stays readable in `docker history`
DOCKER_BUILD_ARGS = $(if $(DOCKERFILE_SUFFIX),\
	$(if $(PIP_INDEX_URL),--secret id=pip_index_url$(comma)env=PIP_INDEX_URL,),)

IMAGE_NAME           := $(PROJECT_NAME)-image
CONTAINER_NAME       := $(PROJECT_NAME)-container
TRAINING_IMAGE_NAME   = $(IMAGE_NAME)-training-$(ARCH)
INFERENCE_IMAGE_NAME  = $(IMAGE_NAME)-inference-$(ARCH)
TRAINING_CONTAINER    = $(CONTAINER_NAME)-training-$(ARCH)
INFERENCE_CONTAINER   = $(CONTAINER_NAME)-inference-$(ARCH)

# --- GHCR (ghcr.io) ---------------------------------------------------------
# docker login ghcr.io -u $(GHCR_NAMESPACE) first (PAT with write:packages)
GHCR_REGISTRY        := ghcr.io
GHCR_NAMESPACE       := allisterk2703
GHCR_TAG             := latest
GHCR_TRAINING_IMAGE   = $(GHCR_REGISTRY)/$(GHCR_NAMESPACE)/$(TRAINING_IMAGE_NAME)
GHCR_INFERENCE_IMAGE  = $(GHCR_REGISTRY)/$(GHCR_NAMESPACE)/$(INFERENCE_IMAGE_NAME)

# --- Packaging -------------------------------------------------------------
WHEEL_CHECK_DIR := .wheel-check

# --- Helm overlays ---------------------------------------------------------
# Not named ENV: some shells export ENV, which would pre-set it.
HELM_ENV ?=
ifneq ($(HELM_ENV),)
ifeq ($(filter $(HELM_ENV),preprod prod),)
$(error HELM_ENV must be 'preprod' or 'prod' (got '$(HELM_ENV)'))
endif
endif

# --- Kubernetes ------------------------------------------------------------
K8S_CONTEXT       := orbstack
# Cluster/user entries must pre-exist in the kubeconfig; create-context only
# assembles them under a context name, it does not create the cluster itself
K8S_CLUSTER       := orbstack
K8S_USER          := orbstack
# Must match the 'namespace' key of the matching values file
K8S_NAMESPACE     := $(PROJECT_NAME)$(if $(HELM_ENV),-$(HELM_ENV),)-namespace
K8S_MANIFESTS_DIR := k8s
K8S_EXPORT         = IMAGE_NAME=$(IMAGE_NAME) ARCH=$(ARCH) PROJECT_NAME=$(PROJECT_NAME) PROJECT_DIR=$(PWD) K8S_NAMESPACE=$(K8S_NAMESPACE) ARGO_NAMESPACE=$(ARGO_NAMESPACE)
# KUBECTL_CLUSTER is cluster-scoped (namespace/context management), KUBECTL adds -n
KUBECTL_CLUSTER = kubectl --context $(K8S_CONTEXT)
KUBECTL         = $(KUBECTL_CLUSTER) -n $(K8S_NAMESPACE)

# --- Helm ------------------------------------------------------------------
HELM_CHART_DIR := helm/titanic
# One release per environment, otherwise prod would take over preprod
HELM_RELEASE   := titanic$(if $(HELM_ENV),-$(HELM_ENV),)
# When HELM_ENV is set the overlay owns projectName/namespace (--set beats --values)
HELM_VALUES    := $(if $(HELM_ENV),--values $(HELM_CHART_DIR)/values-$(HELM_ENV).yaml,)
HELM_NAMES     := $(if $(HELM_ENV),,--set projectName=$(PROJECT_NAME) --set namespace=$(K8S_NAMESPACE))
HELM_EXTRA     :=

# --- ArgoCD ----------------------------------------------------------------
ARGOCD_NAMESPACE := argocd
ARGOCD_APP       := titanic

# --- Argo Workflows ----------------------------------------------------------
# Consumes the Argo Workflows instance deployed by the separate infra-k8s
# project (namespace must match its ARGO_WORKFLOWS_NAMESPACE, default below)
ARGO_NAMESPACE ?= argo-workflows


# ==========================================================================
#  Help and environment
# ==========================================================================

help:  ## Show the list of available commands
	echo "→ List of available commands:"
	grep -h -E '^[a-zA-Z0-9_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  🔹 %-35s %s\n", $$1, $$2}'

print-env:  ## Print environment variables
	echo "PROJECT_NAME=$(PROJECT_NAME)"
	echo "ENV_FILE=$(ENV_FILE) ($(if $(wildcard $(ENV_FILE)),found,not found: cp .env.tmp .env))"
	echo "ARCH=$(ARCH)"
	echo "DOCKERFILE=Dockerfile.<component>$(DOCKERFILE_SUFFIX)"
	echo "IMAGE_NAME=$(IMAGE_NAME)"
	echo "TRAINING_IMAGE_NAME=$(TRAINING_IMAGE_NAME)"
	echo "INFERENCE_IMAGE_NAME=$(INFERENCE_IMAGE_NAME)"
	echo "CONTAINER_NAME=$(CONTAINER_NAME)"
	echo "HELM_ENV=$(if $(HELM_ENV),$(HELM_ENV),<none: values.yaml only>)"
	echo "HELM_RELEASE=$(HELM_RELEASE)"
	echo "HELM_CHART_DIR=$(HELM_CHART_DIR)"
	echo "K8S_CONTEXT=$(K8S_CONTEXT)"
	echo "K8S_NAMESPACE=$(K8S_NAMESPACE)"
	echo "K8S_MANIFESTS_DIR=$(K8S_MANIFESTS_DIR)"
	echo "ARGOCD_NAMESPACE=$(ARGOCD_NAMESPACE)"
	echo "ARGOCD_APP=$(ARGOCD_APP)"
	echo "ARGO_NAMESPACE=$(ARGO_NAMESPACE)"


# ==========================================================================
#  Recipes
# ==========================================================================

include mk/python.mk
include mk/packaging.mk
include mk/docker.mk
include mk/k8s.mk
include mk/helm.mk
include mk/argocd.mk
include mk/argo.mk
include mk/cluster.mk
