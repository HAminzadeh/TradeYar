import unittest, tempfile, pathlib
from tradeyar_core.v062_adapter import FRAMES, verified_history, sync_timescale
class V062AdapterTests(unittest.TestCase):
 def test_all_supported_intraday_frames(self):
  self.assertEqual(FRAMES['H4'],14400)
  self.assertNotIn('MN1',FRAMES)
 def test_requires_v062_source(self):
  with tempfile.TemporaryDirectory() as d:
   with self.assertRaises(FileNotFoundError):verified_history(d,d)
 def test_requires_config(self):
  with self.assertRaises(ValueError):sync_timescale('.','.','')
 def test_negative_max(self):
  with self.assertRaises(ValueError):verified_history('.','.',max_rows=2)
