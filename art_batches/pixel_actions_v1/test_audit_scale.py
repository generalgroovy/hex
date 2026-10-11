"""Isolated diagnostics tests: no Godot, builder, sprite writes, or publication."""
import importlib.util
import math
from pathlib import Path
import unittest

from PIL import Image

spec = importlib.util.spec_from_file_location("audit_scale", Path(__file__).with_name("audit_scale.py"))
audit = importlib.util.module_from_spec(spec)
spec.loader.exec_module(audit)


def measurement(name="head height", idle=24, posed=20):
    return {"name": name, "definition": "Reviewer-selected crown to chin, excluding collar",
            "direction": "S", "action": "fall", "idle": {"pixels": idle, "uncertainty": 0},
            "posed": {"pixels": posed, "uncertainty": 0}}


def record(*measurements):
    return {"ground_sha256": "ground", "action_sha256": "action", "reviewer": "test-reviewer",
            "measurements": list(measurements)}


class ScaleAuditTests(unittest.TestCase):
    def test_equal_silhouettes_do_not_approve_anatomy(self):
        atlas = Image.new("RGBA", (1024, 512))
        for column in range(8):
            atlas.paste((50, 60, 70, 255), (column * 128 + 45, 46, column * 128 + 80, 104))
        self.assertEqual({cell["height"] for cell in audit.cell_bounds(atlas, 0)}, {58})
        result = audit.compare_landmarks(record(measurement()), "ground", "action")
        self.assertEqual(result["median_ratio"], 1.2)
        self.assertEqual(result["uniform_scale_feasibility"], "NOT_ESTABLISHED_SINGLE_SPAN")
        self.assertFalse(result["automatic_correction"])

    def test_conflicting_head_and_torso_ratios_do_not_become_one_scale(self):
        result = audit.compare_landmarks(record(measurement(), measurement("torso width", 30, 30)), "ground", "action")
        self.assertIsNone(result["common_ratio_interval"])
        self.assertEqual(result["uniform_scale_feasibility"], "CONFLICTING_ANATOMICAL_SPANS")

    def test_uncertainty_is_propagated_without_native_acceptance(self):
        mark = measurement()
        mark["idle"]["uncertainty"] = 1
        mark["posed"]["uncertainty"] = 1
        result = audit.compare_landmarks(record(mark, measurement("head width", 23, 20)), "ground", "action")
        self.assertEqual(result["common_ratio_interval"], [1.15, 1.15])
        self.assertEqual(result["native_motion_acceptance"], "NOT_RUN")

    def test_stale_landmarks_rejected(self):
        with self.assertRaisesRegex(ValueError, "stale"):
            audit.compare_landmarks(record(measurement()), "changed-ground", "action")

    def test_unidentified_landmarks_rejected(self):
        for key in ["name", "definition", "direction", "action"]:
            mark = measurement()
            mark[key] = ""
            with self.subTest(key=key), self.assertRaises(ValueError):
                audit.compare_landmarks(record(mark), "ground", "action")

    def test_span_rejects_boolean_nonfinite_negative_and_invalid_uncertainty(self):
        for value in [True, 0, -1, math.inf, math.nan, "24"]:
            with self.subTest(value=value), self.assertRaises(ValueError):
                audit.measured_span({"pixels": value, "uncertainty": 0})
        for value in [True, -1, 20, math.inf, math.nan]:
            with self.subTest(value=value), self.assertRaises(ValueError):
                audit.measured_span({"pixels": 20, "uncertainty": value})

    def test_hidden_rgb_is_not_an_occupied_cell(self):
        with self.assertRaisesRegex(ValueError, "Blank"):
            audit.cell_bounds(Image.new("RGBA", (1024, 512), (100, 100, 100, 0)), 0)


if __name__ == "__main__":
    unittest.main()
