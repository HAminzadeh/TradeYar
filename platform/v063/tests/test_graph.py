import unittest
from tradeyar_core.graph import PAIRS, CURRENCIES

class GraphDefinitions(unittest.TestCase):
    def test_currency_pair_definitions(self):
        for p in PAIRS:
            self.assertEqual(len(p),6)
            self.assertIn(p[:3],CURRENCIES)
            self.assertIn(p[3:],CURRENCIES)

if __name__ == '__main__': unittest.main()
