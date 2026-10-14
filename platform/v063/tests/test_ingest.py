from datetime import datetime, timezone
from pathlib import Path
import tempfile
import unittest
from tradeyar_core.ingest import iter_closed_bars, next_close, parse_utc

class IngestTests(unittest.TestCase):
    def test_iso_timezone_and_epoch(self):
        self.assertEqual(parse_utc('1704067200'),parse_utc('2024-01-01T00:00:00Z'))
        with self.assertRaises(ValueError): parse_utc('2024-01-01T00:00:00')
    def test_month_calendar(self):
        x=parse_utc('2024-01-01T00:00:00Z')
        self.assertEqual(next_close(x,'MN1'),parse_utc('2024-02-01T00:00:00Z'))
    def test_strict_ohlc(self):
        with tempfile.TemporaryDirectory() as d:
            f=Path(d)/'x.csv';f.write_text('time,open,high,low,close,volume\n1704067200,1.1,1.2,1.0,1.15,5\n')
            self.assertEqual(len(list(iter_closed_bars(f,'H1'))),1)
            f.write_text('time,open,high,low,close,volume\n1704067200,1.1,1.09,1.0,1.15,5\n')
            with self.assertRaisesRegex(ValueError,'OHLC'): list(iter_closed_bars(f,'H1'))
    def test_no_open_candle(self):
        with tempfile.TemporaryDirectory() as d:
            f=Path(d)/'x.csv';f.write_text('time,open,high,low,close,volume\n1704067200,1.1,1.2,1.0,1.15,5\n')
            with self.assertRaisesRegex(ValueError,'incomplete'):
                list(iter_closed_bars(f,'H1',now=parse_utc('2024-01-01T00:30:00Z')))
    def test_duplicate_time_rejected(self):
        with tempfile.TemporaryDirectory() as d:
            f=Path(d)/'x.csv';f.write_text('time,open,high,low,close,volume\n1704067200,1.1,1.2,1.0,1.15,5\n1704067200,1.1,1.2,1.0,1.15,5\n')
            with self.assertRaisesRegex(ValueError,'duplicate'): list(iter_closed_bars(f,'H1'))
if __name__=='__main__': unittest.main()
