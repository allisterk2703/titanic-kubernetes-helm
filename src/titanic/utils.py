# titanic/utils.py
import json
import pickle
from typing import List, Optional

import pandas as pd

from titanic.logger import get_logger
from titanic.paths import get_model_dir

logger = get_logger()


def load_pickle(name: str):
    """Load a pickled object from the model directory."""
    model_dir = get_model_dir()
    path = model_dir / name

    if not path.exists():
        raise FileNotFoundError(f"❌ Missing artifact: {path.resolve()}")

    with open(path, "rb") as f:
        return pickle.load(f)


def load_model():
    """Load the trained model from saved pickle file."""
    return load_pickle("model.pkl")


def load_scaler():
    """Load the fitted scaler from saved pickle file."""
    return load_pickle("scaler.pkl")


def print_head(df: pd.DataFrame) -> None:
    logger.info("\n📊 First 5 rows:")
    logger.info(f"\n{df.head()}")


def print_column_types(df: pd.DataFrame) -> None:
    logger.info("\n📊 Column types:")
    logger.info(f"\n{df.dtypes}")


def load_feature_names() -> List[str]:
    """Load feature names from saved JSON file."""
    model_dir = get_model_dir()
    path = model_dir / "feature_names.json"

    if not path.exists():
        raise FileNotFoundError(f"❌ Missing feature names file: {path.resolve()}")

    with open(path, "r") as f:
        return json.load(f)


def align_features(df: pd.DataFrame, feature_names: Optional[List[str]] = None) -> pd.DataFrame:
    """
    Align DataFrame columns with expected feature names.

    Args:
        df: DataFrame to align
        feature_names: List of expected feature names. If None, loads from saved file.

    Returns:
        DataFrame with columns aligned to feature_names order, missing columns filled with 0.
    """
    if feature_names is None:
        feature_names = load_feature_names()

    df = df.copy()
    for col in feature_names:
        if col not in df.columns:
            df[col] = 0
    df = df[feature_names]
    return df
