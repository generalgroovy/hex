from pathlib import Path
from datetime import datetime, timezone
import hashlib, json, shutil, subprocess
root = Path(r'C:\Users\sende\Projects\hex')
out = root / 'docs/verification/hex-viewport-20260923'
assert Path.cwd().resolve() == root.resolve()
def read(path): return json.loads(path.read_text(encoding='utf-8-sig'))
def sha(path):
    with path.open('rb') as stream: return hashlib.file_digest(stream, 'sha256').hexdigest()
def git(*args): return subprocess.check_output(['git', *args], cwd=root, text=True).strip()
assert git('remote', 'get-url', 'origin') == 'https://github.com/generalgroovy/hex.git'
assert not git('diff', '--cached', '--name-only')
assert not (out / 'baseline.json').exists()
protected = read(root / 'docs/verification/hex-render-frame-20260923/preservation-audit.json')['protected_files']
for item in protected: assert sha(root / item['path']) == item['sha256'], item['path']
for name in ['exports/hex-render-frame-20260923/windows/hex.pck',
             'exports/hex-render-frame-20260923/HEX-p55-1b26a51136d1-Windows-x64.zip',
             'tests/support/hex_ordered_geometry_candidate.gd', 'tests/performance/profile_hex_ordered_geometry_candidate.gd']:
    protected.append({'path':name, 'sha256':sha(root / name)})
originals = []
for name in ['src/presentation/hex_court_presenter.gd', 'src/app/bootstrap.gd',
             'src/presentation/pixel_presentation.gd', 'src/presentation/hex_water_material_presenter.gd',
             'tests/support/hex_draw_component_harness.gd', 'tests/performance/profile_hex_draw_components.gd',
             'content/runtime/runtime_build_identity_v1.json']:
    target = out / 'baseline-source' / name
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(root / name, target)
    originals.append({'path':name, 'sha256':sha(target), 'preserved':target.relative_to(out).as_posix()})
identity = read(root / 'content/runtime/runtime_build_identity_v1.json')
assert identity['build_id'] == 'p55-1b26a51136d1'
report = {'utc':datetime.now(timezone.utc).isoformat(), 'root':str(root),
          'origin':git('remote','get-url','origin'), 'head':git('rev-parse','HEAD'),
          'branch':git('branch','--show-current'), 'status':git('status','--short').splitlines(),
          'staged':[], 'runtime_identity':identity, 'protected':protected, 'baseline_sources':originals,
          'scope':'D8 TEST-ONLY viewport material submission candidate. No production modification authorized for this experimental slice before source review, exact pixel/authority comparisons and measured benefit. D6 source/package stay frozen; one integration owner runs every engine command.'}
(out / 'baseline.json').write_text(json.dumps(report,indent=2)+'\n')
print('PASS: D8 baseline;',len(protected),'protected hashes,',len(originals),'source originals; D6 unchanged')
