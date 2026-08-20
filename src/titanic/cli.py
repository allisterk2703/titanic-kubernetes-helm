# titanic/cli.py
import argparse

from titanic.config import TARGET_COLUMN
from titanic.evaluate import evaluate
from titanic.load import load_data
from titanic.logger import get_logger, setup_file_logging
from titanic.paths import get_output_dir, print_paths
from titanic.preprocess import preprocess
from titanic.train import train_model

logger = get_logger()


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(prog="titanic-train", description="Run the Titanic training pipeline")
    parser.add_argument("--data-file", default="data.csv", help="Input file name inside the training data directory")
    parser.add_argument("--test-size", type=float, default=0.2, help="Test split proportion")
    parser.add_argument("--random-state", type=int, default=42, help="Random seed for the train/test split")
    parser.add_argument("--log-dir", default=None, help="Directory for log files (defaults to TITANIC_LOG_DIR)")
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> None:
    args = parse_args(argv)

    setup_file_logging(args.log_dir or str(get_output_dir() / "logs"))
    print_paths()

    df = load_data(args.data_file)
    df = preprocess(df)
    train_model(df, target_col=TARGET_COLUMN, test_size=args.test_size, random_state=args.random_state)
    evaluate()


if __name__ == "__main__":
    main()
