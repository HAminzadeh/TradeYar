# TradeYar

Java-first intelligent forex workstation.

Technologies:
- Java 21
- Spring Boot
- Python / FastAPI
- React / TypeScript
- MetaTrader 5 / MQL5
- PostgreSQL
- Redis

The generated version is an initial project scaffold.

MT5 account integration, market feeds, live indicators,
20 actual strategies, backtesting, ML and news intelligence
are planned modules, not completed trading features.

Live order submission is disabled.

## Setup

Run:

.\scripts\Setup-TradeYar.ps1 -InstallDependencies

## Start

Run:

.\scripts\Start-TradeYar.ps1

Dashboard:
http://localhost:5173

Backend:
http://localhost:8080/api/health