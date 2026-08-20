# titanic/paths.py
import os
import platform
from pathlib import Path

from titanic.formatting import header
from titanic.logger import get_logger

logger = get_logger()


def get_base_dir() -> Path:
    """
    Root directory used to resolve default data/model/output locations.

    Defaults to the current working directory so that an installed wheel never
    writes inside site-packages. Override with TITANIC_BASE_DIR.
    """
    return Path(os.getenv("TITANIC_BASE_DIR", Path.cwd()))


def get_platform() -> str:
    return platform.machine()


def _resolve_dir(env_var: str, *relative_parts: str) -> Path:
    env_path = os.getenv(env_var)
    if env_path and Path(env_path).exists():
        return Path(env_path)
    return get_base_dir().joinpath(*relative_parts)


def get_input_dir() -> Path:
    return _resolve_dir("TRAINING_DATA_DIR", "input", "data", "training")


def get_model_dir() -> Path:
    return _resolve_dir("MODEL_DIR", "output", "model")


def get_output_dir() -> Path:
    return _resolve_dir("OUTPUT_DIR", "output")


def print_paths():
    logger.info(header("PATHS"))
    logger.info(f"PLATFORM   = {get_platform()}")
    logger.info(f"INPUT_DIR  = {get_input_dir()}")
    logger.info(f"MODEL_DIR  = {get_model_dir()}")
    logger.info(f"OUTPUT_DIR = {get_output_dir()}")
    logger.info(50 * "=" + "\n")


if __name__ == "__main__":
    print_paths()
