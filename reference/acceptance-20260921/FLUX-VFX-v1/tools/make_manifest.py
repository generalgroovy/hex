#!/usr/bin/env python3
"""Inventory this owned package. Does not touch the source packet or repository.
manifest.json excludes itself from its SHA-256 inventory to avoid self-reference.
"""
from __future__ import annotations
from pathlib import Path
from datetime import datetime,timezone
import hashlib,json
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]

def main():
 access=json.loads((ROOT/'evidence/input-access.json').read_text())
 source=json.loads((ROOT/'evidence/input-manifest.json').read_text())
 integrity=json.loads((ROOT/'evidence/input-integrity.json').read_text())
 layout=json.loads((ROOT/'definitions/atlas-layout.json').read_text())
 atlases={a['path']:a for a in layout['atlases']}
 outputs=[]
 for p in sorted(ROOT.rglob('*')):
  if not p.is_file() or p.name=='manifest.json' or '__pycache__' in p.parts:continue
  rel=p.relative_to(ROOT).as_posix()
  status='PROPOSAL'
  if rel.startswith(('boards/','preview/')) or p.name in ['index.html','preview-standalone.html'] or p.name=='source-player-aim-restoration.png':status='OFFLINE_PREVIEW'
  elif rel.startswith(('tests/','tools/','evidence/')):status='STATIC_VERIFIED'
  if rel.startswith('assets/reference_inputs/') or rel.startswith('assets/actors/') and p.name!='source-player-aim-restoration.png':status='STATIC_VERIFIED'
  role='documentation'
  if rel=='HANDOFF.md' or rel.startswith('integration/'):role='integration_notes'
  elif rel.startswith('assets/motifs/'):role='material_animation_atlas'
  elif rel.startswith('assets/ui/'):role='element_identity_icon'
  elif rel.startswith('assets/reference_inputs/'):role='historical_gameplay_capture'
  elif rel.startswith('assets/actors/'):role='preview_actor_dependency'
  elif rel.startswith('boards/'):role='offline_motion_preview' if p.suffix=='.apng' else 'offline_visual_preview'
  elif rel.startswith('definitions/'):role='material_definitions'
  elif rel.startswith('preview/') or p.suffix=='.html':role='offline_preview_code'
  elif rel.startswith('evidence/'):role='input_or_verification_evidence'
  elif rel.startswith('tests/'):role='offline_test'
  elif rel.startswith('tools/'):role='rebuild_or_package_tool'
  row={'path':rel,'role':role,'status':status,'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'bytes':p.stat().st_size}
  if 'rejected_generation' in p.parts:row.update(status='OFFLINE_PREVIEW',disposition='REJECTED_DO_NOT_INTEGRATE')
  if p.suffix.lower() in ['.png','.apng']:
   with Image.open(p) as im:
    row['dimensions']=list(im.size);row['pixel_mode']=im.mode;row['frame_count']=getattr(im,'n_frames',1)
    alpha=im.convert('RGBA').getchannel('A').getextrema();row['alpha']='opaque' if alpha==(255,255) else 'straight RGBA';row['color_space']='sRGB values'
   if rel in atlases:row.update(cell_size=[64,80],pivot=[32,40],columns=8,rows=atlases[rel]['rows'],frames_per_row=8,filter='nearest; no mipmaps')
   elif rel.startswith('assets/actors/') and '-base.png' in rel:row.update(cell_size=[96,96],pivot=[48,84],provenance='unchanged supplied active base sheet; preview input, not a new skin')
   elif rel.startswith('assets/reference_inputs/'):row['provenance']='unchanged supplied historical gameplay capture; not captured during this assignment'
  outputs.append(row)
 manifest={
  'schema_version':1,'task_id':'FLUX-VFX-v1','handoff_id':'FLUX-VFX-v1','package_root':'FLUX-VFX-v1','category':'vfx','created_at_utc':datetime.now(timezone.utc).isoformat(),
  'status':'PROPOSAL','input_packet_id':source['packet_id'],'input_manifest_sha256':hashlib.sha256((ROOT/'evidence/input-manifest.json').read_bytes()).hexdigest(),'input_archive_sha256':integrity['archive_sha256'],
  'source_identity_as_reported':source['reported_runtime_identity'],'git_head_as_reported':source['git']['head'],'git_as_reported':source['git'],'source_identity_recomputed':False,
  'input_files_read':access['files_with_text_or_selected_source_inspection']+access['actual_native_images_visually_inspected']+access['active_base_sheets_decoded_and_verified']+access['concept_images_visually_inspected'],
  'read_scope_details':'evidence/input-access.json; source excerpts are selected spans, not full code review',
  'missing_inputs':['complete buildable Godot project / project.godot','live Windows checkout and dirty work state','full renderer caller and layer order','VisualLanguage implementation','referenced runtime projectile atlas','nested chemistry snapshot and wire-packing dependencies','current client exposure/eligibility presentation binding','exact saved camera/profile settings'],
  'outputs':outputs,
  'decisions':['Retain all eight source palettes and IDs; Steam is a reaction.','Keep whole selected cells and legacy semantic seams.','Water remains a non-damaging reagent.','Use bounded authored motifs; Steam is open scald, never concealment.','Read per-region heat and optional actor exposure independently.','Preserve existing projectile strength-size math and all gameplay values.','Union coincident same-material base opacity without discarding records.','All new previews are offline, with no Godot/human acceptance claim.'],
  'proposed_live_targets':['content/visual/visual_language_v1.json (lead-mapped schema only)','src/presentation/hex_court_presenter.gd (Water/Fire/Steam presentation only)','new lead-owned texture folder, e.g. assets/sprites/element_material_v1/'],
  'dependencies':{'preview_runtime':'modern browser; all runtime images/data/code embedded in preview-standalone.html or included alongside index.html','preview_entrypoints':['preview-standalone.html','index.html'],'development':'Python + Pillow; optional Playwright + Chromium and Node. See evidence/verification.json and requirements-dev.txt.','font_files_included':False,'network_required_for_preview':False},
  'tests':json.loads((ROOT/'evidence/verification.json').read_text())['checks'],
  'risks':['Godot import/UV sampling/caller layer mapping are unverified.','Saved camera transform is missing; native paintover uses a documented 0.75x fit.','Actor exposure/eligibility is an optional unbound read-only proposal; no new network fields.','No runtime performance or paid-workload equivalence claim.','Grounded base-sprite directions are not the full travel/aim animation matrix.','Same-material coincident fill opacity is unioned; per-record motifs/seams remain and need real dense-capture review.','Image-generator exploration is rejected; never integrate it.'],
  'runtime_verification':'NOT_RUN','godot_verification':'NOT_RUN','human_acceptance':'NOT_RUN',
  'source_changes':{'packet_files_changed':0,'live_repo_files_changed':0,'commits':0,'pushes':0,'checkpoint_promotions':0},
  'hash_policy':'Every regular payload file is listed except manifest.json itself; no self-hash. ZIP SHA-256 is external.'}
 for test in manifest['tests']:
  evidence=test.get('evidence',[]);test['evidence']=evidence if isinstance(evidence,list) else [evidence]
 (ROOT/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
 print('manifest:',len(outputs),'payload files')
if __name__=='__main__':main()
