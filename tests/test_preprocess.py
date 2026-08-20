# tests/test_preprocess.py
"""
Guard-rails against train/serve skew in the preprocessing step.

The categorical encoding used at inference must be the one learnt at training
time. Deriving it from the data being encoded silently produces a different
feature for the same passenger, which is invisible in the response.
"""

import pandas as pd
import pytest

from titanic import preprocess as pp


@pytest.fixture
def model_dir(tmp_path, monkeypatch):
    monkeypatch.setenv("MODEL_DIR", str(tmp_path))
    return tmp_path


def _frame(embarked):
    return pd.DataFrame(
        {
            "embarked": embarked,
            "sex": ["male"] * len(embarked),
            "sibsp": [0] * len(embarked),
            "parch": [0] * len(embarked),
        }
    )


def test_encoding_is_persisted_at_training(model_dir):
    pp.feature_engineering(_frame(["S", "C", "Q"]), mode="train")

    assert (model_dir / pp.ENCODING_FILE).exists()
    assert pp.load_encoding() == {"C": 0, "Q": 1, "S": 2}


def test_predict_reuses_the_training_encoding(model_dir):
    train = pp.feature_engineering(_frame(["S", "C", "Q", "S"]), mode="train")

    # One row at a time, the way the API calls it
    for value, expected in zip(["S", "C", "Q", "S"], train["embarked"].tolist()):
        encoded = pp.feature_engineering(_frame([value]), mode="predict")["embarked"].iloc[0]
        assert encoded == expected, f"{value} encoded as {encoded} at predict time, {expected} at training time"


def test_predict_without_a_trained_encoding_raises(model_dir):
    with pytest.raises(FileNotFoundError, match=pp.ENCODING_FILE):
        pp.feature_engineering(_frame(["S"]), mode="predict")


def test_unknown_category_falls_back_instead_of_crashing(model_dir):
    pp.feature_engineering(_frame(["S", "C"]), mode="train")

    encoded = pp.feature_engineering(_frame(["Z"]), mode="predict")["embarked"].iloc[0]
    assert encoded == -1


def test_predict_keeps_every_input_row(model_dir, monkeypatch):
    """A batch must return as many rows as it was given, duplicates included."""
    monkeypatch.setattr(pp, "fill_na_predict", lambda df: df)
    pp.feature_engineering(_frame(["S"]), mode="train")

    duplicated = pd.DataFrame(
        {
            "pclass": [3, 3, 1],
            "sex": ["male", "male", "female"],
            "age": [22.0, 22.0, 38.0],
            "sibsp": [1, 1, 1],
            "parch": [0, 0, 0],
            "fare": [7.25, 7.25, 71.28],
            "embarked": ["S", "S", "S"],
        }
    )

    assert len(pp.preprocess(duplicated, mode="predict", show_section=False)) == 3
