"""Seal the completed unintegrated D8 experiment and retain its exact attempts."""
from pathlib import Path
import json, hashlib, shutil, subprocess

root=Path(r'C:\Users\sende\Projects\hex')
out=root/'docs/verification/hex-viewport-20260923'
assert Path.cwd().resolve()==root.resolve()
def read(p): return json.loads(p.read_text(encoding='utf-8-sig'))
def sha(p):
    with p.open('rb') as stream: return hashlib.file_digest(stream,'sha256').hexdigest()
def copy(p,q):
    q.parent.mkdir(parents=True,exist_ok=True)
    if q.exists(): assert sha(p)==sha(q), str(q)
    else: shutil.copy2(p,q)

for name in ['start_viewport_candidate.py','preserve_viewport_candidate.py','refine_viewport_cells.py',
             'audit_viewport_result.py','seal_viewport_evidence.py',
             'run_viewport_candidate_v1.ps1','run_viewport_candidate_v2.ps1','run_viewport_candidate_v3.ps1']:
    copy(root/'.godot'/name,out/'tools'/name)
attempt_files=0
for version in ['v1','v2','v3']:
    folder=out/'attempts'/version
    for entry in read(folder/'freeze.json')['files']:
        assert sha(out/entry['preserved'])==entry['sha256'],entry
        if version=='v3': assert sha(root/entry['source'])==entry['sha256'],entry
    for entry in read(folder/'evidence-map.json')['files']:
        assert sha(out/entry['preserved'])==entry['sha256'],entry
        assert sha(root/entry['source'])==entry['sha256'],entry
        attempt_files+=1
baseline=read(out/'baseline.json')
for entry in baseline['protected']+baseline['baseline_sources']:
    assert sha(root/entry['path'])==entry['sha256'],entry
assert not subprocess.check_output(['git','diff','--cached','--name-only'],cwd=root,text=True).strip()
assert read(root/'content/runtime/runtime_build_identity_v1.json')==baseline['runtime_identity']
for name in ['.agent/HEX-RESUME.md','.agent/OVERHAUL-IMPLEMENTATION.md']:
    copy(root/name,out/'final-documentation'/name)
records=[]
for p in sorted(out.rglob('*')):
    if p.is_file() and p.relative_to(out).as_posix() not in ['evidence-map.json','final-audit.json']:
        records.append({'path':p.relative_to(out).as_posix(),'sha256':sha(p),'bytes':p.stat().st_size})
(out/'evidence-map.json').write_text(json.dumps({'scope':'Sealed D8 test-only candidate, attempts, failed and passing receipts, referenced logs and images, source freezes, review and current handoff. No personal or isolated profiles copied.','files':records},indent=2)+'\n',encoding='utf-8')
(out/'final-audit.json').write_text(json.dumps({'status':'passed','runtime_build_id':baseline['runtime_identity']['build_id'],
    'production_changed':False,'integration_decision':'DEFER after third refinement; dense draw regressions remain',
    'preserved_files':len(records),'attempt_artifacts':attempt_files,'protected_hashes':len(baseline['protected']),
    'original_source_copies':len(baseline['baseline_sources']),'staged_changes':False,'checkpoint_promoted':False},indent=2)+'\n',encoding='utf-8')
print(f'PASS: D8 sealed {len(records)} files, {attempt_files} original/preserved attempt artifacts,44 protected hashes; unchanged playable D6 identity')
