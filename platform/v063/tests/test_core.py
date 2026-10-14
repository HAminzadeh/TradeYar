import unittest
from tradeyar_core.core import AuditEvent, authorized, fingerprint, safe_symbol, Settings, ConfigurationError

class CoreTests(unittest.TestCase):
    def test_stable_hash(self):
        self.assertEqual(fingerprint({'a': 1,'b':2}), fingerprint({'b':2,'a':1}))
    def test_token_denies_missing(self):
        self.assertFalse(authorized('anything',''))
        self.assertFalse(authorized(None,'longsecrettoken'))
        self.assertTrue(authorized('some-secret','some-secret'))
    def test_validation(self):
        self.assertEqual(safe_symbol(' eurusd '), 'EURUSD')
        with self.assertRaises(ValueError): safe_symbol('EURUSD;DELETE')
    def test_audit_immutable_hash(self):
        a=AuditEvent.new('DATA_INGESTED', {'rows': 10})
        self.assertFalse(a.trading_authorized)
        self.assertEqual(a.payload_hash, fingerprint(a.payload))
    def test_localhost_guard(self):
        x=Settings('','','x'*25,'0.0.0.0',8002,'development')
        with self.assertRaises(ConfigurationError): x.validate_http()

if __name__ == '__main__': unittest.main()
