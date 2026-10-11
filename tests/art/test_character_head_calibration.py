"""Candidate head metadata integrity; no visual acceptance inference."""
import hashlib
import json
import math
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
HEADS = ROOT / 'art_batches/character_motion_v1/head_calibration.json'
DIRECTIONS = ('S','SE','E','NE','N','NW','W','SW')


class HeadCalibrationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.data = json.loads(HEADS.read_text(encoding='utf-8'))
        cls.source = ROOT / cls.data['source_manifest']
        cls.manifest = json.loads(cls.source.read_text(encoding='utf-8'))

    def test_exact_current_cast_coverage(self):
        self.assertEqual(self.data['schema_version'],1)
        self.assertEqual(len(self.data['characters']),30)
        self.assertEqual(set(self.data['characters']),{c['id'] for c in self.manifest['characters']})
        self.assertEqual(self.data['source_manifest_sha256'], hashlib.sha256(self.source.read_bytes()).hexdigest())

    def test_hash_locked_identity_sources(self):
        for source in self.manifest['characters']:
            row = self.data['characters'][source['id']]
            self.assertEqual(row['source_atlas'],source['atlas'])
            self.assertEqual(row['source_atlas_sha256'],source['atlas_sha256'])
            self.assertEqual(row['size'],source['body'])
            self.assertEqual(row['race'],source['race'])

    def test_common_head_target_is_independent_of_body_size(self):
        self.assertEqual(self.data['target_cranial_height_px'],18)
        for row in self.data['characters'].values():
            left,top,right,bottom = row['cranial_bounds']
            self.assertTrue(all(isinstance(v,(int,float)) and math.isfinite(v) for v in (left,top,right,bottom)))
            self.assertTrue(0 <= left < right <=96 and 0 <= top < bottom <=96)
            self.assertEqual(bottom-top,row['source_cranial_height_px'])
            self.assertEqual(right-left,row['source_cranial_width_px'])
            self.assertAlmostEqual(row['uniform_head_scale']*(bottom-top),18)
            self.assertTrue(.5 < row['uniform_head_scale'] <2)
            self.assertNotIn('body_scale',row)

    def test_all_eight_anchor_bindings_are_finite_and_nonzero(self):
        for row in self.data['characters'].values():
            self.assertEqual(tuple(row['facings']),DIRECTIONS)
            for facing in row['facings'].values():
                for key in ('head_anchor','neck_anchor'):
                    self.assertEqual(len(facing[key]),2)
                    self.assertTrue(all(isinstance(v,(int,float)) and math.isfinite(v) and 0 <= v <=96 for v in facing[key]))
                self.assertGreater(math.dist(facing['head_anchor'],facing['neck_anchor']),.1)
                self.assertTrue(1 <= facing['recommended_head_mask_bottom_y'] <=95)

    def test_review_limitations_cannot_be_silently_accepted(self):
        self.assertEqual(self.data['status'],'candidate_not_visual_acceptance')
        pilot_count = 0
        for row in self.data['characters'].values():
            self.assertTrue(row['head_mask_review_required'])
            self.assertTrue(row['confidence'])
            self.assertIn('complete_head_mask_review',row['holds'])
            pilot_count += row['directional_anchor_evidence'] == 'manual_pilot_candidate'
            self.assertNotIn('human_approved',row)
        self.assertEqual(pilot_count,3)
        self.assertIn('candidate',self.data['policy']['mask_prerequisite'])


if __name__ == '__main__':
    unittest.main()
