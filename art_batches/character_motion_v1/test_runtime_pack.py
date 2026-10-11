"""Lossless runtime promotion proof, independent of Godot's presentation tests."""
import hashlib
import json
import unittest
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
PACK = ROOT / "assets/sprites/fullbody_cast_v1"
SOURCE = ROOT / "art_batches/character_motion_v1/output/motion-common-heads-v3"


class RuntimePackTests(unittest.TestCase):
    def test_all_source_pixels_preserved(self):
        runtime = json.loads((PACK / "manifest.json").read_text())
        original = json.loads((SOURCE / "manifest.json").read_text())
        self.assertEqual(len(runtime["characters"]), 30)
        source_by_id = {c["id"]: c for c in original["characters"]}
        self.assertEqual(runtime["cranial_target_pixels"], 18)
        self.assertEqual(runtime["cell"], [128, 128])
        self.assertEqual(runtime["pivot"], [64, 104])
        for entry in runtime["characters"]:
            with self.subTest(character=entry["id"]):
                source = source_by_id[entry["id"]]
                atlas = Image.open(SOURCE / source["atlas"]).convert("RGBA")
                expected = Image.new("RGBA", (1024, 128))
                for index, name in enumerate(original["directions"]):
                    part = source["directions"][name]["layers"]["fullbody"]
                    x, y, w, h = part["rect"]
                    ox, oy = part["source_origin"]
                    expected.paste(atlas.crop((x, y, x+w, y+h)), (128*index+int(ox)+16, int(oy)+20))
                actual = Image.open(PACK / entry["atlas"]).convert("RGBA")
                self.assertEqual(expected.tobytes(), actual.tobytes())
                self.assertEqual(hashlib.sha256(actual.tobytes()).hexdigest(), entry["rgba_sha256"])
                self.assertEqual(entry["body"], source["body"])
                self.assertEqual(set(actual.getchannel("A").getdata()), {0, 255})
                for direction in entry["directions"].values():
                    self.assertEqual(len(direction["vertices"]), 289)
                    for vertex in direction["vertices"]:
                        self.assertIn(vertex[2], direction["bindings"])
                        self.assertIn(vertex[3], direction["bindings"])
        self.assertEqual(sum("keys" in c for c in runtime["characters"]), 3)


if __name__ == "__main__":
    unittest.main()
