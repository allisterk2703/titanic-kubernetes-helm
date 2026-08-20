# titanic/evaluate.py
import json
import pickle
from pathlib import Path

from sklearn.metrics import (
    accuracy_score,
    confusion_matrix,
    f1_score,
    precision_score,
    recall_score,
)

from titanic.formatting import header
from titanic.logger import get_logger
from titanic.paths import get_model_dir, get_output_dir, print_paths

logger = get_logger()


def load_pickle(path: Path):
    with open(path, "rb") as f:
        return pickle.load(f)


def compute_metrics(y_true, y_pred):
    return {
        "accuracy": accuracy_score(y_true, y_pred),
        "precision": precision_score(y_true, y_pred, zero_division=0),
        "recall": recall_score(y_true, y_pred, zero_division=0),
        "f1": f1_score(y_true, y_pred, zero_division=0),
        "confusion_matrix": confusion_matrix(y_true, y_pred).tolist(),
    }


def print_metrics(metrics):
    logger.info(header("EVALUATION METRICS"))
    logger.info(f"Accuracy  : {metrics['accuracy']:.4f}")
    logger.info(f"Precision : {metrics['precision']:.4f}")
    logger.info(f"Recall    : {metrics['recall']:.4f}")
    logger.info(f"F1-score  : {metrics['f1']:.4f}")

    cm = metrics["confusion_matrix"]
    logger.info("Confusion Matrix:")
    logger.info(f"TN={cm[0][0]}  FP={cm[0][1]}")
    logger.info(f"FN={cm[1][0]}  TP={cm[1][1]}")


def save_metrics(metrics):
    out_dir = get_output_dir()
    out_dir.mkdir(parents=True, exist_ok=True)
    with open(out_dir / "metrics.json", "w") as f:
        json.dump(metrics, f, indent=4)
    logger.info(f"Saved metrics in {out_dir / 'metrics.json'}")


def evaluate():
    logger.info(header("EVALUATION PHASE"))

    model_dir = get_model_dir()

    # Load artifacts
    model = load_pickle(model_dir / "model.pkl")
    X_test_scaled = load_pickle(model_dir / "X_test_scaled.pkl")
    y_test = load_pickle(model_dir / "y_test.pkl")

    logger.info("Loaded artifacts successfully")

    # Predict
    y_pred = model.predict(X_test_scaled)

    # Compute metrics
    metrics = compute_metrics(y_test, y_pred)

    # Display & save
    print_metrics(metrics)
    save_metrics(metrics)

    logger.info(50 * "=" + "\n")

    return metrics


if __name__ == "__main__":
    print_paths()
    evaluate()
