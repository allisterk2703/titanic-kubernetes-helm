# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

Everything goes through the Makefile (`make help` lists all targets). It is the source of truth: image names, namespaces and Helm release names are derived there, so prefer a target over a hand-written `docker`/`kubectl`/`helm` command.

```bash
make create-env install-dev   # uv sync, then editable install with dev extras
make test                     # pytest -q tests
make ruff                     # ruff check --fix + ruff format
make isort black              # what the pre-commit hooks enforce (src/ only)
make build-wheel check-wheel  # build, then install the wheel in a throwaway venv and smoke-test it
make print-env                # resolved ARCH, image names, namespace, Helm release
```

Single test: `uv run pytest tests/test_packaging.py::test_paths_default_to_cwd -q`.

`make test` calls `pytest` unqualified. Outside an activated `.venv` that resolves to the globally installed uv tool, where `titanic` is not importable, and every test fails on import rather than on a real defect. Run `source .venv/bin/activate` first, or use `uv run pytest -q tests`.

## Parameters that change what a target does

Two variables drive almost everything. Both are command-line only; passing them changes names, files and namespaces consistently.

`ARCH` (`arm64` default, or `amd64`) selects the platform, the Dockerfile, and the image/container name suffix:

| `ARCH` | Dockerfile | packages |
|---|---|---|
| `arm64` | `Dockerfile.training` / `Dockerfile.inference` | public PyPI |
| `amd64` | `Dockerfile.training.amd64` / `Dockerfile.inference.amd64` | private index from `PIP_INDEX_URL` |

The two `.amd64` files are copies whose only difference is `ARG PIP_INDEX_URL`, fed from `.env` (template: `.env.tmp`, the only value it carries). It is declared as `ARG` and never `ENV`, so the URL, which may embed credentials, is not baked into the final image. `ARCH` is assigned with `:=` on purpose: the command line still wins, but a stale `.env` cannot silently change what a bare `make build-training` produces.

`HELM_ENV` (empty, `preprod` or `prod`) selects a values overlay, and with it a namespace and a Helm release name. It is deliberately not called `ENV`: some shells export `ENV`, which would pre-set it and break every target.

```bash
make build-inference ARCH=amd64
make helm-deploy-inference HELM_ENV=prod
```

## Architecture

**Python package** (`src/titanic/`, src-layout, installed as a wheel). Two console scripts declared in `pyproject.toml`: `titanic-train` (`cli:main`) and `titanic-serve` (`api.main:serve`). The Docker images build the wheel in a first stage and install it in a second, so the container never runs from the source tree.

**Train/serve consistency runs through the model directory.** Anything learnt from the training data must be persisted next to the model and reloaded at inference, never recomputed from the data being predicted: `imputation.json` for the medians, `encoding.json` for the categorical encoding, `feature_names.json` for the column order. A single-row prediction cannot re-derive any of them, and getting it wrong is silent (the API still answers 200 with a wrong feature). `preprocess(df, mode=...)` is the seam: `mode="train"` learns and saves, `mode="predict"` loads and raises if the artifact is missing. Adding a learnt transformation means adding an artifact on both sides. Consequence: a change here invalidates the persisted model, so retrain and rebuild the inference image, which embeds `output/model/` at build time.

**Path resolution is the load-bearing abstraction** (`paths.py`). Nothing is hardcoded: `TITANIC_BASE_DIR` sets the root, and `TRAINING_DATA_DIR`, `MODEL_DIR`, `OUTPUT_DIR` override individual directories. This is what lets the same wheel run locally (defaults relative to cwd), in Docker (`/opt/ml` for training, `/app` for inference) and in Kubernetes (hostPath mounts) with no code change. `tests/test_packaging.py` enforces the invariant that makes this work: importing any module must not touch the filesystem, checked by importing in a subprocess in a temp cwd and asserting nothing was created. Keep `mkdir`/file writes out of module scope.

**Four deployment paths, same application**, in increasing order of indirection. They overlap, so know which one you are in:

1. `k8s/*.yaml` — raw manifests with `${VAR}` placeholders, rendered by `envsubst` from `K8S_EXPORT`. **envsubst uses an explicit allow-list in each target**: a variable added to a manifest must also be added to that list, or it silently stays literal in the output.
2. `helm/titanic/` — the same manifests as Helm templates. `values.yaml` is the base; `values-preprod.yaml` and `values-prod.yaml` are overlays applied on top via `HELM_ENV`.
3. `argocd/application.yaml` — GitOps, watches `main` and applies the chart. It renders values files only, so anything the Makefile injects with `--set` does not reach ArgoCD.
4. Local Docker (`run-*-docker`) and bare local runs (`run-training`, `run-api`).

**Helm values, non-obvious constraints.** `--set` beats `--values`, so when `HELM_ENV` is set the Makefile drops its `--set projectName/namespace` and lets the overlay own them; the namespace convention `$(PROJECT_NAME)-$(HELM_ENV)-namespace` is duplicated in `K8S_NAMESPACE` for the `kubectl delete job` line and must stay in sync. Each environment gets its own release name, otherwise deploying one would take over the other's release and prune its resources. The templates only read `projectName`, `namespace`, `training.*` and `inference.*`: any other key in a values file is silently ignored by Helm, so a typo lints clean. Verify with `helm template` and read the output, not with `helm lint` alone.

**No registry.** Images stay in the local Docker daemon and are consumed with `imagePullPolicy: Never` and `tag: latest`, on a single-node OrbStack cluster. Deployments therefore assume an arm64 node: the `-arm64` suffix hardcoded in the values files is the deploy architecture, independent of the build-time `ARCH`. ArgoCD syncs manifests, not images, so a Python change still requires rebuilding the image by hand.

**Training Job.** Disabled by default (`training.enabled: false`) because it mounts machine-specific hostPath directories; `make helm-run-training` enables it and injects the paths from `$(PWD)`. Kubernetes Jobs are immutable, so every target that runs it deletes the previous one first.

## Conventions

Line length 120 (black, isort with the black profile, ruff). Ruff's rule set is pinned explicitly in `pyproject.toml` so a new release cannot widen it; do not replace it with a broader selection without saying so. Pre-commit runs isort and black on `src/` only. The Makefile relies on `MAKEFLAGS += --silent`, so recipes echo their own status lines rather than the command.
