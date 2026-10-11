"""Fixed anatomical head scaling; no source writes or engine dependencies."""
import copy
import importlib.util
import json
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("head_contract", ROOT / "art_batches/character_motion_v1/head_contract.py")
head = importlib.util.module_from_spec(spec)
spec.loader.exec_module(head)


class HeadContractTests(unittest.TestCase):
    def test_shared_target_not_body_dependent(self):
        for source_height in (11, 16, 19, 23, 55):
            plan = head.make_head_plan([30, 20, 48, 20 + source_height])
            self.assertAlmostEqual(plan["head_scale"] * source_height, 18)
            self.assertEqual(plan["scale_scope"], "identity_all_facings_all_poses")

    def test_preserves_aspect_without_width_stretch(self):
        plan = head.make_head_plan([0, 0, 24, 12])
        self.assertEqual(plan["target_width_px"], 36)
        self.assertEqual(plan["head_scale"], 1.5)

    def test_neck_registered_all_directions_and_poses(self):
        plan = head.make_head_plan([10, 10, 26, 30])
        for direction in range(8):
            for pose in range(12):
                source = (40 + direction, 38 + pose)
                destination = (64 + pose, 70 - direction)
                self.assertEqual(head.place_head_point(source, source, destination, plan), destination)
                shifted = head.place_head_point((source[0] + 10, source[1] - 20), source, destination, plan)
                self.assertEqual(shifted, (destination[0] + 9, destination[1] - 18))

    def test_relative_scale_avoids_double_body_scale(self):
        plan = head.make_head_plan([0, 0, 16, 19])
        for scale in (0.8, 1.074, 1.211, 1.5):
            self.assertAlmostEqual(head.relative_head_scale(plan, scale) * scale * 19, 18)

    def test_body_budget_exact_and_volume_growth(self):
        previous = None
        for size, target in (("small", 58), ("middle", 63), ("large", 68)):
            budget = head.body_budget(size)
            self.assertAlmostEqual(sum(budget[k] for k in ("skull_px", "neck_px", "torso_px", "legs_px")), target)
            self.assertEqual(budget["skull_px"], 18)
            if previous:
                self.assertGreater(budget["torso_px"], previous["torso_px"])
                self.assertGreater(budget["legs_px"], previous["legs_px"])
            previous = budget

    def test_identity_exceptions_rebudget_not_actor_refit(self):
        for skull in (16, 20):
            budget = head.body_budget("middle", skull)
            self.assertAlmostEqual(sum(budget[k] for k in ("skull_px", "neck_px", "torso_px", "legs_px")), 63)

    def test_inputs_not_mutated_and_json_roundtrip(self):
        bounds = [4, 9, 30, 27]
        original = bounds.copy()
        plan = head.make_head_plan(bounds)
        saved = copy.deepcopy(plan)
        head.place_head_point([20, 20], [20, 28], [64, 70], plan)
        self.assertEqual(bounds, original)
        self.assertEqual(plan, saved)
        self.assertEqual(json.loads(json.dumps(plan)), plan)

    def test_invalid_annotations_rejected(self):
        for bounds in (None, [0, 1], [0, 0, 0, 8], [0, 0, 8, 0], [8, 0, 1, 8], [0, 0, float("inf"), 8], [0, 0, 8, True], [0, "1", 8, 9]):
            with self.subTest(bounds=bounds), self.assertRaises(ValueError):
                head.make_head_plan(bounds)

    def test_invalid_target_and_body_scale_rejected(self):
        for value in (0, 15.9, 20.1, True, None, float("nan")):
            with self.subTest(value=value), self.assertRaises(ValueError):
                head.make_head_plan([0, 0, 10, 18], value)
        plan = head.make_head_plan([0, 0, 10, 18])
        for value in (0, -1, True, "1", float("inf")):
            with self.subTest(value=value), self.assertRaises(ValueError):
                head.relative_head_scale(plan, value)

    def test_changed_scale_rejected(self):
        plan = head.make_head_plan([0, 0, 10, 18])
        plan["head_scale"] = 1.3
        with self.assertRaises(ValueError):
            head.place_head_point([0, 0], [0, 0], [0, 0], plan)

    def test_invalid_anchors_and_sizes_rejected(self):
        plan = head.make_head_plan([0, 0, 10, 18])
        for value in (None, [0], [0, 0, 0], [True, 0], [float("nan"), 0]):
            with self.subTest(value=value), self.assertRaises(ValueError):
                head.place_head_point(value, [0, 0], [0, 0], plan)
        for value in (None, [], 3, "giant"):
            with self.subTest(value=value), self.assertRaises(ValueError):
                head.body_budget(value)

    def test_current_annotated_cast_compatible(self):
        calibration_path = ROOT / "art_batches/character_motion_v1/head_calibration.json"
        if not calibration_path.exists():
            self.skipTest("independent reviewed head calibration has not landed")
        records = json.loads(calibration_path.read_text())["characters"]
        self.assertEqual(len(records), 30)
        for identity, record in records.items():
            with self.subTest(identity=identity):
                plan = head.make_head_plan(record["cranial_bounds"])
                self.assertAlmostEqual(plan["head_scale"], record["uniform_head_scale"])
                self.assertAlmostEqual(plan["head_scale"] * record["source_cranial_height_px"], 18)

    def test_contract_matches_helpers(self):
        contract = json.loads((ROOT / "art_batches/character_motion_v1/proportions.json").read_text())
        self.assertEqual(contract["head_contract"]["shared_anatomical_skull_height_px"], 18)
        for size, profile in contract["profiles"].items():
            budget = head.body_budget(size)
            self.assertEqual(profile["anatomical_height_px"], budget["height_px"])
            for field, part in (("skull_height_ratio", "skull_px"), ("neck_gap_ratio", "neck_px"), ("shoulder_to_hip_ratio", "torso_px"), ("hip_to_sole_ratio", "legs_px")):
                self.assertAlmostEqual(profile[field], budget[part] / budget["height_px"], places=8)
        self.assertEqual(len(contract["characters"]), 30)


if __name__ == "__main__":
    unittest.main()
