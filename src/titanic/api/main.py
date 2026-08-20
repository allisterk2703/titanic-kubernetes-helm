# titanic/api/main.py
import os

from fastapi import FastAPI
from pydantic import BaseModel

from titanic.predict import predict as run_prediction

app = FastAPI(title="Titanic inference API")


class PassengerFeatures(BaseModel):
    pclass: int
    sex: str
    age: float
    sibsp: int
    parch: int
    fare: float
    embarked: str


@app.get("/health")
def health():
    return {"status": "ok"}


@app.post("/predict")
def predict(passenger: PassengerFeatures):
    prediction = run_prediction(passenger.model_dump())
    return {"prediction": int(prediction.iloc[0])}


def serve() -> None:
    """Entry point for the `titanic-serve` console script."""
    import uvicorn

    uvicorn.run(
        "titanic.api.main:app",
        host=os.getenv("HOST", "0.0.0.0"),
        port=int(os.getenv("PORT", "8080")),
    )
