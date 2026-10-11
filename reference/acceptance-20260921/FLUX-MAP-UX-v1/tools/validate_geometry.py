"""Run independent offline geometry checks, not Godot / real traversal."""
from __future__ import annotations
import json,math,sys,hashlib
from pathlib import Path
from geometry import *
ROOT=Path(__file__).resolve().parents[1]
def read(p):return json.loads((ROOT/p).read_text())
base=read('evidence/source/repository/content/maps/sanctum_campus_g2_v1.json');cand=read('pilot/campus_candidate.json');design=read('HEX_LAYOUT.json')
results=[]
def record(id,passed,detail):results.append({'id':id,'status':'PASS' if passed else 'FAIL','detail':detail})
record('baseline-eligible-count',len(eligible(base))==1493,{'observed':len(eligible(base)),'historical_reference':1493,'scope':'offline port, not independently rerun Godot'})
record('candidate-eligible-data',eligible(cand)==[tuple(c) for c in read('data/eligible_pilot.json')['cells_qr']],{'observed':len(eligible(cand))})
for q,r in [(0,0),(13,23),(-4,9),(20,12)]:
 record(f'owner-center-{q}-{r}',owner(center((q,r)))==(q,r),{'point_fixed':center((q,r))})
record('lexicographic-face-owner',owner((32000,0))==(0,0),{'point_fixed':[32000,0],'owner':owner((32000,0))})
record('strict-disk-tangency', (1,0) not in selected_disk((0,0),32000,[(0,0),(1,0)]),{'radius_fixed':32000,'note':'Exact face tangency does not select neighbor.'})
record('one-fixed-unit-positive-overlap',(1,0) in selected_disk((0,0),32001,[(0,0),(1,0)]),{'radius_fixed':32001})
record('zero-radius-owner',selected_disk((32000,0),0,[(0,0),(1,0)])==[(0,0)],{'point_fixed':[32000,0]})
for key in ['spawn','arena','stations','practice_targets','connections','canvas_size','reserved_ui_top','reset_zones']:
 record(f'preserve-{key}',cand[key]==base[key],{'policy':'unchanged from supplied baseline'})
record('only-two-obstacles-added',len(cand['buildings'])==len(base['buildings'])+2 and cand['buildings'][:16]==base['buildings'],{'base':len(base['buildings']),'candidate':len(cand['buildings'])})
for label,layout in [('baseline',base),('pilot',cand)]:
 for route in layout['routes']+layout['connections']:
  if route['kind'] in ['advanced','garden']:continue
  distance=route_clearance(route['points'],layout['buildings']);needed=route['width']/2
  record(f'{label}-public-route-{route["id"]}',distance+1e-8>=needed,{'analytic_min_obstacle_distance_px':round(distance,4),'required_radius_px':needed,'note':'Continuous static AABB distance, does not model player dynamics or temporary structures.'})
 for anchor in design['anchors']:
  if anchor['coordinate_status']!='STATIC_VERIFIED' or 'fountain' in anchor['id']:continue
  distance=point_clearance(anchor['world_px'],layout['buildings'])
  record(f'{label}-anchor-{anchor["id"]}',distance>=18,{'minimum_obstacle_distance_px':round(distance,4),'common_wall_radius_px':18})
 for group in layout['practice_groups']:
  for i,tid in enumerate(group['target_ids']):
   target=next(t for t in layout['practice_targets'] if t['id']==tid);points=[group['firing_anchors'][i],target['position']]
   distance=route_clearance(points,layout['buildings']);record(f'{label}-fire-line-{tid}',distance>=group['lane_width']/2,{'distance_px':distance,'required_px':group['lane_width']/2})
   for station in layout['stations']:
    dist=point_segment_distance(station['position'],*points)
    record(f'{label}-fire-line-station-{tid}-{station["id"]}',dist>=station['interaction_radius']+group['lane_width']/2,{'distance_px':round(dist,3),'required_px':station['interaction_radius']+group['lane_width']/2})
for route in design['pilot']['escape_routes']:
 distance=route_clearance(route['points_px'],cand['buildings'])
 record(f'pilot-{route["id"]}-desired-width',distance>=route['desired_clear_width_px']/2,{'minimum_obstacle_distance_px':round(distance,3),'required_half_width_px':route['desired_clear_width_px']/2,'length_px':route['polyline_length_px']})
 for size in ['small','middle','large']:
  record(f'pilot-{route["id"]}-{size}',distance>=18,{'wall_radius_px':18,'hurt_radius_px':design['frozen_actor_contract']['hurt_radius_px'][size],'not_proven':'Body-to-body collision, temporary chemistry, dynamic wall normals, network correction.'})
# Verify patch and rollback against objects, without writing source.
import copy
def apply(obj,ops):
 obj=copy.deepcopy(obj)
 for op in ops:
  tokens=op['path'].strip('/').split('/');target=obj
  for token in tokens[:-1]:target=target[int(token)] if isinstance(target,list) else target[token]
  key=tokens[-1]
  if isinstance(target,list):
   if op['op']=='add': target.append(copy.deepcopy(op['value'])) if key=='-' else target.insert(int(key),copy.deepcopy(op['value']))
   elif op['op']=='remove':target.pop(int(key))
   else:target[int(key)]=copy.deepcopy(op['value'])
  elif op['op']=='remove':del target[key]
  else:target[key]=copy.deepcopy(op['value'])
 return obj
record('forward-patch-object-match',apply(base,read('pilot/campus_patch.json'))==cand,{'writes_to_checkout':False})
record('rollback-object-match',apply(cand,read('pilot/campus_rollback.json'))==base,{'note':'Object identity, not source-file formatting. Never apply to changed live source.'})
report={'status':'STATIC_VERIFIED' if all(r['status']=='PASS' for r in results) else 'STATIC_CHECK_FAILED','tool':'Python standard library geometry port','scope':'Input bytes, integer lattice, AABB geometry and proposal data only','runtime':'NOT_RUN','human':'NOT_RUN','collision_dependency':'CollisionWorld implementation missing. Analytic AABB distance assumes tangent contact allowed; compare with live collision.can_occupy.','count':len(results),'passed':sum(r['status']=='PASS' for r in results),'failed':sum(r['status']=='FAIL' for r in results),'results':results}
(ROOT/'evidence/static_geometry_checks.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps({k:report[k] for k in ['status','count','passed','failed']},indent=2))
for r in results:
 if r['status']=='FAIL':print(r)
sys.exit(bool(report['failed']))
