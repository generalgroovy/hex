#!/usr/bin/env python3
"""Offline pixel/data checks only. No Godot or visual/human acceptance."""
from __future__ import annotations
import hashlib,json,re,unittest
from pathlib import Path
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
LAYOUT=json.loads((ROOT/'definitions/atlas-layout.json').read_text())
PALETTE=json.loads((ROOT/'definitions/palette.json').read_text())
DEFS=json.loads((ROOT/'definitions/materials.proposed.json').read_text())
INPUT=json.loads((ROOT/'evidence/input-manifest.json').read_text())
RECORDS={r['path']:r for r in INPUT['records']}

def rgba(im):return im.convert('RGBA')
def frames(a):
 im=rgba(Image.open(ROOT/a['path']))
 for row,phase in enumerate(a['rows']):
  for f in range(8):yield phase,f,im.crop((f*64,row*80,f*64+64,row*80+80))
def inside(x,y):
 p=[(32,3.05),(64,21.525),(64,58.475),(32,76.95),(0,58.475),(0,21.525)]
 return all((p[(i+1)%6][0]-p[i][0])*(y-p[i][1])-(p[(i+1)%6][1]-p[i][1])*(x-p[i][0])>=-1e-6 for i in range(6))

class Assets(unittest.TestCase):
 def test_six_atlases_176_frames(self):
  self.assertEqual(len(LAYOUT['atlases']),6);self.assertEqual(sum(len(a['rows'])*8 for a in LAYOUT['atlases']),176)
 def test_dimensions_and_straight_rgba(self):
  for a in LAYOUT['atlases']:
   with self.subTest(path=a['path']):
    im=Image.open(ROOT/a['path']);im.load();self.assertEqual(im.mode,'RGBA');self.assertEqual(list(im.size),a['dimensions']);self.assertEqual(im.size,(512,80*len(a['rows'])))
 def test_two_pixel_clusters(self):
  for a in LAYOUT['atlases']:
   for phase,f,im in frames(a):
    px=im.load()
    for y in range(0,80,2):
     for x in range(0,64,2):self.assertEqual({px[x,y],px[x+1,y],px[x,y+1],px[x+1,y+1]}, {px[x,y]})
 def test_visible_motif_pixels_inside_whole_hex(self):
  for a in LAYOUT['atlases']:
   for phase,f,im in frames(a):
    px=im.load()
    for y in range(80):
     for x in range(64):
      if px[x,y][3]:self.assertTrue(inside(x+.5,y+.5),(a['path'],phase,f,x,y))
 def test_transparent_rgb_is_zero(self):
  for a in LAYOUT['atlases']:
   raw=Image.open(ROOT/a['path']).tobytes()
   self.assertTrue(all(raw[i:i+3]==b'\0\0\0' for i in range(0,len(raw),4) if raw[i+3]==0))
 def test_last_expiry_frame_is_empty(self):
  for a in LAYOUT['atlases']:
   for phase,f,im in frames(a):
    if phase in ['decaying','cooling'] and f==7:self.assertIsNone(im.getchannel('A').getbbox())
 def test_normal_active_has_authored_motion(self):
  for a in LAYOUT['atlases']:
   if a['mode']=='normal':
    unique={im.tobytes() for phase,f,im in frames(a) if phase=='active'};self.assertGreaterEqual(len(unique),4)
 def test_reduced_active_holds_static_pose(self):
  for a in LAYOUT['atlases']:
   if a['mode']=='reduced':
    for row in [p for p in a['rows'] if p in ['active','hot','cool']]:self.assertEqual(len({im.tobytes() for p,f,im in frames(a) if p==row}),1)
 def test_steam_harmless_rows_have_no_warm_danger_ink(self):
  warm={tuple(bytes.fromhex(c[1:])) for c in ['#ff8f4f','#ff7740','#e8a065','#f3a061','#d8895b']}
  for a in LAYOUT['atlases']:
   if a['material']=='steam':
    for phase,f,im in frames(a):
     if phase in ['forming','decaying']:
      raw=im.tobytes();self.assertFalse(any(tuple(raw[i:i+3]) in warm and raw[i+3]>0 for i in range(0,len(raw),4)))
 def test_fire_cooling_has_no_active_or_ignition_bright_pixels(self):
  warm={tuple(bytes.fromhex(c[1:])) for c in ['#fa4b26','#ff943e','#ff6a2e','#ffc05a']}
  for a in LAYOUT['atlases']:
   if a['material']=='fire':
    for phase,f,im in frames(a):
     if phase=='cooling':
      raw=im.tobytes();self.assertFalse(any(tuple(raw[i:i+3]) in warm and raw[i+3]>0 for i in range(0,len(raw),4)))
 def test_eight_element_palette_matches_source(self):
  source=json.loads((ROOT/'evidence/input-visual-language.json').read_text())
  self.assertEqual([e['id'] for e in PALETTE['elements']],['water','earth','fire','wind','ice','charge','light','dark'])
  for e in PALETTE['elements']:self.assertEqual(e['palette'],{k:source['elements'][e['id']][k] for k in ['dark','base','bright']})
 def test_original_captures_byte_identical(self):
  for p in (ROOT/'assets/reference_inputs').glob('*.png'):
   record=RECORDS['repository/docs/evidence/global-hex-20260920/native/'+p.name];self.assertEqual(hashlib.sha256(p.read_bytes()).hexdigest(),record['sha256'])
 def test_active_source_body_sheets_unchanged(self):
  for size,height in [('small',58),('middle',63),('large',68)]:
   p=ROOT/f'assets/actors/{size}-base.png';record=RECORDS['repository/assets/sprites/wireframe_motion_v2/'+p.name]
   self.assertEqual(hashlib.sha256(p.read_bytes()).hexdigest(),record['sha256'])
   im=rgba(Image.open(p));bbox=im.crop((0,0,96,96)).getchannel('A').getbbox();self.assertEqual(bbox[3]-bbox[1],height);self.assertEqual(bbox[3],84)
 def test_restoration_retains_exact_source_pixel_colors(self):
  src=rgba(Image.open(ROOT/'assets/reference_inputs/01-before-free-casts-1280x720.png')).tobytes()
  dst=rgba(Image.open(ROOT/'assets/actors/source-player-aim-restoration.png')).tobytes()
  for i in range(0,len(dst),4):
   if dst[i+3]:self.assertEqual(dst[i:i+3],src[i:i+3])
 def test_preview_embedded_data_current(self):
  s=(ROOT/'preview/data.js').read_text();d=json.loads(s.split('window.FLUX_DATA=',1)[1].rsplit(';',1)[0]);self.assertEqual(d['materials'],DEFS);self.assertEqual(d['palette'],PALETTE);self.assertEqual(d['atlas'],LAYOUT)
 def test_all_material_atlas_references_exist(self):
  for m in DEFS['materials'].values():
   for p in m['atlases'].values():self.assertTrue((ROOT/p).is_file())
 def test_no_network_code_or_external_assets(self):
  for p in (ROOT/'preview').glob('*.js'):
   s=p.read_text();self.assertNotRegex(s,r'\bfetch\s*\(|\bXMLHttpRequest\b|\bWebSocket\s*\(')
  s=(ROOT/'index.html').read_text();self.assertNotRegex(s,r'(?:src|href)=["\']https?://')
 def test_pilot_has_no_visibility_or_gameplay_authority(self):
  self.assertEqual(DEFS['authority'].split(';')[0],'presentation_only');self.assertFalse(DEFS['density_policy']['foreground_smoke']);self.assertFalse(DEFS['density_policy']['gameplay_regions_may_be_culled']);self.assertEqual(DEFS['density_policy']['normal_free_particles'],0)

if __name__=='__main__':unittest.main(verbosity=2)
