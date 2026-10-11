"""Layer conservation tests; fixture blocks are never game artwork."""
import copy
import importlib.util
from pathlib import Path
import unittest

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('motion_layers', ROOT / 'art_batches/character_motion_v1/layers.py')
layers = importlib.util.module_from_spec(spec)
spec.loader.exec_module(layers)


class LayerTests(unittest.TestCase):
    def fixture(self):
        frame = Image.new('RGBA', (96,96))
        draw = ImageDraw.Draw(frame)
        draw.rectangle((36,22,59,51), fill=(35,90,140,255))
        draw.rectangle((27,43,67,62), fill=(160,100,40,255))
        draw.rectangle((37,53,45,83), fill=(91,180,44,255))
        draw.rectangle((52,53,60,83), fill=(180,44,91,255))
        return frame, layers.default_spec(frame, 'S')

    def test_conservation_and_anatomical_layers(self):
        frame, spec = self.fixture()
        result = layers.partition_frame(frame, spec)
        self.assertTrue(result['receipt']['pixel_conservation'])
        self.assertGreater(result['receipt']['layer_pixels']['thigh_l'], 0)
        self.assertGreater(result['receipt']['layer_pixels']['thigh_r'], 0)
        self.assertGreater(result['receipt']['layer_pixels']['head'], 0)

    def test_editable_mask_owns_exact_pixels(self):
        frame, spec = self.fixture()
        spec['masks'] = {'appendage_back': [[[36,22],[40,22],[40,26],[36,26]]]}
        result = layers.partition_frame(frame, spec)
        self.assertEqual(result['receipt']['layer_pixels']['appendage_back'], 25)

    def test_overlap_rejected(self):
        frame, spec = self.fixture()
        polygon = [[[36,22],[40,22],[40,26],[36,26]]]
        spec['masks'] = {'head': polygon, 'torso': polygon}
        with self.assertRaisesRegex(ValueError, 'overlap'):
            layers.partition_frame(frame, spec)

    def test_source_tamper_rejected(self):
        frame, spec = self.fixture()
        frame.putpixel((40,30), (255,0,0,255))
        with self.assertRaisesRegex(ValueError, 'different source'):
            layers.partition_frame(frame, spec)

    def test_bad_anchor_and_mask_rejected(self):
        frame, spec = self.fixture()
        spec['anchors']['neck'] = [float('nan'),10]
        with self.assertRaisesRegex(ValueError, 'anchor'):
            layers.partition_frame(frame, spec)
        spec = layers.default_spec(frame, 'S')
        spec['masks'] = {'head': [[[1,1],[2,2],[3,3]]]}
        with self.assertRaisesRegex(ValueError, 'Degenerate'):
            layers.partition_frame(frame, spec)

    def test_bad_depth_and_bone_rejected(self):
        frame, spec = self.fixture()
        spec['order'].append('head')
        with self.assertRaisesRegex(ValueError, 'depth'):
            layers.partition_frame(frame, spec)
        spec = layers.default_spec(frame, 'S')
        spec['anchors']['neck'] = spec['anchors']['head']
        with self.assertRaisesRegex(ValueError, 'Degenerate'):
            layers.partition_frame(frame, spec)

    def test_merging_is_nonmutating(self):
        _, spec = self.fixture()
        old = copy.deepcopy(spec)
        result = layers.merge_override(spec, {'anchors': {'head': [48,30]}})
        self.assertEqual(spec, old)
        self.assertEqual(result['anchors']['head'], [48,30])

    def test_all_current_cast_sources_conserve(self):
        import json
        manifest = json.loads(layers.DEFAULT_MANIFEST.read_text())
        self.assertEqual(len(manifest['characters']),30)
        for character in manifest['characters']:
            result = layers.load_character(character['id'])
            self.assertEqual(list(result['directions']), list(layers.DIRECTIONS))
            for view in result['directions'].values():
                self.assertTrue(view['receipt']['pixel_conservation'])
                self.assertTrue(view['receipt']['review_required'])


if __name__ == '__main__':
    unittest.main()
