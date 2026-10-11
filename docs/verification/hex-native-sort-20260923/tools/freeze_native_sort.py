from pathlib import Path
from datetime import datetime, timezone
import hashlib, json, shutil, sys

root = Path(r'C:\Users\sende\Projects\hex')
assert Path.cwd() == root
out = root / 'docs/verification/hex-native-sort-20260923'
def sha(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()
baseline = json.loads((out / 'baseline.json').read_text(encoding='utf-8'))
for item in baseline['protected']:
    assert sha(root / item['path']) == item['sha256'], item['path']
version = sys.argv[1]
assert version in ['v1', 'v2', 'v3']
target = out / ('freeze-' + version)
assert not target.exists()
target.mkdir()
files = []
for name in ['tests/support/hex_native_sort_candidate.gd',
             'tests/performance/profile_hex_native_sort_candidate.gd',
             'tests/performance/profile_hex_hash_candidate.gd',
             'tests/performance/profile_unified_wellspring.gd',
             'tests/support/hex_stable_cells_candidate.gd',
             'src/sim/hex/hex_chemistry_world.gd',
             'src/sim/core/canonical_bytes.gd', 'src/sim/core/sim_world.gd',
             'src/sim/hex/hex_grid.gd', 'src/sim/hex/hex_world_definition.gd',
             'content/abilities/foundation_abilities_v1.json',
             'content/champions/foundation_champions_v1.json',
             'content/maps/sanctum_campus_g2_v1.json', '.godot/freeze_native_sort.py']:
    copy = target / name
    copy.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(root / name, copy)
    files.append({'path': name, 'sha256': sha(copy), 'preserved': copy.relative_to(out).as_posix()})
(target / 'freeze.json').write_text(json.dumps({'utc': datetime.now(timezone.utc).isoformat(),
    'files': files, 'protected_hashes': len(baseline['protected']),
    'runtime': baseline['runtime_identity']['build_id']}, indent=2) + '\n', encoding='utf-8')
print(f'PASS: {version} freeze of {len(files)} files; {len(baseline["protected"])} protected hashes unchanged')
