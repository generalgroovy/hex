"""Offline contract tests; synthetic rectangles are fixtures, never candidate art."""
import copy
import importlib.util
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from PIL import Image, ImageDraw

REPO = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("named_cast", REPO / "art_batches/character_cast_v1/build.py")
cast = importlib.util.module_from_spec(spec)
spec.loader.exec_module(cast)
fullbody_spec = importlib.util.spec_from_file_location("fullbody_cast", REPO / "art_batches/character_cast_v1/fullbody.py")
fullbody = importlib.util.module_from_spec(fullbody_spec)
fullbody_spec.loader.exec_module(fullbody)


class NamedCastTests(unittest.TestCase):
    def fixture(self, path):
        image = Image.new("RGBA", (256, 32))
        draw = ImageDraw.Draw(image)
        heads = {}
        for i,direction in enumerate(cast.DIRECTIONS):
            draw.rectangle((i*32+10, 5, i*32+22, 24), fill=(65+i, 120, 170, 255))
            heads[direction] = {"rect": [i*32, 0, 32, 32], "chin_anchor": [16, 24]}
        source = path / "source.png"
        image.save(source)
        recipe = {"schema_version": 1, "character_id": "example", "directions": list(cast.DIRECTIONS),
                  "source_png": "source.png", "source_sha256": cast.sha(source), "reference_head_height": 20,
                  "heads": heads}
        character = {"id": "example", "race": "Human", "size": "middle", "appearance": "unspecified",
                     "component_recipe": "recipe.json"}
        cast.write_json(path / "recipe.json", recipe)
        cast.write_json(path / "catalog.json", {"schema_version": 1, "characters": [character]})
        return recipe, character

    def test_valid_eight_direction_recipe(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            _, char = self.fixture(root)
            config, parts, torso, provenance = cast.load_recipe(root / "recipe.json", char)
            self.assertEqual(len(parts), 8)
            self.assertIsNone(torso)
            self.assertEqual(len(provenance["identity_fingerprint"]), 64)
            self.assertEqual(set(parts["S"].getchannel("A").getdata()), {0,255})

    def test_missing_source_fails_preflight_without_output(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            _, char = self.fixture(root)
            char["component_recipe"] = None
            cast.write_json(root / "catalog.json", {"schema_version": 1, "characters": [char]})
            with self.assertRaisesRegex(ValueError, "Missing component_recipe"):
                cast.preflight(root / "catalog.json")
            self.assertEqual({p.name for p in root.iterdir()}, {"source.png", "recipe.json", "catalog.json"})

    def test_hash_required_and_verified(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            recipe, char = self.fixture(root)
            for digest in (None, "0"*64):
                recipe["source_sha256"] = digest
                cast.write_json(root / "recipe.json", recipe)
                with self.assertRaises((ValueError, TypeError)):
                    cast.load_recipe(root / "recipe.json", char)

    def test_reject_missing_direction_overlap_and_clipping(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            original, char = self.fixture(root)
            mutations = []
            recipe = copy.deepcopy(original)
            del recipe["heads"]["NE"]
            mutations.append(recipe)
            recipe = copy.deepcopy(original)
            recipe["heads"]["SE"]["rect"] = recipe["heads"]["S"]["rect"]
            mutations.append(recipe)
            recipe = copy.deepcopy(original)
            recipe["heads"]["S"]["rect"] = [10,0,22,32]
            mutations.append(recipe)
            for recipe in mutations:
                cast.write_json(root / "recipe.json", recipe)
                with self.assertRaises(ValueError):
                    cast.load_recipe(root / "recipe.json", char)

    def test_nonfinite_anchor_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            recipe, char = self.fixture(root)
            recipe["heads"]["S"]["chin_anchor"] = [float("nan"), 24]
            cast.write_json(root / "recipe.json", recipe)
            with self.assertRaisesRegex(ValueError, "Invalid chin_anchor"):
                cast.load_recipe(root / "recipe.json", char)

    def test_named_recipe_identity_not_substituted(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            _, char = self.fixture(root)
            char["id"] = "other"
            with self.assertRaisesRegex(ValueError, "character_id mismatch"):
                cast.load_recipe(root / "recipe.json", char)

    def test_duplicate_named_art_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            recipe, char = self.fixture(root)
            second = {**char, "id": "second", "component_recipe": "second.json"}
            cast.write_json(root / "second.json", {**recipe, "character_id": "second"})
            cast.write_json(root / "catalog.json", {"schema_version": 1, "characters": [char, second]})
            with self.assertRaisesRegex(ValueError, "Duplicate named identity"):
                cast.preflight(root / "catalog.json")

    def test_expected_banks(self):
        source = cast.read_json(cast.factory.RIG_DIR / "rig-data.json")
        keys = cast.expected_keys(source["base_rows"])
        self.assertEqual(len(keys), 1104)
        self.assertIn("slide/7", keys)
        self.assertIn("locomotion/7/0/6", keys)
        self.assertIn("sprint_locomotion/0/7/6", keys)

    def test_output_cannot_target_production_or_existing(self):
        for path in (REPO / "assets/sprites/cast", REPO, cast.HERE / "output"):
            with self.assertRaises(ValueError):
                cast.safe_output(path)

    def test_nonmutating_volume_headless_adapter(self):
        source = cast.read_json(cast.factory.RIG_DIR / "rig-data.json")
        before = json.dumps(source, sort_keys=True)
        data = cast.volume.adapt_data(source)
        renderer, headless = cast.load_body_renderer()
        pose = next(p for p in data["poses"] if p["body"] == "large" and p["state"] == "grounded" and p["aim"] == 0)
        frame = headless(pose, data)
        self.assertEqual(frame.size, (96,96))
        self.assertEqual(frame.mode, "RGBA")
        self.assertEqual(json.dumps(source, sort_keys=True), before)
        self.assertEqual(frame.getchannel("A").getbbox()[3], 84)

    def test_unknown_selection_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            self.fixture(root)
            with self.assertRaisesRegex(ValueError, "Unknown requested"):
                cast.preflight(root / "catalog.json", ["missing"])

    def test_fullbody_uniform_scale_and_registration(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            recipe, char = self.fixture(root)
            recipe["body_parts"] = {d: {"rect": v["rect"], "ground_anchor": [16,25]} for d,v in recipe.pop("heads").items()}
            recipe["reference_body_height"] = 20
            cast.write_json(root / "fullbody.json", recipe)
            config, parts, provenance = fullbody.load_recipe(root / "fullbody.json", char)
            cells, measurements = fullbody.assemble_parts(config, parts, char)
            self.assertEqual(len(cells), 8)
            self.assertEqual(measurements["uniform_scale"], 63/20)
            self.assertTrue(all(cell.getchannel("A").getbbox()[3] == 84 for cell in cells.values()))

    def test_fullbody_missing_recipe_not_substituted_with_head(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            self.fixture(root)
            with self.assertRaisesRegex(ValueError, "Missing fullbody_recipe"):
                fullbody.preflight(root / "catalog.json")

    def test_fullbody_honest_height_calibration(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            recipe, char = self.fixture(root)
            recipe["body_parts"] = {d: {"rect": v["rect"], "ground_anchor": [16,25]} for d,v in recipe.pop("heads").items()}
            recipe["reference_body_height"] = 50
            cast.write_json(root / "fullbody.json", recipe)
            with self.assertRaisesRegex(ValueError, "Reference body height"):
                fullbody.load_recipe(root / "fullbody.json", char)

    def test_fullbody_roundtrip_and_tamper_detection(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            recipe, char = self.fixture(root)
            recipe["body_parts"] = {d: {"rect": v["rect"], "ground_anchor": [16,25]} for d,v in recipe.pop("heads").items()}
            recipe["reference_body_height"] = 20
            cast.write_json(root / "fullbody.json", recipe)
            char["fullbody_recipe"] = "fullbody.json"
            cast.write_json(root / "catalog.json", {"schema_version": 1, "characters": [char]})
            # Test-only fixture output, never the allowed real candidate roots.
            with patch.object(fullbody.components, "safe_output", return_value=root / "candidate"):
                receipt = fullbody.build(root / "catalog.json", root / "candidate")
            self.assertEqual(receipt["authored_idle_directions"], 8)
            self.assertEqual(receipt["movement_animation_frames"], 0)
            self.assertFalse(receipt["production_ready"])
            manifest_path = root / "candidate/manifest.json"
            manifest = cast.read_json(manifest_path)
            manifest["characters"][0]["atlas_sha256"] = "0"*64
            cast.write_json(manifest_path, manifest)
            with self.assertRaisesRegex(ValueError, "Atlas hash mismatch"):
                fullbody.check(root / "candidate")


if __name__ == "__main__":
    unittest.main()
