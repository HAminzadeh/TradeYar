# Manual UI test steps
1. Open http://127.0.0.1:5173/#M01 and verify 20 cards.
2. Click all 20 sidebar buttons. URL hash and heading must update.
3. On M02 switch fa/en, confirm direction and translated labels. Try light/dark.
4. On M04/M05/M07 choose USDJPY and ensure new data is fetched.
5. On M08 evaluate SMA_CROSS and inspect other strategies as planned/not implemented.
6. On M09 run backtest, M11 calculate risk, M12 create one paper order.
7. On M13 journal shows created order; M17 report count increases.
8. On M16 add an alert and check it.
9. On M20 verify HTTP 423. NEVER test a real broker order.
10. Reload a module deep-link, verify the correct page opens.
