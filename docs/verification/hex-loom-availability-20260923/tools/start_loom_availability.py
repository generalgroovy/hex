from pathlib import Path
from datetime import datetime, timezone
import hashlib, json, shutil, subprocess

root = Path(r'C:\Users\sende\Projects\hex')
out = root / 'docs/verification/hex-loom-availability-20260923'
assert Path.cwd().resolve() == root.resolve()
def sha(path):
    with path.open('rb') as f: return hashlib.file_digest(f, 'sha256').hexdigest()
def git(*args): return subprocess.check_output(['git', *args], cwd=root, text=True).strip()
assert git('remote', 'get-url', 'origin') == 'https://github.com/generalgroovy/hex.git'
assert not git('diff', '--cached', '--name-only')
assert not out.exists()
out.mkdir(parents=True)
changed = ['src/app/bootstrap.gd', 'src/app/character_weave_policy.gd',
           'src/app/spell_loom_editor.gd', 'src/presentation/spell_loom_presenter.gd',
           'tests/unit/test_spell_loom_editor.gd', 'tests/unit/test_character_weave_policy.gd',
           'tests/unit/test_weave_acknowledgement.gd', 'tests/run_all.gd',
           'content/runtime/runtime_build_identity_v1.json', 'scripts/package-hex.ps1',
           'SPECIFICATION.md', 'README.md', 'docs/HEX-PLAYTEST.md',
           '.agent/OVERHAUL-IMPLEMENTATION.md', '.agent/HEX-RESUME.md']
old = json.loads((root / 'docs/verification/hex-viewport-20260923/baseline.json').read_text())
protected = [x for x in old['protected'] if x['path'] not in changed]
for item in protected: assert sha(root / item['path']) == item['sha256'], item['path']
originals = []
for name in changed:
    target = out / 'baseline-source' / name
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(root / name, target)
    originals.append({'path':name, 'sha256':sha(target), 'preserved':target.relative_to(out).as_posix()})
identity = json.loads((root / 'content/runtime/runtime_build_identity_v1.json').read_text())
assert identity['build_id'] == 'p55-1b26a51136d1'
report = {'utc':datetime.now(timezone.utc).isoformat(), 'root':str(root),
          'origin':git('remote','get-url','origin'), 'head':git('rev-parse','HEAD'),
          'branch':git('branch','--show-current'), 'status':git('status','--short').splitlines(),
          'staged':[], 'runtime_identity':identity, 'protected':protected, 'baseline_sources':originals,
          'scope':'E1 contextual Spell Loom availability; unchanged authority rules, content, simulation and saved IDs. Root alone runs engine validation. D6 package retained as fallback.'}
(out / 'baseline.json').write_text(json.dumps(report,indent=2)+'\n')
print('PASS baseline:',len(protected),'protected hashes;',len(originals),'preserved originals')
