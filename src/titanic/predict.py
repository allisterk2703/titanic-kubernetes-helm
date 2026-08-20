# titanic/predict.py
import json
from typing import Union

import pandas as pd

from titanic.config import TARGET_COLUMN
from titanic.logger import get_logger
from titanic.paths import get_base_dir, print_paths
from titanic.preprocess import preprocess
from titanic.utils import align_features, load_model, load_scaler

logger = get_logger()


def predict(data: Union[dict, pd.DataFrame]) -> pd.Series:
    """
    Predict survival for one passenger or a batch.

    Args:
        data: dict or DataFrame with input features

    Returns:
        pd.Series of predictions (0 or 1)
    """
    logger.debug("🔹 Converting input to DataFrame")
    if isinstance(data, dict):
        df = pd.DataFrame([data])
    elif isinstance(data, pd.DataFrame):
        df = data.copy()
    else:
        raise TypeError("data must be a dict or DataFrame")

    logger.debug("🔹 Preprocessing input")
    df = preprocess(df, mode="predict", show_section=False)

    # Remove target column if present (safety)
    if TARGET_COLUMN in df.columns:
        df = df.drop(columns=[TARGET_COLUMN])

    logger.debug("🔹 Loading artifacts")
    scaler = load_scaler()
    model = load_model()

    logger.debug("🔹 Aligning features")
    df = align_features(df)

    logger.debug("🔹 Scaling features")
    df_scaled = scaler.transform(df)

    logger.debug("🔹 Predicting")
    preds = model.predict(df_scaled)

    logger.info(f"✅ Predictions: {preds.tolist()}")
    return pd.Series(preds, name="prediction")


if __name__ == "__main__":
    print_paths()

    # Load the example payload from input/example_input.json
    example_path = get_base_dir() / "input" / "example_input.json"
    with example_path.open() as f:
        example = json.load(f)

    logger.info("🎯 Running prediction on example input:")
    result = predict(example)
    logger.info(result)
