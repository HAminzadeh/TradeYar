# Development API (all under http://localhost:8080)

- `GET /api/health` â€” existing status from initial scaffold.
- `GET /api/modules` â€” module registry.
- `GET /api/preferences`, `PUT /api/preferences` â€” in-memory locale preferences.
- `GET /api/market/candles?symbol=EURUSD&limit=100` â€” synthetic candles.
- `GET /api/market/quote?symbol=EURUSD` â€” synthetic snapshot.
- `GET /api/charts/series?symbol=EURUSD` â€” chart data wrapper.
- `GET /api/mt5/status` â€” disconnected or last CSV snapshot from configured file.
- `GET /api/technical/summary?symbol=EURUSD` â€” SMA/EMA/RSI.
- `GET /api/strategies` / `GET /api/strategies/evaluate?strategy=SMA_CROSS` â€” strategies.
- `GET /api/backtest/run?symbol=EURUSD&strategy=SMA_CROSS` â€” demonstrator using synthetic data.
- `GET /api/signals/preview?symbol=EURUSD` â€” untrusted trading signal preview.
- `POST /api/risk/position-size` â€” capped estimated size, not trade authorization.
- `GET /api/paper/orders`, `POST /api/paper/orders` â€” simulated paper orders only.
- `GET /api/journal` â€” simulated order record view.
- `GET /api/news/events` â€” non-live sample calendar events.
- `GET /api/ai/status` â€” optional Python service health check.
- `GET /api/alerts`, `POST /api/alerts`, `GET /api/alerts/check` â€” in-memory alerts.
- `GET /api/reports/overview` â€” mock trade counts; no fabricated P/L.
- `GET /api/education/lessons?lang=fa` â€” basic learning content.
- `GET /api/live/status`, `POST /api/live/orders` â€” hard-locked execution (423).

No API here is authorized for internet-facing production use until authentication, rate limiting, validation, persistence and monitoring have been implemented.