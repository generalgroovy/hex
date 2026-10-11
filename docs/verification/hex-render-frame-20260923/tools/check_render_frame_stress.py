from pathlib import Path
import hashlib, json
root = Path(r'C:\Users\sende\Projects\hex')
out = root / 'docs/verification/hex-render-frame-20260923'
assert Path.cwd().resolve() == root.resolve()
def read(path): return json.loads(path.read_text(encoding='utf-8-sig'))
def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()
old_path = root / '.godot/unified-wellspring-render-profile-hash-v1.json'
new_path = root / '.godot/unified-wellspring-render-profile-render-frame-v1.json'
old, new = read(old_path), read(new_path)
assert old['failures'] == new['failures'] == 0
fields = ['case', 'sample_ticks', 'requested_pressed_by_wire', 'requested_held_ticks_by_wire',
          'admitted_by_wire', 'refusals_by_wire_and_reason', 'released_by_wire', 'processed_clashes',
          'processed_products', 'workload_totals', 'event_counts', 'authority_metrics', 'peaks',
          'inventory_totals', 'alive_work', 'final_occupancy_after_cleanup', 'contact_queries',
          'cleanup_ticks', 'sample_end_hash', 'final_hash', 'trace_sha256', 'draw_authority_checks',
          'draw_authority_mutations', 'present_frames', 'visual_mode']
assert len(old['runs']) == len(new['runs']) == 4
for a, b in zip(old['runs'], new['runs']):
    for field in fields: assert a[field] == b[field], (a['case'], a['visual_mode'], field)
for path, digest in new['source_sha256'].items(): assert sha(root / path) == digest, path
report = {'status':'passed', 'scope':'Fresh integrated stress has exactly the previous D2 authority workload and traces, with no workload/cadence changes. Sequential timing results are not a matched A/B gain.',
          'old_receipt_sha256': sha(old_path), 'new_receipt_sha256': sha(new_path),
          'compared_fields':fields, 'cases':4, 'assertions':new['assertions'],
          'frames':sum(r['present_frames'] for r in new['runs']),
          'deadline_misses':sum(r['frame_deadline_misses_over_16667us'] for r in new['runs']),
          'draw_authority_mutations':sum(r['draw_authority_mutations'] for r in new['runs'])}
(out / 'stress-workload-equivalence.json').write_text(json.dumps(report,indent=2)+'\n')
print(json.dumps(report))
