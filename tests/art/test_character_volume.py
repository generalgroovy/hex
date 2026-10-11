"""Offline anatomy invariants. No engine, imports, or production assets changed."""
import copy
import importlib.util
import json
import math
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("character_volume", ROOT / "art_batches/character_volume_v1/volume.py")
v = importlib.util.module_from_spec(spec)
spec.loader.exec_module(v)


class CharacterVolumeTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.source = json.loads((v.RIG / "rig-data.json").read_text())
        cls.fingerprint = json.dumps(cls.source, sort_keys=True)
        cls.data = v.adapt_data(cls.source)
        cls.module, render = v.load_renderer()
        cls.render = staticmethod(render)

    def test_source_not_mutated(self):
        self.assertEqual(json.dumps(self.source, sort_keys=True), self.fingerprint)

    def test_all_semantic_records_preserved(self):
        self.assertEqual(len(self.data["poses"]), 3312)
        for old, new in zip(self.source["poses"], self.data["poses"]):
            for key in ("body", "state", "aim", "travel", "phase", "direction"):
                self.assertEqual(old[key], new[key])

    def test_fixed_bone_lengths_every_pose(self):
        pairs = (("hip", "knee", "thigh"), ("knee", "ankle", "shin"),
                 ("ankle", "toe", "foot"), ("shoulder", "elbow", "humerus"),
                 ("elbow", "hand", "forearm"))
        for pose in self.data["poses"]:
            for side in ("l", "r"):
                for start, end, bone in pairs:
                    self.assertAlmostEqual(math.dist(pose["landmarks"][start+"_"+side], pose["landmarks"][end+"_"+side]), self.data["bone_lengths"][bone], places=6)

    def test_original_contact_and_lift_classification(self):
        for old, new in zip(self.source["poses"], self.data["poses"]):
            for key in ("ankle_l", "ankle_r", "toe_l", "toe_r"):
                self.assertAlmostEqual(new["landmarks"][key][2], old["landmarks"][key][2]*v.LEG_SCALE, places=8)

    def test_data_calibration_and_cell_contract(self):
        self.assertEqual(self.data["cell"], [96, 96])
        self.assertEqual(self.data["pivot"], [48, 84])
        self.assertEqual(self.data["rig_sha256"], self.source["rig_sha256"])
        self.assertEqual(self.data["source_bone_lengths"], self.source["bone_lengths"])

    def test_double_application_rejected(self):
        with self.assertRaises(ValueError): v.adapt_data(self.data)
        with self.assertRaises(ValueError): v.adapt_pose(self.data["poses"][0], self.source)

    def test_front_height_and_volume_ladder(self):
        widths, areas = [], []
        for body, profile in v.PROFILES.items():
            pose = next(p for p in self.data["poses"] if p["body"]==body and p["state"]=="grounded" and p["aim"]==0)
            image = self.render(pose, self.data)
            alpha=image.getchannel("A")
            box=alpha.getbbox()
            self.assertEqual(box[3]-box[1], profile["height"])
            widths.append(box[2]-box[0])
            areas.append(sum(value>0 for value in alpha.getdata()))
        self.assertGreater(widths[1]/widths[0], 1.15)
        self.assertGreater(widths[2]/widths[1], 1.15)
        self.assertGreater(areas[2]/areas[0], 1.6)

    def test_profile_volume_not_just_screen_width(self):
        for body in v.PROFILES:
            old=next(p for p in self.source["poses"] if p["body"]==body and p["state"]=="grounded" and p["aim"]==2)
            new=v.adapt_pose(old, self.source)
            old_bounds=self.module.render(old, self.source).getbbox()
            new_bounds=self.render(new, self.data).getbbox()
            self.assertGreater(new_bounds[2]-new_bounds[0], old_bounds[2]-old_bounds[0])

    def test_eight_yaw_depth_and_mesh_order(self):
        for pose in self.data["poses"]:
            self.assertEqual(len(pose["mesh_points"]), 24)
            self.assertEqual(len(pose["mesh_faces"]), 16)
            self.assertEqual([x["depth"] for x in pose["mesh_faces"]], sorted(x["depth"] for x in pose["mesh_faces"]))
            self.assertTrue(all(math.isfinite(n) for p in pose["points"].values() for n in p))

    def test_all_frames_render_binary_alpha_and_horizontal_bounds(self):
        for pose in self.data["poses"]:
            image=self.render(pose,self.data)
            self.assertEqual(image.size,(96,96))
            alpha=image.getchannel("A")
            self.assertLessEqual(set(alpha.getdata()),{0,255})
            box=alpha.getbbox()
            self.assertGreater(box[0],0)
            self.assertGreater(box[1],0)
            self.assertLess(box[2],96)
            self.assertLessEqual(box[3],84)


if __name__=="__main__": unittest.main()
