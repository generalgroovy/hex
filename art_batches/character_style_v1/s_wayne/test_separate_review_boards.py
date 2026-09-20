"""Pure technical regressions; synthetic blocks are test data, not character art."""
import unittest
from collections import Counter
import numpy as np
from PIL import Image, ImageDraw
from separate_review_boards import separation, inside

def fixture(alpha=False):
    data = np.zeros((320, 512, 4), dtype=np.uint8)
    if not alpha:
        for y in range(320):
            for x in range(512):
                value = 190 if (x // 8 + y // 8) % 2 else 244
                data[y, x] = (value, value, value, 255)
    image = Image.fromarray(data)
    draw = ImageDraw.Draw(image)
    draw.rectangle((60, 65, 180, 270), fill=(42, 28, 52, 255))
    draw.rectangle((300, 60, 425, 275), fill=(105, 52, 25, 255))
    draw.rectangle((90, 110, 112, 130), fill=(242, 242, 242, 255))
    draw.point((88, 58), fill=(25, 22, 30, 255))
    return image

class TechnicalExtractionTests(unittest.TestCase):
    def test_checker_and_subject_rgba_conservation(self):
        original = fixture()
        before = original.tobytes()
        packed, mask, records, alpha, kept = separation(original, 2, 2)
        self.assertEqual(original.tobytes(), before)
        self.assertEqual(alpha["minimum"], 255)
        self.assertEqual(len(records), 2)
        self.assertEqual(mask.getpixel((0, 0)), 255)
        self.assertEqual(mask.getpixel((95, 115)), 0, "Enclosed ivory highlight must survive")
        self.assertEqual(mask.getpixel((88, 58)), 0, "Detached dark edge pixel must survive")
        source = np.array(original)
        selected = source[np.array(mask) == 0]
        output = np.array(packed)
        actual = output[output[:, :, 3] != 0]
        self.assertEqual(Counter(map(tuple, selected)), Counter(map(tuple, actual)))
        self.assertEqual(kept, len(actual))
        for record in records:
            x, y, w, h = record["rect"]
            cell = np.array(packed.crop((x, y, x+w, y+h)))[:, :, 3]
            self.assertFalse(cell[0].any() or cell[-1].any() or cell[:, 0].any() or cell[:, -1].any())

    def test_actual_alpha_is_not_rekeyed(self):
        original = fixture(True)
        packed, mask, records, alpha, kept = separation(original, 2, 2)
        self.assertEqual(alpha["minimum"], 0)
        self.assertIsNone(mask.getbbox())
        self.assertEqual(kept, np.count_nonzero(np.array(original)[:, :, 3]))
        self.assertEqual(len(records), 2)
        self.assertEqual(packed.mode, "RGBA")

    def test_clipped_source_rejected(self):
        image = fixture()
        ImageDraw.Draw(image).line((0, 50, 60, 80), fill=(20, 10, 10, 255), width=3)
        with self.assertRaisesRegex(ValueError, "perimeter"):
            separation(image, 2, 2)

    def test_ambiguous_third_body_rejected(self):
        image = fixture()
        ImageDraw.Draw(image).rectangle((205, 75, 270, 260), fill=(30, 20, 50, 255))
        with self.assertRaisesRegex(ValueError, "substantial component"):
            separation(image, 2, 2)

    def test_scoped_paths(self):
        self.assertTrue(str(inside("prepared-v5")).endswith("prepared-v5"))
        with self.assertRaises(ValueError):
            inside("../../escape.png")

if __name__ == "__main__":
    unittest.main(verbosity=2)

