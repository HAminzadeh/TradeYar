"""TradeYar AI adapter. No model is trained or loaded."""
from fastapi import FastAPI
from pydantic import BaseModel, Field

app = FastAPI(title="TradeYar AI", version="0.2.0")

class PredictionRequest(BaseModel):
    symbol: str = Field(min_length=3, max_length=20)
    features: dict[str, float] = Field(default_factory=dict)

@app.get("/health")
def health():
    return {"service": "tradeyar-ai", "status": "READY", "model_loaded": False,
            "trade_authorized": False}

@app.post("/predict")
def predict(request: PredictionRequest):
    return {"symbol": request.symbol, "signal": "NO_SIGNAL", "implemented": False,
            "trade_authorized": False, "reason": "No trained and validated model exists"}

@app.get("/predict")
def get_predict():
    return {"signal": "NO_SIGNAL", "implemented": False, "trade_authorized": False}