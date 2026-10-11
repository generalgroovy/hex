"""Exact authored-key source registration; no engine or production writes."""
import copy
import importlib.util
import json
import math
from pathlib import Path
import tempfile
import unittest
from unittest import mock

from PIL import Image, ImageDraw

ROOT=Path(__file__).resolve().parents[2]
spec=importlib.util.spec_from_file_location("authored_action_keys",ROOT/"art_batches/character_motion_v1/action_keys.py")
keys=importlib.util.module_from_spec(spec)
spec.loader.exec_module(keys)


class AuthoredKeyTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.recipes={}
        cls.banks={}
        for identity in ("s_wayne","oh_tipi","red_baron"):
            recipe=json.loads((keys.HERE/"action-recipes"/(identity+".json")).read_text())
            cls.recipes[identity]=recipe
            cls.banks[identity]=keys.assemble(recipe,ROOT/recipe["source_png"])

    def test_all_three_have64_distinct_authored_keys(self):
        for cells,records in self.banks.values():
            self.assertEqual(len(cells),64)
            self.assertEqual(len(records),64)
            self.assertEqual(len({keys.pixel_sha(c) for c in cells.values()}),64)
            self.assertEqual(set(cells),{row+"/"+direction for row in keys.ROWS for direction in keys.DIRECTIONS})

    def test_all_frames_same_scale_per_character(self):
        for identity,(_,records) in self.banks.items():
            recipe=self.recipes[identity]
            self.assertEqual({r["uniform_scale"] for r in records},{recipe["uniform_scale"]})
            expected=recipe["head_measurement"]["reference"]*recipe["target_anatomical_height"]/recipe["reference_anatomical_height"]/recipe["head_measurement"]["source"]
            self.assertAlmostEqual(recipe["uniform_scale"],expected,places=9)

    def test_key_heights_are_not_fitted_back_to_standing(self):
        for _,records in self.banks.values():
            heights={r["bounds"][3]-r["bounds"][1] for r in records}
            self.assertGreater(len(heights),4)

    def test_binary_alpha_pivot_and_canvas(self):
        for cells,_ in self.banks.values():
            for cell in cells.values():
                self.assertEqual(cell.size,(128,128))
                alpha=cell.getchannel("A")
                self.assertEqual(set(alpha.getdata()),{0,255})
                box=alpha.getbbox()
                self.assertGreater(box[0],0)
                self.assertGreater(box[1],0)
                self.assertLess(box[2],128)
                self.assertEqual(box[3],104)

    def test_bad_source_hash_rejected(self):
        recipe=copy.deepcopy(self.recipes["s_wayne"])
        recipe["source_sha256"]="0"*64
        with self.assertRaisesRegex(ValueError,"source hash mismatch"):
            keys.assemble(recipe,ROOT/recipe["source_png"])

    def test_outside_source_crop_rejected(self):
        recipe=copy.deepcopy(self.recipes["s_wayne"])
        recipe["frames"]["slide_entry/S"]["rect"][0]=-1
        with self.assertRaisesRegex(ValueError,"Out-of-source crop"):
            keys.assemble(recipe,ROOT/recipe["source_png"])

    def test_overlapping_crop_without_masks_rejected(self):
        recipe=copy.deepcopy(self.recipes["s_wayne"])
        recipe["frames"]["slide_entry/SE"]=copy.deepcopy(recipe["frames"]["slide_entry/S"])
        with self.assertRaisesRegex(ValueError,"Overlapping authored key crops"):
            keys.assemble(recipe,ROOT/recipe["source_png"])

    def test_missing_frame_rejected(self):
        recipe=copy.deepcopy(self.recipes["s_wayne"])
        del recipe["frames"]["land/S"]
        with self.assertRaisesRegex(ValueError,"all64"):
            keys.assemble(recipe,ROOT/recipe["source_png"])

    def test_oh_tipi_explicit_component_exception(self):
        recipe=self.recipes["oh_tipi"]
        exceptions=[g for g in recipe["gutter_measurements"] if "registration_exception" in g]
        self.assertTrue(exceptions)
        self.assertTrue(any("source_owned_runs" in f for f in recipe["frames"].values()))
        self.assertTrue(all("disconnected_opaque_components" in e["registration_exception"] for e in exceptions))

    def test_component_ownership_cannot_drop_source_pixels(self):
        recipe=copy.deepcopy(self.recipes["oh_tipi"])
        entry=next(f for f in recipe["frames"].values() if "source_owned_runs" in f)
        entry["source_owned_runs"].pop(len(entry["source_owned_runs"])//2)
        with self.assertRaisesRegex(ValueError,"conservation"):
            keys.assemble(recipe,ROOT/recipe["source_png"])

    def test_manifest_and_saved_atlases_match_rebuilt(self):
        from PIL import Image
        folder=keys.HERE/"output/authored-keys-v1"
        manifest=json.loads((folder/"manifest.json").read_text())
        self.assertFalse(manifest["production_ready"])
        self.assertFalse(manifest["human_approved"])
        self.assertEqual(len(manifest["characters"]),3)
        for character in manifest["characters"]:
            path=folder/character["atlas"]
            self.assertEqual(keys.sha(path),character["atlas_sha256"])
            self.assertFalse(character["complete_cycles"])
            with Image.open(path) as atlas:
                self.assertEqual(atlas.size,(1024,1024))
                cells,_=self.banks[character["id"]]
                for record in character["frames"]:
                    x,y,w,h=record["rect"]
                    cell=atlas.crop((x,y,x+w,y+h))
                    self.assertEqual(keys.pixel_sha(cell),record["rgba_sha256"])
                    self.assertEqual(cell.tobytes(),cells[record["key"]].tobytes())


class ExplicitHeadMeasurementTests(unittest.TestCase):
    @staticmethod
    def fixture(root):
        catalog = root/"catalog.json"
        catalog.write_text(json.dumps({"characters":[{"id":"steezo"}]}),encoding="utf-8")
        source = root/"fixture.png"
        image = Image.new("RGBA",(320,320))
        draw = ImageDraw.Draw(image)
        for row in range(8):
            for col in range(8):
                x,y=col*40+8,row*40+8
                draw.rectangle((x,y,x+19,y+25),fill=(40+row*20,50+col*20,120,255))
        image.save(source)
        return catalog,source

    def test_explicit_18px_cranial_target_preserves_authored_ratio(self):
        normalized,scale=keys.validate_measurement({"source_head_height":36,"source_head_width":30,"frame":"jump_rise/S"})
        self.assertEqual(scale,.5)
        self.assertEqual(normalized["target_head_height"],18)
        self.assertEqual(normalized["predicted_target_head_width"],15)
        self.assertEqual(normalized["source_head_width"]/normalized["source_head_height"],normalized["predicted_target_head_width"]/normalized["target_head_height"])

    def test_invalid_measurements_rejected(self):
        for measure in ({}, {"source_head_height":0}, {"source_head_height":-10},
                        {"source_head_height":True}, {"source_head_height":math.nan},
                        {"source_head_height":math.inf}, {"source_head_height":4},
                        {"source_head_height":20,"source_head_width":False},
                        {"source_head_height":20,"source_head_width":-1},
                        {"source_head_height":20,"source_head_width":math.nan},
                        {"source_head_height":20,"target_head_height":40},
                        {"source_head_height":20,"target_head_height":False},
                        {"source_head_height":20,"frame":"not_a_frame"},
                        {"source_head_height":20,"whole_pose_height":100},
                        {"source_head_height":20,"notes":""}):
            with self.subTest(measure=measure),self.assertRaises(ValueError):
                keys.validate_measurement(measure)
        with self.assertRaises(ValueError): keys.validate_measurement({"source_head_height":100},(80,80))
        with self.assertRaises(ValueError): keys.validate_measurement({"source_head_height":20,"source_head_width":90},(80,80))

    def test_new_id_requires_explicit_measurement(self):
        with self.assertRaisesRegex(ValueError,"explicit cranial"):
            keys.register_source("steezo","not_opened.png")
        with self.assertRaisesRegex(ValueError,"Unknown current character"):
            keys.register_source("imaginary_new_character","not_opened.png",{"source_head_height":30})
        with self.assertRaisesRegex(ValueError,"Unknown current character"):
            keys.build_key_atlas("../escape","not_opened.png","not_opened",{"source_head_height":30})

    def test_all_current_cast_ids_are_available_not_just_pilots(self):
        ids=keys.known_characters()
        self.assertEqual(len(ids),30)
        self.assertIn("steezo",ids)
        self.assertIn("h_le_ne",ids)
        self.assertIn("fimu_yashiha",ids)

    def test_register_and_assemble_new_identity_one_sheet_scale(self):
        with tempfile.TemporaryDirectory() as temp:
            root=Path(temp)
            catalog,source=self.fixture(root)
            with mock.patch.object(keys,"REPO",root),mock.patch.object(keys,"CATALOG",catalog):
                recipe=keys.register_source("steezo",source,{"source_head_height":12,"source_head_width":10,"notes":"Synthetic explicit cranial landmarks for fixture"})
                cells,records=keys.assemble(recipe,source)
            self.assertEqual(recipe["uniform_scale"],1.5)
            self.assertTrue(recipe["source_proportions_preserved"])
            self.assertNotIn("reference_anatomical_height",recipe)
            self.assertEqual(recipe["catalog_sha256"],keys.sha(catalog))
            self.assertEqual(len(cells),64)
            self.assertEqual({r["uniform_scale"] for r in records},{1.5})
            self.assertEqual(recipe["head_measurement"]["predicted_target_head_width"],15)

    def test_measurement_cannot_exceed_declared_source_frame(self):
        with tempfile.TemporaryDirectory() as temp:
            root=Path(temp)
            catalog,source=self.fixture(root)
            with mock.patch.object(keys,"REPO",root),mock.patch.object(keys,"CATALOG",catalog):
                with self.assertRaisesRegex(ValueError,"exceeds declared measurement frame"):
                    keys.register_source("steezo",source,{"source_head_height":80})
                with self.assertRaisesRegex(ValueError,"exceeds declared measurement frame"):
                    keys.register_source("steezo",source,{"source_head_height":12,"source_head_width":80})

    def test_head_scale_not_inferred_from_whole_pose_height(self):
        with tempfile.TemporaryDirectory() as temp:
            root=Path(temp)
            catalog,source=self.fixture(root)
            with mock.patch.object(keys,"REPO",root),mock.patch.object(keys,"CATALOG",catalog):
                first=keys.register_source("steezo",source,{"source_head_height":24})
                with Image.open(source) as opened: image=opened.copy()
                # Change complete body height in every cell; explicit cranium
                # measurement remains the sole scale authority.
                for row in range(8):
                    for col in range(8):
                        image.paste((0,0,0,0),(col*40,row*40+28,(col+1)*40,row*40+34))
                image.save(source)
                second=keys.register_source("steezo",source,{"source_head_height":24})
            self.assertEqual(first["uniform_scale"],second["uniform_scale"])
            self.assertNotEqual(first["frames"]["slide_entry/S"]["source_alpha_bounds"],second["frames"]["slide_entry/S"]["source_alpha_bounds"])


if __name__=="__main__": unittest.main()
