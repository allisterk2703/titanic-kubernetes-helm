# titanic/config.py
TARGET_COLUMN = "survived"
PROBLEM_TYPE = "binary_classification"  # regression, binary_classification, multiclass_classification

# MLflow defaults (overridable via MLFLOW_TRACKING_URI / MLFLOW_EXPERIMENT_NAME)
MLFLOW_TRACKING_URI = "sqlite:///mlflow.db"
EXPERIMENT_NAME = "titanic"
