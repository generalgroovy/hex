"""Offline deterministic factory tests; no Godot, generation, or production writes."""
import copy
import importlib.util
import json
import math
from pathlib import Path
import tempfile
import unittest

from PIL import Image, ImageDraw

REPO = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location("race_factory", REPO / "art_batches/race_sprite_factory_v1/factory.py")
factory = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(factory)


class RaceSpriteFactoryTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.data = json.loads((factory.RIG_DIR / "rig-data.json").read_text(encoding="utf-8"))
        cls.renderer, headless = factory.load_renderer()
        cls.headless = staticmethod(headless)

    def fixture(self, directory, mode="RGBA"):
        # Deliberately abstract rectangles: validation fixture, never shipped art.
        image = Image.new(mode, (256, 96))
        draw = ImageDraw.Draw(image)
        heads = {}
        for row, gender in enumerate(factory.GENDERS):
            for col, direction in enumerate(factory.DIRECTIONS):
                draw.rectangle((col*32+10, row*32+5, col*32+21, row*32+24), fill="#62bac9")
                draw.point((col*32+11+col, row*32+12), fill="#091b35")
                heads[f"{gender}/{direction}"] = {"rect": [col*32, row*32, 32, 32], "crown_anchor": [16, 5]}
        image.save(directory / "source.png")
        config = {"schema_version": 1, "race_id": "test", "source_png": "source.png",
                  "directions": list(factory.DIRECTIONS), "genders": list(factory.GENDERS),
                  "reference_head_height": 20, "heads": heads}
        recipe = directory / "recipe.json"
        factory.write_json(recipe, config)
        return recipe, config

    def test_complete_original_rig_contract(self):
        counts = factory.validate_rig(self.data)
        self.assertEqual(sum(v["total"] for v in counts.values()), 3312)

    def test_missing_frame_rejected(self):
        data = dict(self.data, poses=self.data["poses"][:-1])
        with self.assertRaisesRegex(ValueError, "Incomplete/duplicate"):
            factory.validate_rig(data)

    def test_recipe_strict_alpha_and_measurements(self):
        with tempfile.TemporaryDirectory() as directory:
            recipe, _ = self.fixture(Path(directory))
            config, source, parts, measurements = factory.load_recipe(recipe)
            self.assertEqual(len(parts), 24)
            self.assertEqual(measurements["neutral/S"]["source_alpha_bounds"], [10, 5, 22, 25])
            self.assertEqual(parts["neutral/S"].getchannel("A").getextrema(), (0, 255))

    def test_opaque_source_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            recipe, _ = self.fixture(Path(directory), "RGB")
            with self.assertRaisesRegex(ValueError, "explicit RGBA"):
                factory.load_recipe(recipe)

    def test_near_opaque_source_and_low_alpha_background_normalization(self):
        with tempfile.TemporaryDirectory() as directory:
            directory = Path(directory)
            recipe, config = self.fixture(directory)
            image = Image.open(directory / "source.png")
            alpha = image.getchannel("A").point(lambda a: 253 if a else 8)
            alpha.putpixel((0, 0), 0)
            image.putalpha(alpha)
            image.save(directory / "source.png")
            config["alpha_threshold"] = 127
            factory.write_json(recipe, config)
            _, _, parts, _ = factory.load_recipe(recipe)
            self.assertEqual(parts["neutral/S"].getchannel("A").getextrema(), (0, 255))

    def test_clipped_rect_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            recipe, config = self.fixture(Path(directory))
            config["heads"]["neutral/S"]["rect"] = [10, 5, 12, 20]
            factory.write_json(recipe, config)
            with self.assertRaisesRegex(ValueError, "clipped cell"):
                factory.load_recipe(recipe)

    def test_original_renderer_palette_untouched(self):
        self.assertEqual(self.renderer.CLOTH["skin"], "#e0ab76")
        self.assertEqual(self.headless.__globals__["CLOTH"]["skin"], "#69b8bc")
        self.assertIsNot(self.renderer.CLOTH, self.headless.__globals__["CLOTH"])

    def test_headless_body_and_fixed_scale_motion(self):
        with tempfile.TemporaryDirectory() as directory:
            recipe, _ = self.fixture(Path(directory))
            config, _, parts, _ = factory.load_recipe(recipe)
            heads, scales = factory.prepare_heads(config, parts, self.renderer, self.data)
            self.assertEqual(set(scales), set(factory.BODIES))
            for body in factory.BODIES:
                self.assertEqual(len({heads[(body, key)][0].size for key in parts}), 1)
                for state in ("grounded", "locomotion", "sprint_locomotion", "slide"):
                    poses = [p for p in self.data["poses"] if p["body"] == body and p["state"] == state and p["aim"] == 2]
                    pose = poses[0]
                    headless = self.headless(pose, self.data)
                    bounds = self.renderer.head_bounds(pose, self.data)
                    self.assertEqual(headless.getpixel((48, bounds[1]))[3], 0)
                    first = factory.assemble(pose, self.data, "neutral", self.renderer, self.headless, heads)
                    second = factory.assemble(pose, self.data, "neutral", self.renderer, self.headless, heads)
                    self.assertEqual(factory.rgba_sha(first), factory.rgba_sha(second))
                    self.assertEqual(factory.validate_cell(first)[3], 84)

    def test_production_output_rejected(self):
        with self.assertRaisesRegex(ValueError, "staged candidate roots"):
            factory.safe_output(REPO / "assets/sprites/test")

    def test_seakin_measured_head_placements_fit_all_original_poses(self):
        recipe = factory.HERE / "seakin.recipe.json"
        if not recipe.exists():
            self.skipTest("Pilot source not present")
        config, _, parts, _ = factory.load_recipe(recipe)
        heads, _ = factory.prepare_heads(config, parts, self.renderer, self.data)
        for pose in self.data["poses"]:
            bounds = self.renderer.head_bounds(pose, self.data)
            center_x = self.renderer.pixel(self.renderer.display_point(pose["points"]["head"], pose["body"]))[0]
            for gender in factory.GENDERS:
                head, anchor, kind = heads[(pose["body"], gender+"/"+factory.DIRECTIONS[pose["aim"]])]
                box = head.getchannel("A").getbbox()
                offset = (center_x-anchor[0], (bounds[3]+1 if kind == "chin" else bounds[1])-anchor[1])
                placed = (box[0]+offset[0], box[1]+offset[1], box[2]+offset[0], box[3]+offset[1])
                self.assertTrue(placed[0] > 0 and placed[1] > 0 and placed[2] < 96 and placed[3] < 84,
                                (pose["body"], gender, factory.pose_key(pose), placed))

    def test_bad_frame_alpha_rejected(self):
        cell = Image.new("RGBA", (96, 96))
        cell.putpixel((48, 83), (255, 255, 255, 128))
        with self.assertRaisesRegex(ValueError, "Nonbinary"):
            factory.validate_cell(cell)

    def test_torso_affine_anchor_mapping_lean_and_handedness(self):
        source_neck, source_pelvis = (12, 8), (20, 128)
        target_neck, target_pelvis = (43, 36), (53, 56)
        inverse, details = factory.torso_affine(source_neck, source_pelvis, target_neck, target_pelvis, .15)
        self.assertGreater(details["determinant"], 0)
        self.assertAlmostEqual(details["in_plane_lean_degrees"], math.degrees(math.atan2(10, 20)))
        a, b, c, d, e, f = inverse
        for source, target in ((source_neck, target_neck), (source_pelvis, target_pelvis)):
            self.assertAlmostEqual(a*target[0]+b*target[1]+c, source[0])
            self.assertAlmostEqual(d*target[0]+e*target[1]+f, source[1])

    def test_torso_rejects_reflection_and_degenerate_calibration(self):
        for pelvis, scale in (((0, -20), .1), ((0, 0), .1), ((0, 20), -.1)):
            with self.assertRaisesRegex(ValueError, "Degenerate or inverted"):
                factory.torso_affine((0, 0), pelvis, (48, 35), (48, 55), scale)

    def test_torso_layer_below_near_arms_and_above_legs(self):
        def marker(canvas, pose, data, gender):
            ImageDraw.Draw(canvas).rectangle((0, 0, 95, 83), fill="#ff00ff")
        renderer, headless = factory.load_renderer(torso_overlay=marker)
        pose = next(p for p in self.data["poses"] if p["body"] == "middle" and p["state"] == "grounded" and p["aim"] == 0)
        cell = headless(pose, self.data, "feminine")
        for chain in pose["chains"]:
            if chain["depth"] > pose["torso_depth"]:
                point = renderer.pixel(renderer.display_point(pose["points"][chain["keys"][-1]], "middle"))
                if chain["kind"] == "arm":
                    self.assertNotEqual(cell.getpixel(point)[:3], (255, 0, 255))
                else:
                    self.assertEqual(cell.getpixel(point)[:3], (255, 0, 255))

    def test_optional_torso_all_pose_affines_preserve_anchors(self):
        recipe = factory.HERE / "seakin-v2.recipe.json"
        if not recipe.exists():
            self.skipTest("Torso pilot recipe not present")
        config = factory.read_config(recipe)
        for pose in self.data["poses"]:
            body = pose["body"]
            target_neck = self.renderer.display_point(pose["points"]["neck"], body)
            target_pelvis = self.renderer.display_point(pose["points"]["pelvis"], body)
            for gender in factory.GENDERS:
                entry = config["torso"]["parts"][gender+"/"+factory.DIRECTIONS[pose["aim"]]]
                _, details = factory.torso_affine(entry["neck_anchor"], entry["pelvis_anchor"], target_neck, target_pelvis, .15)
                self.assertGreater(details["determinant"], 0)

    def test_short_vest_has_zero_standing_slide_roll_fallbacks(self):
        recipe = factory.HERE / "seakin-v3.recipe.json"
        if not recipe.exists():
            self.skipTest("Short vest source not present")
        config, _, parts, _ = factory.load_recipe(recipe)
        overlay, stats = factory.prepare_torsos(recipe, config, self.renderer, self.data)
        renderer, headless = factory.load_renderer(torso_overlay=overlay)
        heads, _ = factory.prepare_heads(config, parts, renderer, self.data)
        count = 0
        for pose in self.data["poses"]:
            if pose["state"] in ("grounded", "slide", "roll"):
                for gender in factory.GENDERS:
                    cell = factory.assemble(pose, self.data, gender, renderer, headless, heads)
                    factory.validate_cell(cell)
                    count += 1
        self.assertEqual(count, 216)
        self.assertEqual(stats["held_pose_fallbacks"], {})

    def test_v1_render_remains_pixel_identical_after_optional_extension(self):
        output = REPO / ".godot/race-sprite-candidates/seakin-v1"
        records_path = output / "seakin-middle-neutral.frames.json"
        if not records_path.exists():
            self.skipTest("Historical v1 candidate not present")
        config, _, parts, _ = factory.load_recipe(factory.HERE / "seakin.recipe.json")
        heads, _ = factory.prepare_heads(config, parts, self.renderer, self.data)
        records = {r["key"]: r for r in json.loads(records_path.read_text(encoding="utf-8"))}
        keys = ("grounded/2", "slide/6", "roll/4", "locomotion/0/2/3", "sprint_locomotion/6/2/6")
        for pose in self.data["poses"]:
            if pose["body"] == "middle" and factory.pose_key(pose) in keys:
                cell = factory.assemble(pose, self.data, "neutral", self.renderer, self.headless, heads)
                self.assertEqual(factory.rgba_sha(cell), records[factory.pose_key(pose)]["rgba_sha256"])


if __name__ == "__main__":
    unittest.main()
