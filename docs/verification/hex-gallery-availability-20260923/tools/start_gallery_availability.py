from pathlib import Path
from datetime import datetime, timezone
import hashlib, json, shutil, subprocess
root = Path(r'C:\Users\sende\Projects\hex')
assert Path.cwd() == root
def sha(p):
    with p.open('rb') as f: return hashlib.file_digest(f, 'sha256').hexdigest()
def git(*args): return subprocess.check_output(['git', *args], cwd=root, text=True).strip()
assert git('remote','get-url','origin') == 'https://github.com/generalgroovy/hex.git'
assert not git('diff','--cached','--name-only')
old = root/'docs/verification/hex-loom-availability-20260923'
seal = old/'documentation-seal.json'
assert not seal.exists()
docs = ['README.md','SPECIFICATION.md','docs/HEX-PLAYTEST.md','.agent/HEX-RESUME.md','.agent/OVERHAUL-IMPLEMENTATION.md',
        'docs/verification/hex-loom-availability-20260923/HANDOFF.md','docs/verification/hex-loom-availability-20260923/review.md']
records = []
for name in docs:
    target=old/'final-documentation'/name
    target.parent.mkdir(parents=True,exist_ok=True)
    shutil.copy2(root/name,target)
    records.append({'source':name,'preserved':target.relative_to(old).as_posix(),'sha256':sha(target)})
seal.write_text(json.dumps({'utc':datetime.now(timezone.utc).isoformat(),'status':'passed',
    'source_only_current_state_check':'passed','git_diff_check':'passed; existing CRLF conversion warning only',
    'independent_review':'review.md final bounded and documentation pass','files':records},indent=2)+'\n')

out=root/'docs/verification/hex-gallery-availability-20260923'
assert not out.exists()
out.mkdir(parents=True)
(out/'.gdignore').write_text('')
changed=['src/app/bootstrap.gd','src/presentation/character_selection_grid.gd',
         'tests/unit/test_character_selection_grid.gd','tests/unit/test_character_gallery_integration.gd',
         'content/runtime/runtime_build_identity_v1.json','scripts/package-hex.ps1',*docs[:5]]
prior=json.loads((old/'preservation-audit.json').read_text())['protected_files']
protected=[x for x in prior if x['path'] not in changed]
for name in ['src/app/character_selection_model.gd','tests/run_all.gd',
             'exports/hex-loom-availability-20260923-v2/windows/hex.pck',
             'exports/hex-loom-availability-20260923-v2/HEX-p55-c5d0f6accb97-Windows-x64.zip']:
    if not any(x['path']==name for x in protected): protected.append({'path':name,'sha256':sha(root/name)})
for item in protected: assert sha(root/item['path'])==item['sha256'],item['path']
originals=[]
for name in changed:
    target=out/'baseline-source'/name
    target.parent.mkdir(parents=True,exist_ok=True)
    shutil.copy2(root/name,target)
    originals.append({'path':name,'sha256':sha(target),'preserved':target.relative_to(out).as_posix()})
identity=json.loads((root/'content/runtime/runtime_build_identity_v1.json').read_text())
assert identity['build_id']=='p55-c5d0f6accb97'
(out/'baseline.json').write_text(json.dumps({'utc':datetime.now(timezone.utc).isoformat(),
    'root':str(root),'origin':git('remote','get-url','origin'),'head':git('rev-parse','HEAD'),
    'branch':git('branch','--show-current'),'status':git('status','--short').splitlines(),
    'staged':[],'runtime_identity':identity,'protected':protected,'baseline_sources':originals,
    'scope':'E2 contextual Gallery availability using existing admission rules; root only engine owner; E1 preserved playable package.'},indent=2)+'\n')
print('Sealed E1 documentation; E2 baseline',len(protected),'protected;',len(originals),'originals')
