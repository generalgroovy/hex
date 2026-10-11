from pathlib import Path
from datetime import datetime, timezone
import hashlib, json, shutil, subprocess

root = Path(r'C:\Users\sende\Projects\hex')
assert Path.cwd() == root
def sha(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()
def git(*args):
    return subprocess.check_output(['git', *args], cwd=root, text=True).strip()
assert git('remote', 'get-url', 'origin') == 'https://github.com/generalgroovy/hex.git'
assert not git('diff', '--cached', '--name-only')
old = root / 'docs/verification/hex-gallery-availability-20260923'
protected = json.loads((old / 'preservation-audit.json').read_text(encoding='utf-8'))['protected_files']
for item in protected:
    assert sha(root / item['path']) == item['sha256'], item['path']
for name in ['exports/hex-gallery-availability-20260923/windows/hex.pck',
             'exports/hex-gallery-availability-20260923/HEX-p55-aeefbd4a5e7b-Windows-x64.zip']:
    if not any(item['path'] == name for item in protected):
        protected.append({'path': name, 'sha256': sha(root / name)})
identity = json.loads((root / 'content/runtime/runtime_build_identity_v1.json').read_text(encoding='utf-8'))
assert identity['build_id'] == 'p55-aeefbd4a5e7b'
out = root / 'docs/verification/hex-native-sort-20260923'
assert not out.exists()
out.mkdir(parents=True)
(out / '.gdignore').write_text('', encoding='utf-8')
originals = []
for name in ['.agent/OVERHAUL-IMPLEMENTATION.md', '.agent/HEX-RESUME.md',
             'src/sim/hex/hex_chemistry_world.gd', 'tests/performance/profile_hex_hash_candidate.gd',
             'tests/support/hex_stable_cells_candidate.gd']:
    target = out / 'baseline-source' / name
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(root / name, target)
    originals.append({'path': name, 'sha256': sha(target), 'preserved': target.relative_to(out).as_posix()})
record = {'utc': datetime.now(timezone.utc).isoformat(), 'root': str(root),
          'origin': git('remote', 'get-url', 'origin'), 'head': git('rev-parse', 'HEAD'),
          'branch': git('branch', '--show-current'), 'status': git('status', '--short').splitlines(),
          'staged': [], 'runtime_identity': identity, 'protected': protected,
          'baseline_sources': originals, 'weekly_remaining_percent': 5,
          'scope': 'D9 test-only native cell-key sort; exact whole public hash A/B; root sole engine owner.',
          'engine_context': 'Previously visible user hex PID17752 exited before this slice; never stopped by agent.'}
(out / 'baseline.json').write_text(json.dumps(record, indent=2) + '\n', encoding='utf-8')
print(f'D9 baseline sealed: {len(protected)} protected hashes, {len(originals)} source/document copies')
