.PHONY: build-wheel check-wheel clean-dist

# ==========================================================================
#  Packaging
#
#  check-wheel installs the built wheel in a throwaway environment outside
#  the repository, which is the only way to catch import-time side effects.
# ==========================================================================

build-wheel: clean-dist  ## Build the wheel and the sdist into dist/
	echo "📦 Building the wheel..."
	uv build
	ls -1 dist/
	echo "✅ Wheel built in dist/"

check-wheel: build-wheel  ## Install the wheel in a throwaway venv outside the repo and smoke-test it
	rm -rf $(WHEEL_CHECK_DIR)
	mkdir -p $(WHEEL_CHECK_DIR)
	echo "🔍 Wheel contents (top level):"
	unzip -Z1 dist/*.whl | cut -d/ -f1 | sort -u
	uv venv --quiet $(WHEEL_CHECK_DIR)/venv
	VIRTUAL_ENV=$(WHEEL_CHECK_DIR)/venv uv pip install --quiet "$(PWD)/$$(ls dist/*.whl | head -1)"
	cd $(WHEEL_CHECK_DIR) && ./venv/bin/python -c "import titanic, titanic.api.main; print('✅ import OK:', titanic.__version__)"
	cd $(WHEEL_CHECK_DIR) && ./venv/bin/titanic-train --help > /dev/null && echo "✅ console script OK"
	test -z "$$(ls -A $(WHEEL_CHECK_DIR) | grep -v venv)" \
		&& echo "✅ no side effect on import" \
		|| (echo "❌ import created files: $$(ls -A $(WHEEL_CHECK_DIR) | grep -v venv)" && exit 1)
	rm -rf $(WHEEL_CHECK_DIR)

clean-dist:  ## Remove build artifacts
	rm -rf dist build src/*.egg-info
	echo "✅ Build artifacts removed"
