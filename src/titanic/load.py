# titanic/load.py
import pandas as pd

from titanic.formatting import header
from titanic.logger import get_logger
from titanic.paths import get_input_dir, print_paths

logger = get_logger()

SUPPORTED_EXTENSIONS = [".csv", ".parquet", ".json"]


def load_data(file_name: str = "data.csv") -> pd.DataFrame:
    logger.info(header("DATA LOADING"))

    input_dir = get_input_dir()
    file_path = input_dir / file_name

    if not file_path.exists():
        raise FileNotFoundError(f"File not found: {file_path}\nExpected location: {input_dir.resolve()}")

    ext = file_path.suffix.lower()

    if ext not in SUPPORTED_EXTENSIONS:
        raise ValueError(f"Unsupported file extension: {ext}\nSupported formats: {SUPPORTED_EXTENSIONS}")

    logger.info(f"Loading data from: {file_path.resolve()}")

    if ext == ".csv":
        df = pd.read_csv(file_path)
    elif ext == ".parquet":
        df = pd.read_parquet(file_path)
    elif ext == ".json":
        df = pd.read_json(file_path)

    logger.info(f"Data loaded successfully: shape={df.shape}")

    logger.info(50 * "=" + "\n")

    return df


if __name__ == "__main__":
    print_paths()

    df = load_data()
    # print_head(df)
    # print_column_types(df)
