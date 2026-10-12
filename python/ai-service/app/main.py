from fastapi import FastAPI

app = FastAPI(title="TradeYar AI", version="0.1.0")

@app.get("/health")
def health():
    return {
        "service": "tradeyar-ai",
        "status": "READY",
        "model_loaded": False
    }

@app.get("/predict")
def predict():
    return {
        "signal": "NO_SIGNAL",
        "implemented": False,
        "message": "ML model not trained yet"
    }