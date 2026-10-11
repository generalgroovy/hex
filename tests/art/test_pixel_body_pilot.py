"""Structural checks only; native rendered review remains a separate gate."""
import hashlib
import json
import unittest
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
BANK = ROOT / "assets/sprites/pixel_body_pilot_v1"


class PixelBodyPilotTests(unittest.TestCase):
    def test_pages_and_registered_contacts(self):
        manifest = json.loads((BANK / "manifest.json").read_text())
        self.assertEqual([c["id"] for c in manifest["characters"]], ["s_wayne", "oh_tipi", "red_baron"])
        self.assertEqual(manifest["pivot"], [64, 104])
        for entry in manifest["characters"]:
            image = Image.open(BANK / entry["atlas"]).convert("RGBA")
            self.assertEqual(image.size, (1024, 768))
            self.assertEqual(hashlib.sha256(image.tobytes()).hexdigest(), entry["rgba_sha256"])
            self.assertTrue(set(image.getchannel("A").getdata()) <= {0, 255})
            for direction in range(8):
                frames = [image.crop((direction*128, row*128, (direction+1)*128, (row+1)*128)) for row in range(6)]
                for frame in frames:
                    box = frame.getbbox()
                    self.assertIsNotNone(box)
                    self.assertEqual(box[3], 104)
                    self.assertGreater(box[0], 0)
                    self.assertLess(box[2], 128)
                    self.assertLessEqual(box[3]-box[1], entry["display_height"]+4)
                self.assertNotEqual(frames[1].tobytes(), frames[3].tobytes(), f"distinct contacts {entry['id']}/{direction}")
                self.assertEqual(frames[0].tobytes(), frames[2].tobytes(), "passing reuse is explicit")
                self.assertEqual(frames[0].tobytes(), frames[4].tobytes(), "passing reuse is explicit")
            imports = (BANK / (entry["atlas"]+".import")).read_text()
            self.assertIn("process/fix_alpha_border=false", imports)
            self.assertIn("mipmaps/generate=false", imports)


if __name__ == "__main__":
    unittest.main()
