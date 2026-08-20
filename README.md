<p align="center">
  <img src=".github/titanic-ship.png" alt="Titanic" width="400">
</p>

# titanic-kubernetes-helm-argo

Prediction of Titanic survival: training a classification model locally or on Kubernetes via OrbStack, experiment tracking with MLflow, and serving predictions through a FastAPI inference API.

## Features

- Load and preprocess Titanic data; train a classifier (sklearn pipeline).
- Run training locally or as a Kubernetes Job on OrbStack.
- Deploy inference as a Kubernetes Deployment with a LoadBalancer Service, or run the API locally with uvicorn.
- Track runs and artifacts with MLflow.

## Project structure

The project is a standard src-layout Python package (`titanic`), installable as a wheel.

- `src/titanic/` — data loading, preprocessing, training, evaluation, prediction.
- `src/titanic/api/` — FastAPI app for inference.
- `src/titanic/cli.py` — training entry point (`titanic-train`).
- `tests/` — packaging guard-rails (imports must stay side-effect free).
- `input/` — sample data and example JSON input.
- `output/` — trained model artifacts and metrics.
- `k8s/`, `helm/` — Kubernetes manifests and Helm chart.
- `Dockerfile.training`, `Dockerfile.inference` — multi-stage images that build then install the wheel.

## Packaging

```bash
make build-wheel   # build dist/*.whl and dist/*.tar.gz with uv
make check-wheel   # install the wheel in a throwaway venv and smoke-test it
make test          # run the test suite
```

The wheel exposes two console scripts:

- `titanic-train` — runs the full pipeline (load → preprocess → train → evaluate).
- `titanic-serve` — starts the inference API (`HOST` / `PORT` environment variables).

Paths are resolved from environment variables: `TITANIC_BASE_DIR` (root for defaults, defaults to the
current directory), `TRAINING_DATA_DIR`, `MODEL_DIR`, `OUTPUT_DIR`, plus `TITANIC_LOG_DIR` for file logging.
Nothing is written to disk at import time.

## Usage

### Local

```bash
make create-env         # uv sync
make install-dev        # editable install with dev extras
make run-training       # train locally (titanic-train)
make run-api            # start the FastAPI server at http://localhost:8080
make run-mlflow-ui      # start the MLflow UI at http://localhost:5001
```

### Docker

```bash
make run-training-docker    # build + run training container
make run-inference-docker   # build + run inference container at http://localhost:8080
```

Everything defaults to arm64: with no argument at all, nothing needs to be
configured anywhere. `ARCH` is passed on the command line only, and also
selects the Dockerfile:

| `ARCH` | Dockerfile | packages |
|---|---|---|
| `arm64` (default) | `Dockerfile.training` / `Dockerfile.inference` | public PyPI |
| `amd64` | `Dockerfile.training.amd64` / `Dockerfile.inference.amd64` | private index, `PIP_INDEX_URL` |

```bash
make build-inference ARCH=amd64   # amd64 image, built from the private index
make print-env                    # show the resolved values
```

The architecture is part of the image and container names, so both can coexist
locally. Only the amd64 builds need configuration: copy `.env.tmp` to `.env`
and set `PIP_INDEX_URL`, the single value that file carries, so the index URL
never appears in a tracked file. It is passed to `docker build` as a BuildKit
secret (`--secret`, not `--build-arg`), so it never shows up in `docker
history` either. Deployments assume an arm64 node (OrbStack).

### Kubernetes (OrbStack)

```bash
make pipeline-k8s-training   # build the image + run training Job
make k8s-logs-training       # stream training logs
make k8s-status-training     # check Job and pod status

make pipeline-k8s-inference  # build the image + deploy inference API
make k8s-url-inference       # get the LoadBalancer IP and port
```

### Helm environments

`values.yaml` holds the default local setup. Two overlays sit on top of it, each with its own
namespace and its own Helm release, selected with `HELM_ENV`:

```bash
make helm-deploy-inference                   # values.yaml only, release 'titanic'
make helm-deploy-inference HELM_ENV=preprod   # + values-preprod.yaml, 1 replica
make helm-deploy-inference HELM_ENV=prod      # + values-prod.yaml, 3 replicas
make helm-dry-run HELM_ENV=prod              # render without applying
```

`HELM_ENV` also drives `helm-status`, `helm-delete` and `helm-run-training`. ArgoCD stays on the default
`values.yaml`: a per-environment Application would be needed to deploy the overlays through GitOps.

### ArgoCD (GitOps)

An ArgoCD Application (`argocd/application.yaml`) watches the `main` branch of this repository and
keeps the cluster in sync with `helm/titanic`, with automated sync, self-heal and prune enabled.

```bash
make argocd-deploy      # create/update the Application
make argocd-status      # sync status, health and deployed revision
make argocd-ui          # UI URL and admin password
make argocd-delete      # remove the Application and its resources
```

Any commit pushed to `main` that changes `helm/titanic` is applied automatically (detection within
about 3 minutes with the default polling). Only manifests are synchronised: images are built locally
and used with `imagePullPolicy: Never`, so changing the Python code still requires rebuilding the image.

The training Job is disabled by default (`training.enabled: false`) because it mounts machine-specific
`hostPath` directories. It is enabled on demand by `make helm-run-training`.

Invoke the inference API:

```bash
curl -X POST http://<EXTERNAL-IP>:8080/predict \
  -H "Content-Type: application/json" \
  -d @input/example_input.json
```

## Author

Allister K.

## License

MIT License — see [LICENSE](LICENSE) for details.
