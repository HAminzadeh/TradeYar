"""Opt-in local-only, token-protected research API. No trade execution endpoints."""
from .core import Settings, authorized


def create_app():
    from fastapi import FastAPI, Header, HTTPException
    from pydantic import BaseModel, Field
    settings = Settings.from_env()
    settings.validate_http()
    app = FastAPI(title='TradeYar Research Platform', version='0.7.0')

    class BacktestRequest(BaseModel):
        csv_path: str = Field(min_length=1)
        strategy: str = 'sma_cross'
        fast: int = Field(default=10, ge=2, le=1000)
        slow: int = Field(default=30, ge=3, le=2000)
        spread_pips: float = Field(default=1.5, ge=0, le=100)
        pip_size: float = Field(default=0.0001, gt=0)

    @app.get('/health')
    def health():
        return {'status': 'READY', 'mode': 'RESEARCH_ONLY',
                'live_execution': False, 'config': settings.safe_summary()}

    @app.post('/research/backtest')
    def backtest(request: BacktestRequest, authorization: str | None = Header(default=None)):
        bearer = (authorization or '')
        token = bearer[7:] if bearer.startswith('Bearer ') else None
        if not authorized(token, settings.api_token):
            raise HTTPException(401, 'Unauthorized')
        try:
            from .backtest import read_bars_csv, backtest_sma
        except ImportError:
            raise HTTPException(409, 'Install Part4 first')
        # Never accept arbitrary remote paths: files must reside under a configured research directory.
        from pathlib import Path
        allowed = Path(__import__('os').environ.get('TRADEYAR_RESEARCH_INPUT_DIR', '')).expanduser()
        if not str(allowed) or str(allowed) == '.':
            raise HTTPException(409, 'TRADEYAR_RESEARCH_INPUT_DIR not configured')
        root = allowed.resolve()
        input_path = Path(request.csv_path).resolve()
        if not input_path.is_relative_to(root) or not input_path.is_file() or input_path.suffix.lower() != '.csv':
            raise HTTPException(400, 'Input must be a CSV within TRADEYAR_RESEARCH_INPUT_DIR')
        try:
            bars = read_bars_csv(input_path)
            return backtest_sma(bars, request.fast, request.slow,
                                request.spread_pips, request.pip_size)
        except (ValueError, OSError) as ex:
            raise HTTPException(422, str(ex))
    return app
