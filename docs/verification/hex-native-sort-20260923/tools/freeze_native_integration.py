from pathlib import Path
from datetime import datetime, timezone
import hashlib, json, shutil

root = Path(r'C:\Users\sende\Projects\hex')
assert Path.cwd() == root
out = root / 'docs/verification/hex-native-sort-20260923'
def sha(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()
def read(path):
    return json.loads(path.read_text(encoding='utf-8'))
baseline = read(out / 'integration-baseline.json')
for item in baseline['protected']:
    assert sha(root / item['path']) == item['sha256'], item['path']
for item in read(out / 'freeze-v1/freeze.json')['files']:
    if item['path'] != 'src/sim/hex/hex_chemistry_world.gd':
        assert sha(root / item['path']) == item['sha256'], item['path']
target = out / 'integration-freeze-v1'
assert not target.exists()
target.mkdir()
files = []
for name in ['src/sim/hex/hex_chemistry_world.gd', 'tests/unit/test_hex_hash_specialization.gd',
             'tests/performance/profile_hex_native_sort_integrated.gd',
             'content/runtime/runtime_build_identity_v1.json', 'scripts/package-hex.ps1',
             '.godot/gallery_pose_control.gd', '.godot/freeze_native_integration.py']:
    copy = target / name
    copy.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(root / name, copy)
    files.append({'path': name, 'sha256': sha(copy), 'preserved': copy.relative_to(out).as_posix()})
identity = read(root / 'content/runtime/runtime_build_identity_v1.json')
assert identity['build_id'] != baseline['runtime_identity']['build_id']
(target / 'freeze.json').write_text(json.dumps({'utc': datetime.now(timezone.utc).isoformat(),
    'files': files, 'protected_hashes': len(baseline['protected']), 'identity': identity}, indent=2) + '\n', encoding='utf-8')
print(f'PASS: integration frozen {identity["build_id"]}, {len(files)} files, {len(baseline["protected"])} protected hashes')
