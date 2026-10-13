# Staged implementation

Run `powershell -ExecutionPolicy Bypass -File .\scripts\Build-TradeYar.ps1 -Stage All` from a cloned repo, or provide `-Root`.
For a single phase use `-Stage 0` .. `-Stage 11`; phases 0..N must be completed before testing phase N on its own.

0 Architecture and contracts
1 M01 core, M19 infrastructure
2 M02 interface and internationalization
3 M03 preferences
4 M04 market, M05 chart
5 M06 MT5 read-only adapter
6 M07 indicators, M08 strategies
7 M09 backtesting demo
8 M10 signals, M11 risk sizing
9 M12 paper trading, M13 journal
10 M14 news, M15 AI, M16 alerts, M17 reports, M18 learning
11 M20 LOCKED execution

Only synthetic market data is available at first. This scaffold should not be used to make investment decisions.