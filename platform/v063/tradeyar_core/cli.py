"""Run using: python -m tradeyar_core.cli ... (with PYTHONPATH=platform)."""
from __future__ import annotations
import argparse
import json
from .core import Settings


def main() -> int:
    p = argparse.ArgumentParser(description='TradeYar research-only platform')
    sub = p.add_subparsers(dest='command', required=True)
    sub.add_parser('inspect', help='Print safe configuration (no secrets)')
    sub.add_parser('serve', help='Launch a local token-protected research API')
    imp = sub.add_parser('ingest-bars', help='Import a closed-bar CSV into TimescaleDB (Part3)')
    imp.add_argument('--file', required=True)
    imp.add_argument('--symbol', required=True)
    imp.add_argument('--timeframe', required=True)
    imp.add_argument('--provider', required=True)
    imp.add_argument('--source-license', default='UNVERIFIED')
    imp.add_argument('--allow-unverified', action='store_true')
    res = sub.add_parser('backtest', help='Offline SMA backtest of CSV (Part4)')
    res.add_argument('--file', required=True)
    res.add_argument('--fast', type=int, default=10)
    res.add_argument('--slow', type=int, default=30)
    res.add_argument('--spread-pips', type=float, default=1.5)
    res.add_argument('--pip-size', type=float, default=0.0001)
    wf = sub.add_parser('walkforward', help='Chronological train/test parameter selection (Part4)')
    wf.add_argument('--file', required=True)
    wf.add_argument('--train', type=int, default=600)
    wf.add_argument('--test', type=int, default=200)
    wf.add_argument('--embargo', type=int, default=10)
    args = p.parse_args()
    if args.command == 'inspect':
        print(json.dumps(Settings.from_env().safe_summary(), indent=2)); return 0
    if args.command == 'serve':
        from .api import create_app
        import uvicorn
        cfg = Settings.from_env()
        uvicorn.run(create_app(), host=cfg.host, port=cfg.port); return 0
    if args.command == 'ingest-bars':
        from .ingest import ingest_csv
        result = ingest_csv(args.file, args.symbol, args.timeframe, args.provider,
                            args.source_license, args.allow_unverified)
        print(json.dumps(result, indent=2)); return 0
    if args.command == 'backtest':
        from .backtest import backtest_sma, read_bars_csv
        print(json.dumps(backtest_sma(read_bars_csv(args.file), args.fast, args.slow,
                                       args.spread_pips, args.pip_size), indent=2)); return 0
    if args.command == 'walkforward':
        from .backtest import read_bars_csv
        from .walkforward import walkforward_sma
        print(json.dumps(walkforward_sma(read_bars_csv(args.file), args.train, args.test,
                                         args.embargo), indent=2)); return 0
    return 2

if __name__ == '__main__':
    raise SystemExit(main())
