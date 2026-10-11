import importlib.util
import json
from pathlib import Path
import sys
import unittest
from PIL import Image

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'art_batches/character_motion_v1'))
import shared_heads as h
import layers
sys.path.pop(0)


class SharedHeadAssemblyTests(unittest.TestCase):
    def test_shared_sampling_does_not_open_neck_seams(self):
        head=Image.new('RGBA',(96,96)); body=Image.new('RGBA',(96,96))
        head.paste((10,20,30,255),(35,25,61,44))
        body.paste((50,60,70,255),(35,44,61,84))
        result=h.connected_registration({'head':head,'torso':body},18/19,1.25,48,44,[48,34],17)
        merged=Image.new('RGBA',(128,128))
        for im in result.values(): merged.alpha_composite(im)
        for y in range(40,103):
            self.assertEqual(merged.getpixel((64,y))[3],255)
        self.assertLessEqual(set(merged.getdata()),{(0,0,0,0),(10,20,30,255),(50,60,70,255)})
    def test_all_thirty_identity_scales_and_no_clipping(self):
        catalog=json.loads(layers.DEFAULT_MANIFEST.read_text())
        for character in catalog['characters']:
            with self.subTest(character=character['id']):
                original=layers.load_character(character['id'])
                before=original['directions']['S']['layers']['head'].tobytes()
                normalized=h.apply(original)
                record=normalized['shared_head']
                self.assertAlmostEqual(record['source_head_height']*record['head_scale'],18)
                self.assertEqual(before,original['directions']['S']['layers']['head'].tobytes())
                for view in normalized['directions'].values():
                    self.assertTrue(view['receipt']['shared_head']['pre_scale_conservation'])
                    for im in view['layers'].values():
                        self.assertEqual(im.size,(128,128))
                        self.assertLessEqual(set(im.getchannel('A').getdata()),{0,255})
    def test_wrong_source_hash_rejected(self):
        source=layers.load_character('s_wayne')
        source['character']['atlas_sha256']='bad'
        with self.assertRaises(ValueError): h.apply(source)
    def test_layer_transform_rejects_clipping(self):
        im=Image.new('RGBA',(96,96))
        im.putpixel((0,0),(255,255,255,255))
        with self.assertRaises(ValueError):h.transform_layer(im,2,[48,84],[48,84])


if __name__=='__main__':unittest.main()
