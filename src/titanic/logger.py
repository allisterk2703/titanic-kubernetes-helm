# titanic/logger.py
import logging
import os
import sys
from datetime import datetime
from pathlib import Path

LOGGER_NAME = "titanic"
FORMATTER = logging.Formatter("%(asctime)s - %(levelname)s - %(message)s")


def get_logger() -> logging.Logger:
    """
    Return the package logger, configured with a stdout handler only.

    Importing this module never touches the filesystem: file logging is opt-in
    via setup_file_logging() or the TITANIC_LOG_DIR environment variable.
    """
    logger = logging.getLogger(LOGGER_NAME)
    logger.setLevel(logging.INFO)
    logger.propagate = False

    if not any(isinstance(h, logging.StreamHandler) for h in logger.handlers):
        sh = logging.StreamHandler(sys.stdout)
        sh.setFormatter(FORMATTER)
        logger.addHandler(sh)

    return logger


def setup_file_logging(log_dir: Path | str | None = None) -> Path | None:
    """
    Add a timestamped file handler to the package logger.

    Called explicitly by entry points. Returns the log file path, or None when
    no directory is configured.
    """
    logger = get_logger()

    if log_dir is None:
        log_dir = os.getenv("TITANIC_LOG_DIR")
    if log_dir is None:
        return None

    log_dir = Path(log_dir)
    log_dir.mkdir(parents=True, exist_ok=True)

    timestamp = datetime.now().strftime("%Y-%m-%d_%H-%M-%S")
    log_file = log_dir / f"logs_{timestamp}.log"

    fh = logging.FileHandler(log_file)
    fh.setFormatter(FORMATTER)
    logger.addHandler(fh)

    logger.info(f"Log file created: {log_file}\n")
    return log_file
