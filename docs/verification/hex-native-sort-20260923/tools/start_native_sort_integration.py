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
assert not (out / 'integration-baseline.json').exists()
baseline = read(out / 'baseline.json')
for item in baseline['protected']:
    assert sha(root / item['path']) == item['sha256'], item['path']
assert read(out / 'runs/v1/audit.json')['status'] == 'passed'
changed = ['src/sim/hex/hex_chemistry_world.gd', 'tests/unit/test_hex_hash_specialization.gd',
           'content/runtime/runtime_build_identity_v1.json', 'scripts/package-hex.ps1',
           'README.md', 'SPECIFICATION.md', 'docs/HEX-PLAYTEST.md']
originals = []
for name in changed:
    target = out / 'integration-baseline-source' / name
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(root / name, target)
    originals.append({'path': name, 'sha256': sha(target), 'preserved': target.relative_to(out).as_posix()})
protected = [item for item in baseline['protected'] if item['path'] not in changed]
(out / 'integration-baseline.json').write_text(json.dumps({'utc': datetime.now(timezone.utc).isoformat(),
    'protected': protected, 'baseline_sources': originals, 'runtime_identity': baseline['runtime_identity'],
    'scope': 'D9 production integration of measured key sorting, with single existing record projection and generic fallback retained.'}, indent=2) + '\n', encoding='utf-8')
print(f'Integration baseline: {len(protected)} untouched protected hashes and {len(originals)} source/document originals')
