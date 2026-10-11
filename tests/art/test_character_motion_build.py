"""Small offline builder fixtures; no full cast build, runtime or source edits."""
import hashlib
import importlib.util
import json
import math
from pathlib import Path
import sys
import tempfile
import unittest
from unittest import mock

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
MODULE = ROOT / "art_batches/character_motion_v1"
sys.path.insert(0, str(MODULE))
spec = importlib.util.spec_from_file_location("character_motion_build_tests_target", MODULE / "build.py")
b = importlib.util.module_from_spec(spec)
spec.loader.exec_module(b)
sys.path.pop(0)


def fixture():
    directions = {}
    for direction in b.layers.DIRECTIONS:
        body = Image.new("RGBA", (96, 96))
        body.paste((30, 100, 190, 255), (36, 30, 60, 70))
        foot = Image.new("RGBA", (96, 96))
        foot.paste((140, 90, 30, 255), (39, 77, 47, 84))
        directions[direction] = {
            "spec": {"core_bounds": [35, 26, 61, 84], "anchor_status": "fixture"},
            "anchors": {"pelvis": [48, 65], "neck": [48, 40], "ankle_l": [42, 79], "toe_l": [44, 83]},
            "layers": {"torso": body, "foot_l": foot},
            "bindings": {"torso": ["pelvis", "neck"], "foot_l": ["ankle_l", "toe_l"]},
            "order": ["torso", "foot_l"], "receipt": {"fixture": True},
        }
    return {"character": {"id": "fixture", "display_name": "Fixture", "body": "small", "race": "human"}, "directions": directions}


class CharacterMotionBuildTests(unittest.TestCase):
    def test_core_scale_uses_anatomy_and_one_scale(self):
        source = fixture()
        self.assertEqual(b.core_scale(source["character"], source), (1.0, "fixture"))
        source["character"]["body"] = "large"
        self.assertAlmostEqual(b.core_scale(source["character"], source)[0], 68/58)
        source["directions"]["S"]["spec"]["core_bounds"][3] = 27
        with self.assertRaises(ValueError): b.core_scale(source["character"], source)

    def test_atlas_rectangles_inside_disjoint_and_binary(self):
        with tempfile.TemporaryDirectory() as temp:
            entry = b.pack_character(fixture(), Path(temp))
            atlas = Image.open(Path(temp)/entry["atlas"]).convert("RGBA")
            self.assertEqual(list(atlas.size), entry["atlas_dimensions"])
            self.assertEqual(atlas.width, 512)
            self.assertEqual(atlas.height & (atlas.height-1), 0)
            self.assertLessEqual(set(atlas.getchannel("A").getdata()), {0, 255})
            seen = []
            for view in entry["directions"].values():
                for layer in view["layers"].values():
                    x, y, w, h = layer["rect"]
                    self.assertGreaterEqual(min(x, y), 2)
                    self.assertLessEqual(x+w, atlas.width)
                    self.assertLessEqual(y+h, atlas.height)
                    for xx, yy, ww, hh in seen:
                        self.assertTrue(x+w <= xx or xx+ww <= x or y+h <= yy or yy+hh <= y)
                    seen.append([x, y, w, h])
            self.assertEqual(len(seen), 24)

    def test_packed_pixels_reconstruct_unit_scale_sources(self):
        original = fixture()
        with tempfile.TemporaryDirectory() as temp:
            entry = b.pack_character(original, Path(temp))
            atlas = Image.open(Path(temp)/entry["atlas"]).convert("RGBA")
            for direction, view in entry["directions"].items():
                for name, layer in view["layers"].items():
                    x, y, w, h = layer["rect"]
                    restored = Image.new("RGBA", (96, 96))
                    restored.paste(atlas.crop((x, y, x+w, y+h)), tuple(layer["source_origin"]))
                    if name == "fullbody":
                        expected = Image.new("RGBA", (96, 96))
                        for part in original["directions"][direction]["order"]:
                            expected.alpha_composite(original["directions"][direction]["layers"][part])
                    else:
                        expected = original["directions"][direction]["layers"][name]
                    self.assertEqual(restored.tobytes(), expected.tobytes())

    def test_cage_weights_are_finite_normalized_known_parts(self):
        with tempfile.TemporaryDirectory() as temp:
            entry = b.pack_character(fixture(), Path(temp))
            for view in entry["directions"].values():
                self.assertEqual(len(view["mesh_vertices"]), 17*17)
                for vertex in view["mesh_vertices"]:
                    self.assertEqual(len(vertex["parts"]), 2)
                    self.assertTrue(all(part in view["layers"] for part in vertex["parts"]))
                    weight = vertex["weight"]
                    self.assertTrue(math.isfinite(weight))
                    self.assertGreaterEqual(weight, 0)
                    self.assertLessEqual(weight, 1)
                    self.assertAlmostEqual(weight+(1-weight), 1)
                    self.assertTrue(all(math.isfinite(v) for v in vertex["point"]))

    def test_cage_trim_uvs_stay_inside_transparent_gutter(self):
        # Reproduce the renderer's trim-clamp arithmetic; native shader/UV
        # sampling is an additional engine gate, not established by this test.
        with tempfile.TemporaryDirectory() as temp:
            entry = b.pack_character(fixture(), Path(temp))
            atlas = Image.open(Path(temp)/entry["atlas"]).convert("RGBA")
            for view in entry["directions"].values():
                full = view["layers"]["fullbody"]
                x, y, w, h = full["rect"]
                ox, oy = full["source_origin"]
                self.assertEqual(full["unscaled_bounds"], [36, 30, 60, 84])
                for vertex in view["mesh_vertices"]:
                    px, py = vertex["point"]
                    u = min(x+w+1, max(x-1, x+px-ox))
                    v = min(y+h+1, max(y-1, y+py-oy))
                    self.assertTrue(0 <= u/atlas.width <= 1)
                    self.assertTrue(0 <= v/atlas.height <= 1)
                    self.assertTrue(x-1 <= u <= x+w+1)
                    self.assertTrue(y-1 <= v <= y+h+1)
                for px in range(x-1, x+w+2):
                    self.assertEqual(atlas.getpixel((px, y-1))[3], 0)
                    self.assertEqual(atlas.getpixel((px, y+h+1))[3], 0)
                for py in range(y-1, y+h+2):
                    self.assertEqual(atlas.getpixel((x-1, py))[3], 0)
                    self.assertEqual(atlas.getpixel((x+w+1, py))[3], 0)

    def test_cage_identity_transform_reconstructs_original_rest_points(self):
        # Identity transforms about each binding anchor must cancel that pivot.
        # This tests packed records/formula, not GDScript's deformed leg solver.
        with tempfile.TemporaryDirectory() as temp:
            entry = b.pack_character(fixture(), Path(temp))
            for view in entry["directions"].values():
                for vertex in view["mesh_vertices"]:
                    px, py = vertex["point"]
                    transformed = []
                    for part in vertex["parts"]:
                        root_anchor = view["layers"][part]["binding"][0]
                        ax, ay = view["anchors"][root_anchor]
                        transformed.append((px-ax+ax+16, py-ay+ay+20))
                    weight = vertex["weight"]
                    x = transformed[0][0]*weight+transformed[1][0]*(1-weight)
                    y = transformed[0][1]*weight+transformed[1][1]*(1-weight)
                    self.assertAlmostEqual(x, px+16)
                    self.assertAlmostEqual(y, py+20)

    def test_packing_deterministic_and_hash_matches(self):
        with tempfile.TemporaryDirectory() as first, tempfile.TemporaryDirectory() as second:
            a = b.pack_character(fixture(), Path(first))
            c = b.pack_character(fixture(), Path(second))
            self.assertEqual(a, c)
            self.assertEqual(a["atlas_sha256"], hashlib.sha256((Path(first)/"fixture.png").read_bytes()).hexdigest())
            self.assertTrue(a["review_required"])
            self.assertEqual(a["hidden_surface_status"], "correction_art_required_where_revealed")

    def test_bank_shape_with_mocked_small_contract(self):
        contract = {"clips": [
            {"id": "idle", "loop": True, "preview_fps": 4, "frames_proposed": 4, "priority": 1},
            {"id": "walk", "loop": True, "preview_fps": 10, "frames_proposed": 8, "priority": 1},
            {"id": "slide", "loop": True, "preview_fps": 12, "frames_proposed": 6, "priority": 1},
            {"id": "taunt", "loop": False, "preview_fps": 8, "frames_proposed": 4, "priority": 2},
        ]}
        # JSON fixture creation is testing input, not a repository file edit.
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            (root/"motion_contract.json").write_text(json.dumps(contract), encoding="utf-8")
            point = {"points": {"pelvis": [48.123456, 65], "neck": [48, 40]}}
            with mock.patch.object(b, "HERE", root), mock.patch.object(b.poses, "rest", return_value=point), mock.patch.object(b.poses, "pose", return_value=point):
                bank = b.make_bank()
            self.assertFalse(bank["production_ready"])
            self.assertEqual(set(bank["actions"]), {"idle", "walk", "slide"})
            self.assertTrue(bank["actions"]["walk"]["travel_matrix"])
            self.assertTrue(bank["actions"]["slide"]["travel_facing"])
            self.assertFalse(bank["actions"]["idle"]["travel_matrix"])
            for body in ("small", "middle", "large"):
                self.assertEqual(len(bank["bodies"][body]["clips"]), 80)
                self.assertEqual(len(bank["bodies"][body]["rest"]), 8)
                self.assertEqual(bank["bodies"][body]["rest"]["0"]["pelvis"][0], 48.1235)
                self.assertTrue(all(len(frames) == 8 for frames in bank["bodies"][body]["clips"].values()))

    def test_build_rejects_existing_and_uncontained_output_before_bank(self):
        with tempfile.TemporaryDirectory() as temp, mock.patch.object(b, "make_bank") as expensive:
            with self.assertRaises(ValueError): b.build(Path(temp))
            with self.assertRaises(ValueError): b.build(Path(temp)/"not-in-project")
            expensive.assert_not_called()


if __name__ == "__main__": unittest.main()
