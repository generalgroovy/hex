"""S.Wayne authored correction integrity; no engine or production mutation."""
import copy
import importlib.util
from pathlib import Path
import tempfile
import json
import unittest

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
def module(name):
    spec = importlib.util.spec_from_file_location(name, ROOT / f'art_batches/character_motion_v1/{name}.py')
    result = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(result)
    return result

layers, corrections = module('layers'), module('corrections')


class CorrectionTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.character = layers.load_character('s_wayne')

    def test_32_authored_components(self):
        recipe, parts = corrections.load_recipe(str(corrections.DEFAULT_RECIPE))
        self.assertEqual(len(parts),32)
        self.assertEqual(recipe['source_size'],[1448,1086])

    def test_all_views_preserve_identity_and_original_pixels(self):
        for direction, original in self.character['directions'].items():
            result = corrections.apply_corrections(original,direction)
            self.assertEqual(len(result['receipt']['corrective_art']['layers']),8)
            self.assertEqual(len(result['correction_underlays']),8)
            for name, source in original['layers'].items():
                dest = result['layers'][name]
                self.assertEqual(source.tobytes(),dest.tobytes())
                for y in range(96):
                    for x in range(96):
                        pixel = source.getpixel((x,y))
                        if pixel[3]: self.assertEqual(dest.getpixel((x,y)),pixel)
            for name in ('head','hand_l','hand_r','foot_l','foot_r'):
                self.assertEqual(result['layers'][name].tobytes(), original['layers'][name].tobytes())
            self.assertNotIn('corrective_art', original['receipt'])
            before, after = Image.new('RGBA',(96,96)), Image.new('RGBA',(96,96))
            for underlay in result['correction_underlays'].values():
                after.alpha_composite(underlay)
            for name in original['order']:
                before.alpha_composite(original['layers'][name])
                after.alpha_composite(result['layers'][name])
            self.assertEqual(before.tobytes(),after.tobytes())
            for underlay in result['correction_underlays'].values():
                for y in range(96):
                    for x in range(96):
                        if underlay.getpixel((x,y))[3]:
                            self.assertEqual(before.getpixel((x,y))[3],255)

    def test_wrong_character_or_facing_fails_closed(self):
        original = self.character['directions']['S']
        with self.assertRaisesRegex(ValueError,'No authored'):
            corrections.apply_corrections(original,'S','oh_tipi')
        with self.assertRaisesRegex(ValueError,'Facing'):
            corrections.apply_corrections(original,'N')

    def test_alignment_rejects_zero_bone_and_clipping(self):
        source = Image.new('RGBA',(50,50),(12,34,56,255))
        with self.assertRaisesRegex(ValueError,'Degenerate'):
            corrections.align_bone(source,[0,0],[0,0],[10,10],[20,20])
        with self.assertRaisesRegex(ValueError,'exceeds'):
            corrections.align_bone(source,[0,0],[20,20],[90,90],[95,95])

    def test_source_hash_tamper_fails(self):
        recipe = json.loads(corrections.DEFAULT_RECIPE.read_text())
        recipe['source_sha256'] = '0'*64
        # A sibling temporary recipe retains the intended contained source path.
        with tempfile.NamedTemporaryFile('w',suffix='.json',dir=corrections.HERE,delete=False) as out:
            json.dump(recipe,out)
            path = Path(out.name)
        try:
            with self.assertRaisesRegex(ValueError,'hash mismatch'):
                corrections.load_recipe(str(path))
        finally:
            path.unlink()


if __name__ == '__main__':
    unittest.main()
