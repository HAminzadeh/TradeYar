"""Phase 2 image inventory contract with external shared MinIO (no Docker required)."""
import json
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LOCK = ROOT / "infrastructure/v063/offline-images.lock.json"
COMPOSE = ROOT / "infrastructure/v063/compose.yml"
MANAGER = ROOT / "scripts/Manage-TradeYar-OfflineImages.ps1"
STARTER = ROOT / "scripts/Start-TradeYar-Offline.ps1"


class SharedMinioOfflineContract(unittest.TestCase):
    def test_only_three_owned_research_images_are_locked(self):
        data = json.loads(LOCK.read_text(encoding="utf-8"))
        self.assertEqual(data["schemaVersion"], 1)
        self.assertEqual(data["projectName"], "tradeyar-v063")
        assets = data["assets"]
        self.assertEqual({a["service"] for a in assets}, {"timescale", "neo4j", "clickhouse"})
        self.assertEqual(len(assets), 3)
        self.assertEqual(
            next(a["image"] for a in assets if a["service"] == "clickhouse"),
            "clickhouse:25.3.14.14",
        )
        compose = COMPOSE.read_text(encoding="utf-8")
        images = re.findall(r"^\s*image:\s*(\S+)\s*$", compose, re.MULTILINE)
        self.assertCountEqual(images, [a["image"] for a in assets])
        self.assertNotRegex(compose, r"(?m)^  minio:\s*$")
        self.assertIn("MinIO is an EXTERNAL", compose)

    def test_no_implicit_online_or_shared_minio_modification(self):
        manager = MANAGER.read_text(encoding="utf-8").lower()
        starter = STARTER.read_text(encoding="utf-8").lower()
        for script in (manager, starter):
            self.assertNotIn("docker pull", script)
        self.assertNotIn("'timescale','neo4j','clickhouse','minio'", manager)
        self.assertNotIn("'timescale','neo4j','clickhouse','minio'", starter)
        self.assertIn("docker load", manager)
        self.assertIn("docker save", manager)
        self.assertIn("--pull never", starter)


if __name__ == "__main__":
    unittest.main()
