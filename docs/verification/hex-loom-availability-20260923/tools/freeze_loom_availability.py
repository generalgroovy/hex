from pathlib import Path
from datetime import datetime, timezone
import hashlib, json, shutil, subprocess, sys

root = Path(r'C:\Users\sende\Projects\hex')
out = root / 'docs/verification/hex-loom-availability-20260923'
assert Path.cwd().resolve() == root.resolve()
label = sys.argv[1]
assert label.replace('-', '').isalnum()
target = out / label
assert not target.exists()
target.mkdir()
def sha(path):
    with path.open('rb') as f: return hashlib.file_digest(f, 'sha256').hexdigest()
baseline = json.loads((out/'baseline.json').read_text())
for item in baseline['protected']: assert sha(root/item['path']) == item['sha256'], item['path']
assert not subprocess.check_output(['git','diff','--cached','--name-only'],cwd=root,text=True).strip()
paths = ['src/app/bootstrap.gd','src/app/character_weave_policy.gd','src/app/spell_loom_editor.gd',
         'src/presentation/spell_loom_presenter.gd','tests/unit/test_character_weave_policy.gd',
         'tests/unit/test_spell_loom_editor.gd','tests/unit/test_weave_acknowledgement.gd',
         'tests/diagnostics/loom_availability_journey.gd','content/runtime/runtime_build_identity_v1.json',
         'scripts/package-hex.ps1']
records = []
for name in paths:
    dest = target/'source'/name
    dest.parent.mkdir(parents=True,exist_ok=True)
    shutil.copy2(root/name,dest)
    records.append({'path':name,'sha256':sha(dest),'preserved':dest.relative_to(out).as_posix()})
data = {'utc':datetime.now(timezone.utc).isoformat(),'files':records,
        'identity':json.loads((root/paths[-2]).read_text()),'protected_hashes':len(baseline['protected'])}
(target/'freeze.json').write_text(json.dumps(data,indent=2)+'\n')
print('Frozen',label,len(records),'files')
