# titanic/train.py
import json
import logging
import os
import pickle
import time
from datetime import datetime
from pathlib import Path

import mlflow
import pandas as pd
from sklearn.linear_model import LogisticRegression
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import StandardScaler

from titanic.config import EXPERIMENT_NAME, MLFLOW_TRACKING_URI, TARGET_COLUMN
from titanic.formatting import header
from titanic.load import load_data
from titanic.logger import get_logger
from titanic.paths import get_model_dir, print_paths
from titanic.preprocess import preprocess

logger = get_logger()


def setup_mlflow() -> str:
    """
    Configure MLflow tracking. Called at run time, never at import time.

    Returns the experiment name.
    """
    logging.getLogger("mlflow.store.db.utils").disabled = True
    logging.getLogger("mlflow.tracking.fluent").disabled = True
    logging.getLogger("alembic.runtime.migration").disabled = True

    tracking_uri = os.getenv("MLFLOW_TRACKING_URI", MLFLOW_TRACKING_URI)
    experiment_name = os.getenv("MLFLOW_EXPERIMENT_NAME", EXPERIMENT_NAME)

    mlflow.set_tracking_uri(tracking_uri)
    if tracking_uri.startswith("sqlite:///") and not os.path.exists(tracking_uri.removeprefix("sqlite:///")):
        time.sleep(3)
    mlflow.set_experiment(experiment_name)

    return experiment_name


def save_pickle(obj, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with open(path, "wb") as f:
        pickle.dump(obj, f)


def save_json(data, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with open(path, "w") as f:
        json.dump(data, f, indent=2)


def split_xy(df: pd.DataFrame, target_col: str):
    X = df.drop(columns=[target_col])
    y = df[target_col]
    logger.info("Created X and y")
    return X, y


def compute_imputation_values(df: pd.DataFrame) -> dict:
    numeric_cols = df.select_dtypes(include=["number"]).columns
    strategy = {col: df[col].median() for col in numeric_cols}
    logger.info("Computed imputation medians")
    return strategy


def train_model(
    df: pd.DataFrame,
    target_col: str,
    test_size: float = 0.2,
    random_state: int = 42,
):
    logger.info(header("TRAINING PHASE"))

    # ---- MLflow run ----
    experiment_name = setup_mlflow()
    timestamp = datetime.now().strftime("%Y-%m-%d_%H-%M-%S")
    run_name = f"{experiment_name}_run_{timestamp}"
    logger.info(f"Starting MLflow run: {run_name}")

    with mlflow.start_run(run_name=run_name):
        mlflow.set_tag("timestamp", timestamp)
        mlflow.log_param("test_size", test_size)
        mlflow.log_param("random_state", random_state)

        # 1. Split features/target
        X, y = split_xy(df, target_col)

        # 2. Compute imputation strategy
        imputation_values = compute_imputation_values(X)

        # 3. Split train/test
        X_train, X_test, y_train, y_test = train_test_split(
            X, y, test_size=test_size, random_state=random_state, stratify=y
        )
        logger.info("Train-test split done")
        mlflow.log_metric("train_rows", len(X_train))
        mlflow.log_metric("test_rows", len(X_test))

        # 4. Apply imputation
        for col, val in imputation_values.items():
            X_train[col] = X_train[col].fillna(val)
            X_test[col] = X_test[col].fillna(val)
        logger.info("Imputation applied")

        # 5. Scale features
        scaler = StandardScaler()
        X_train_scaled = scaler.fit_transform(X_train)
        X_test_scaled = scaler.transform(X_test)
        logger.info("Scaling done")

        # 6. Train model
        model = LogisticRegression(max_iter=1000)
        model.fit(X_train_scaled, y_train)
        logger.info("Model trained")

        # 7. Compute accuracy for MLflow
        accuracy = model.score(X_test_scaled, y_test)
        mlflow.log_metric("accuracy", accuracy)
        logger.info(f"Test accuracy logged: {accuracy:.4f}")

        # 8. Save artifacts
        model_dir = get_model_dir()

        save_pickle(model, model_dir / "model.pkl")
        save_pickle(scaler, model_dir / "scaler.pkl")
        save_json(list(X_train.columns), model_dir / "feature_names.json")
        save_pickle(X_test_scaled, model_dir / "X_test_scaled.pkl")
        save_pickle(y_test, model_dir / "y_test.pkl")
        save_json(imputation_values, model_dir / "imputation.json")

        # Log MLflow artifacts
        mlflow.log_artifacts(str(model_dir))

        logger.info(f"Artifacts saved to: {model_dir.resolve()}")

    logger.info(50 * "=" + "\n")

    return model, scaler, X_test_scaled, y_test, imputation_values


if __name__ == "__main__":
    print_paths()
    df = load_data()
    df = preprocess(df)
    train_model(df, TARGET_COLUMN)
