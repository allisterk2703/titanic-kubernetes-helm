# tests/test_packaging.py
"""
Guard-rails for wheel packaging: importing the package must be side-effect free.

These tests run the imports in a subprocess with a temporary working directory,
so a stray mkdir() at import time shows up as a created directory.
"""

import subprocess
import sys

MODULES = [
    "titanic",
    "titanic.cli",
    "titanic.paths",
    "titanic.logger",
    "titanic.train",
    "titanic.predict",
    "titanic.api.main",
]


def _import_in_subprocess(tmp_path, modules):
    code = "import importlib\n" + "\n".join(f"importlib.import_module({m!r})" for m in modules)
    result = subprocess.run(
        [sys.executable, "-c", code],
        cwd=tmp_path,
        capture_output=True,
        text=True,
    )
    assert result.returncode == 0, result.stderr
    return result


def test_import_does_not_touch_filesystem(tmp_path):
    _import_in_subprocess(tmp_path, MODULES)
    assert list(tmp_path.iterdir()) == [], f"import created files: {list(tmp_path.iterdir())}"


def test_paths_default_to_cwd(tmp_path, monkeypatch):
    from titanic import paths

    for var in ("TITANIC_BASE_DIR", "TRAINING_DATA_DIR", "MODEL_DIR", "OUTPUT_DIR"):
        monkeypatch.delenv(var, raising=False)
    monkeypatch.chdir(tmp_path)

    assert paths.get_input_dir() == tmp_path / "input" / "data" / "training"
    assert paths.get_model_dir() == tmp_path / "output" / "model"
    assert paths.get_output_dir() == tmp_path / "output"
    assert list(tmp_path.iterdir()) == []


def test_env_vars_override_paths(tmp_path, monkeypatch):
    from titanic import paths

    monkeypatch.setenv("MODEL_DIR", str(tmp_path))
    assert paths.get_model_dir() == tmp_path


def test_console_script_entry_points_resolve():
    from importlib.metadata import entry_points

    scripts = {ep.name: ep for ep in entry_points(group="console_scripts")}
    for name in ("titanic-train", "titanic-serve"):
        assert name in scripts, f"missing console script: {name}"
        scripts[name].load()
