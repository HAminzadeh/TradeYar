# TradeYar v0.4: Research and safety contract

- **20** existing strategy IDs remain in `StrategyService.CATALOG`; only **3** currently implement basic synthetic evaluation.
- **23** UI software modules: M01..M20 + M21 consensus + M22 trading styles + M23 knowledge.
- This is not a 23-strategy trading system. The difference between software modules and 20 algorithm strategies is intentional.
- M21 returns `INSUFFICIENT_EVIDENCE`, not a BUY/SELL entry, pending genuine independent validated strategies, 16 aligned votes/20 and live-data validity.
- M23 reports zero verified historical coverage and no trained model. A ten-year *target window* is not evidence that ten years were downloaded, tested or learned.
- M22 settings are local-browser defaults; PostgreSQL persistence and shared account access controls are not ready.
- Resetting local settings does not delete orders, research data or models. The legacy server preferences `M03` require explicit confirmation before a reset PUT.
- Backend safety boundary is independent of the UI. `POST /api/live/orders` remains forbidden with HTTP 423.
- Stage 0/1 are the only implemented installer stages, remaining phases require actual data provider and production engineering work.

## Test gates

- `npm run build`: TypeScript and Vite succeed with installed Node dependencies.
- Maven tests succeed with JUnit contract and existing regression tests.
- Spring Boot restart then `scripts/Test-TradeYar-v04.ps1` checks legacy and new API contracts.
- Click all 23 UI links, verify guide + reset; compare Persian RTL/English LTR.
- Verify malicious/invalid profile IDs rejected; external URLs and imports are not accepted by research endpoints.
- Verify frontend never exposes automatic real trade placement.
