.PHONY: create-env activate-env install-pip install-dev install-requirements install-all isort black ruff install-pre-commit pre-commit test clean run-training run-api run-mlflow-ui test-inference-local

# ==========================================================================
#  Python environment
#
#  The project is a src-layout package: `uv sync` installs it with its
#  dependencies into .venv.
# ==========================================================================

create-env:  ## Create local virtual environment with uv and install dependencies
	uv sync
	echo "✅ Virtual environment created and dependencies installed (.venv)"

activate-env:  ## Print the command to activate the local venv (a subshell cannot activate it for you)
	test -d .venv || (echo "❌ .venv not found: run 'make create-env' first" && exit 1)
	echo "Copy-paste this into your shell:" >&2
	echo ">> source .venv/bin/activate"

install-pip:  ## Upgrade pip, setuptools and wheel via uv
	test -d .venv || (echo "❌ .venv not found: run 'make create-env' first" && exit 1)
	uv pip install --upgrade pip setuptools wheel
	echo "✅ pip, setuptools and wheel upgraded"

install-dev: install-pip  ## Install the package in editable mode with its dev extras
	test -d .venv || (echo "❌ .venv not found: run 'make create-env' first" && exit 1)
	uv pip install -e ".[dev]"
	echo "✅ Package installed in editable mode with dev extras"

install-requirements:  ## Install libraries from requirements.txt
	test -d .venv || (echo "❌ .venv not found: run 'make create-env' first" && exit 1)
	uv pip install -r requirements.txt
	echo "✅ Libraries from requirements.txt installed successfully"

install-all: install-pip install-dev install-requirements  ## Install all libraries
	echo "✅ All libraries installed successfully"


# ==========================================================================
#  Code quality
#
#  isort and black are what the pre-commit hooks enforce; ruff is the linter.
# ==========================================================================

isort:  ## Sort Python imports
	echo "👷 Sorting imports with isort..."
	isort $(SRC_DIR) $(TESTS_DIR)
	echo "✅ Imports sorted with isort"

black:  ## Format Python code with Black
	echo "🎨 Formatting code with Black..."
	black $(SRC_DIR) $(TESTS_DIR)
	echo "✅ Code formatted with Black"

ruff:  ## Check and fix Python code with Ruff
	echo "👷 Checking and fixing code with Ruff..."
	ruff check $(SRC_DIR) $(TESTS_DIR) --fix
	ruff format $(SRC_DIR) $(TESTS_DIR)
	echo "✅ Code checked and fixed with Ruff"

install-pre-commit:  ## Install pre-commit, only if the project is a Git repository
	if [ -d ".git" ]; then \
		echo "📦 Installing pre-commit..."; \
		uv pip install pre-commit && pre-commit install && echo "✅ Pre-commit installed"; \
	else \
		echo "ℹ️  Not a Git repository, skipping pre-commit installation"; \
	fi

pre-commit: isort black # ruff  ## Run all pre-commit checks without Git
	echo "✅ Pre-commit executed"

test:  ## Run the test suite
	pytest -q $(TESTS_DIR)

clean:  ## Remove temporary files
	find . -type d \( -name ".venv" -prune \) -o -type d \( -name "__pycache__" -o -name ".pytest_cache" \) -exec rm -rf {} +
	find . -type f -name "*.pyc" -delete
	echo "✅ Temporary files removed"


# ==========================================================================
#  Local run (no container)
#
#  Requires the package to be installed: make create-env && make install-dev
# ==========================================================================

run-training:  ## Run the training locally
	echo "⏳ Training locally...\n"
	titanic-train

run-api:  ## Run the API locally
	echo "⏳ FastAPI should be running at http://localhost:8080...\n"
	uvicorn titanic.api.main:app --host localhost --port 8080

run-mlflow-ui:  ## Run the MLflow UI locally
	echo "⏳ MLflow UI should be running at http://localhost:5001...\n"
	mlflow ui --backend-store-uri "sqlite:///mlflow.db" --host 127.0.0.1 --port 5001

test-inference-local:  ## Test inference server running locally via uvicorn (make run-api)
	curl -sf http://127.0.0.1:8080/openapi.json > /dev/null \
		&& echo "✅ Local inference server is up (http://localhost:8080)" \
		|| (echo "❌ Local inference server is not responding: run 'make run-api' first" && exit 1)
