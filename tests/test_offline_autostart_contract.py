"""Static safety and startup wiring contract for the TradeYar offline research launcher."""
import json
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BOOTSTRAP = ROOT / 'scripts/Start-TradeYar-ResearchServices.ps1'
MAIN = ROOT / 'scripts/Start-TradeYar.ps1'
LEGACY = ROOT / 'scripts/Start-TradeYar-Offline.ps1'
MANAGER = ROOT / 'scripts/Manage-TradeYar-OfflineImages.ps1'
LOCK = ROOT / 'infrastructure/v063/offline-images.lock.json'
COMPOSE = ROOT / 'infrastructure/v063/compose.yml'


class TestOfflineStartup(unittest.TestCase):
    def test_exact_three_services_no_minio_container_creation(self):
        images = json.loads(LOCK.read_text(encoding='utf-8'))['assets']
        self.assertEqual({x['service'] for x in images}, {'timescale', 'neo4j', 'clickhouse'})
        compose = COMPOSE.read_text(encoding='utf-8')
        self.assertNotRegex(compose, r'(?m)^  minio:\s*$')
        self.assertEqual(set(re.findall(r'^\s*image:\s*(\S+)', compose, re.M)),
                         {x['image'] for x in images})

    def test_startup_has_offline_safety_controls(self):
        source = BOOTSTRAP.read_text(encoding='utf-8')
        low = source.lower()
        self.assertIn('--pull never', source)
        self.assertIn('--no-build', source)
        self.assertIn('--no-recreate', source)
        self.assertIn('shared-minio.json', low)
        self.assertIn('imageId', source)
        self.assertIn('Manage-TradeYar-OfflineImages.ps1', source)
        self.assertIn('-Mode Verify -Services $svc', source)
        self.assertIn('-Mode Restore -Services $svc', source)
        self.assertIn('minioManagedByTradeYar', source)
        self.assertIn('TRADEYAR-STARTUP', source)
        for cmd in ('docker pull', 'docker save', 'docker system prune',
                    'docker volume rm', 'docker compose down',
                    'invoke-webrequest', 'invoke-restmethod', 'pip install',
                    'npm ci', 'docker build', 'docker rm'):
            self.assertNotIn(cmd, low)
        self.assertIn("'Check','Start'", source)
        self.assertIn("'timescale','neo4j','clickhouse'", source)
        self.assertNotIn("'timescale','neo4j','clickhouse','minio'", source)

    def test_main_entrypoint_launches_offline_infrastructure_first(self):
        main = MAIN.read_text(encoding='utf-8-sig')
        self.assertIn('TRADEYAR-PHASE2-AUTOSTART-BEGIN', main)
        self.assertIn('TRADEYAR-PHASE2-AUTOSTART-END', main)
        self.assertIn('Start-TradeYar-ResearchServices.ps1', main)
        self.assertIn('TRADEYAR_AUTO_REPAIR_ON_STARTUP', main)
        self.assertIn('DemoOnly', main)
        self.assertIn('StrictOfflineApplication', main)
        self.assertIn('-NoServices -StartFrontend', main)
        self.assertLess(main.index('Start-TradeYar-ResearchServices.ps1'),
                        main.index('Start-Process'))

    def test_legacy_offline_launcher_uses_current_image(self):
        legacy = LEGACY.read_text(encoding='utf-8')
        self.assertIn("clickhouse:25.3.14.14", legacy)
        self.assertNotIn("clickhouse/clickhouse-server:25.3", legacy)
        self.assertIn('--pull never', legacy)

    def test_manager_retains_audited_restore(self):
        manager = MANAGER.read_text(encoding='utf-8')
        self.assertIn("'Restore'", manager)
        self.assertIn('docker load', manager)
        self.assertIn('Get-FileHash', manager)


if __name__ == '__main__':
    unittest.main()
