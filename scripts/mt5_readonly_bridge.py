#!/usr/bin/env python3
"""TradeYar v0.5: OPTIONAL, explicitly launched, read-only MT5 closed-bar exporter.

No credentials, positions, order_send, or order modification. Connects to an already
logged-in local MT5 terminal. Install `MetaTrader5` separately on Windows (approved source).
Example: py -3 scripts/mt5_readonly_bridge.py --symbol EURUSD --timeframe M15 --bars 3000
Then set TRADEYAR_MARKET_DIR to the output directory and restart Spring Boot.
"""
import argparse
import csv
from datetime import datetime, timezone
import os
from pathlib import Path
import sys
import tempfile
import time

SYMBOLS = {"EURUSD", "GBPUSD", "USDJPY", "XAUUSD"}
FRAMES = {"M1", "M5", "M15", "M30", "H1", "H4", "D1", "W1", "MN1"}


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--symbol", choices=sorted(SYMBOLS), default="EURUSD")
    p.add_argument("--timeframe", choices=sorted(FRAMES), default="M15")
    p.add_argument("--bars", type=int, default=3000, help="Up to 20000 closed bars per export; history availability depends on MT5")
    p.add_argument("--loop", action="store_true", help="Only with explicit opt-in; refresh snapshots periodically")
    p.add_argument("--interval", type=int, default=30, help="Seconds; must be >= 10")
    p.add_argument("--output-dir", default=os.getenv("TRADEYAR_MARKET_DIR", str(Path.home() / "AppData" / "Local" / "TradeYar" / "market")))
    args = p.parse_args()
    if not 120 <= args.bars <= 20000 or args.interval < 10:
        p.error("--bars must be 120..20000 and --interval >=10")
    try:
        import MetaTrader5 as mt5
    except ImportError:
        print("ERROR: official MetaTrader5 Python package not installed. Use approved Python environment.", file=sys.stderr)
        return 2
    lookup = {"M1": mt5.TIMEFRAME_M1, "M5": mt5.TIMEFRAME_M5, "M15": mt5.TIMEFRAME_M15,
              "M30": mt5.TIMEFRAME_M30, "H1": mt5.TIMEFRAME_H1, "H4": mt5.TIMEFRAME_H4,
              "D1": mt5.TIMEFRAME_D1, "W1": mt5.TIMEFRAME_W1, "MN1": mt5.TIMEFRAME_MN1}
    if not mt5.initialize():
        print(f"MT5 failed to attach to logged-in terminal: {mt5.last_error()}", file=sys.stderr)
        return 3
    try:
        info = mt5.account_info()
        if info is None:
            print("MT5 is not logged into an account; read-only export aborted", file=sys.stderr)
            return 4
        print("Connected to local MT5 terminal (read-only); no credentials are written")
        dest = Path(args.output_dir).expanduser().resolve()
        dest.mkdir(parents=True, exist_ok=True)
        while True:
            if not mt5.symbol_select(args.symbol, True):
                print(f"Cannot select {args.symbol}: {mt5.last_error()}", file=sys.stderr)
                return 5
            # start_pos 1 deliberately excludes the currently forming candle (index zero).
            rates = mt5.copy_rates_from_pos(args.symbol, lookup[args.timeframe], 1, args.bars)
            if rates is None or len(rates) < 120:
                print(f"Too few bars for {args.symbol}/{args.timeframe}: {mt5.last_error()}", file=sys.stderr)
                return 6
            # MT5 returns newest -> older depending on Python call; ALWAYS sort UTC epoch.
            rows = sorted(rates, key=lambda x: int(x["time"]))
            destfile = dest / f"{args.symbol}_{args.timeframe}.csv"
            fd, tmpname = tempfile.mkstemp(prefix=".tradeyar-", suffix=".csv", dir=str(dest))
            try:
                with os.fdopen(fd, "w", newline="", encoding="utf-8") as f:
                    writer = csv.writer(f, lineterminator="\n")
                    writer.writerow(["time", "open", "high", "low", "close", "volume"])
                    for r in rows:
                        writer.writerow([int(r["time"]), float(r["open"]), float(r["high"]),
                                         float(r["low"]), float(r["close"]), int(r["tick_volume"])])
                os.replace(tmpname, destfile)
            finally:
                if os.path.exists(tmpname):
                    os.unlink(tmpname)
            stamp = datetime.fromtimestamp(int(rows[-1]["time"]), timezone.utc).isoformat()
            print(f"Wrote {len(rows)} CLOSED {args.timeframe} bars for {args.symbol} to {destfile}; last={stamp}", flush=True)
            if not args.loop:
                break
            time.sleep(args.interval)
        return 0
    finally:
        mt5.shutdown()


if __name__ == "__main__":
    raise SystemExit(main())
