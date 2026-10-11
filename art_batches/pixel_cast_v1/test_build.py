"""Structural acceptance only; pixels being valid does not certify animation."""
import hashlib
import json
import unittest
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "assets/sprites/pixel_cast_v1"
WORK = Path(__file__).resolve().parent


class FullCastAssembly(unittest.TestCase):
    def test_complete_catalog_registered_and_pixel_exact(self):
        roster = json.loads((ROOT / "content/champions/foundation_champions_v1.json").read_text())["champions"]
        manifest = json.loads((OUT / "manifest.json").read_text())
        expected = {row["id"]: row for row in roster}
        self.assertEqual({row["id"] for row in manifest["characters"]}, set(expected))
        self.assertEqual(len(manifest["characters"]), len(expected))
        self.assertEqual(manifest["rows"], ["idle", "walk_contact_a", "walk_contact_b", "cast"])
        self.assertEqual(manifest["directions"], ["S", "SE", "E", "NE", "N", "NW", "W", "SW"])
        report = json.loads((WORK / "review/assembly.json").read_text())
        self.assertEqual(report["missing"], [])
        self.assertEqual(report["errors"], [])
        for entry in manifest["characters"]:
            with self.subTest(identity=entry["id"]):
                self.assertEqual(entry["body"], expected[entry["id"]]["body_type"])
                image = Image.open(OUT / entry["atlas"]).convert("RGBA")
                self.assertEqual(image.size, (1024, 512))
                self.assertEqual(hashlib.sha256(image.tobytes()).hexdigest(), entry["rgba_sha256"])
                self.assertEqual(set(image.getchannel("A").getdata()), {0, 255})
                for row in range(4):
                    for col in range(8):
                        cell = image.crop((col*128,row*128,(col+1)*128,(row+1)*128))
                        box = cell.getbbox()
                        self.assertIsNotNone(box)
                        self.assertGreater(box[0], 0)
                        self.assertGreater(box[1], 0)
                        self.assertLess(box[2], 128)
                        self.assertEqual(box[3], 104)
                settings = (OUT / (entry["atlas"] + ".import")).read_text()
                self.assertIn("process/fix_alpha_border=false", settings)
                self.assertIn("mipmaps/generate=false", settings)
        for source in report["sources"]:
            self.assertEqual(hashlib.sha256((ROOT/source["source"]).read_bytes()).hexdigest(), source["source_sha256"])
            for correction in source.get("corrections", []):
                path = (ROOT/source["source"]).parent/correction["file"]
                self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(), correction["sha256"])


if __name__ == "__main__":
    unittest.main()
