"""Offline semantic/bone tests; not a claim of native or human visual approval."""
import importlib.util
import math
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("character_motion_poses", ROOT / "art_batches/character_motion_v1/poses.py")
p = importlib.util.module_from_spec(spec)
spec.loader.exec_module(p)


class CharacterMotionPoseTests(unittest.TestCase):
    def test_all_actions_sizes_directions_finite(self):
        for body in p.BODIES:
            for action in p.ACTIONS:
                for aim in range(8):
                    pose = p.pose(body, action, aim, (aim+3)%8, .375)
                    self.assertTrue(all(math.isfinite(x) for point in pose["points"].values() for x in point))
                    self.assertEqual(pose["world_lift"], 0)
                    self.assertEqual(pose["visual_acceptance"], "pending")
                    self.assertEqual(pose["ground_anchor"], [48, 84])

    def test_fixed_bones_for_all_actions(self):
        lengths = {"thigh": .2*.8, "shin": .23*.8, "foot": .08*.8, "humerus": .17*.82, "forearm": .15*.82}
        for body in p.BODIES:
            for action in p.ACTIONS:
                for phase in (0, .15, .5, .85, 1):
                    pose = p.pose(body, action, 3, 6, phase)
                    chest = p.mul(p.add(pose["landmarks"]["shoulder_l"], pose["landmarks"]["shoulder_r"]), .5)
                    self.assertAlmostEqual(math.dist(chest, pose["landmarks"]["pelvis"]), .3, places=6)
                    for side in ("l", "r"):
                        for a, b, bone in (("hip", "knee", "thigh"), ("knee", "ankle", "shin"), ("ankle", "toe", "foot"), ("shoulder", "elbow", "humerus"), ("elbow", "hand", "forearm")):
                            self.assertAlmostEqual(math.dist(pose["landmarks"][a+"_"+side], pose["landmarks"][b+"_"+side]), lengths[bone], places=6)

    def test_independent_aim_and_travel_matrix(self):
        for action in ("walk", "sprint"):
            for aim in range(8):
                for travel in range(8):
                    result = p.pose("middle", action, aim, travel, .25)
                    self.assertEqual((result["aim"], result["travel"]), (aim, travel))

    def test_slide_follows_travel(self):
        result = p.pose("small", "slide", 0, 3, .5)
        self.assertEqual(result["aim"], 3)
        self.assertEqual(result["requested_aim"], 0)

    def test_gait_loop_seam(self):
        for action in ("walk", "sprint"):
            a, b = p.pose("middle", action, 0, 1, 0), p.pose("middle", action, 0, 1, 1)
            self.assertEqual(a["points"], b["points"])

    def test_alternating_leg_motion_is_not_whole_body_translation(self):
        a = p.pose("middle", "walk", 0, 0, .25)
        b = p.pose("middle", "walk", 0, 0, .75)
        self.assertNotEqual(a["landmarks"]["ankle_l"], b["landmarks"]["ankle_l"])
        self.assertNotEqual(p.sub(a["points"]["ankle_l"], b["points"]["ankle_l"]), p.sub(a["points"]["ankle_r"], b["points"]["ankle_r"]))

    def test_return_values_are_isolated(self):
        first = p.rest("small")
        first["points"]["head"][0] = -999
        self.assertNotEqual(p.rest("small")["points"]["head"][0], -999)

    def test_invalid_inputs_fail(self):
        for args in (("tiny", "walk", 0, 0, 0), ("small", "punch", 0, 0, 0), ("small", "walk", -1, 0, 0), ("small", "walk", 0, 8, 0), ("small", "walk", 0, 0, math.nan), ("small", "walk", 0, 0, 1.01)):
            with self.assertRaises(ValueError): p.pose(*args)

    def test_depth_chain_order_and_display_calibration(self):
        for body in p.BODIES:
            result = p.pose(body, "cast", 2, 0, .4)
            self.assertTrue(result["display_space"])
            self.assertEqual(result["display_height"], p.DISPLAY_HEIGHTS[body])
            self.assertEqual([c["depth"] for c in result["chains"]], sorted(c["depth"] for c in result["chains"]))


if __name__ == "__main__": unittest.main()
