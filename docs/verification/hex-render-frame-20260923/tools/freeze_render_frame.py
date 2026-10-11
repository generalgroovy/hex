from pathlib import Path
from datetime import datetime, timezone
import hashlib, json, subprocess

root = Path(r'C:\Users\sende\Projects\hex')
out = root / 'docs/verification/hex-render-frame-20260923'
assert Path.cwd().resolve() == root.resolve()
def read(path): return json.loads(path.read_text(encoding='utf-8-sig'))
def sha(path):
    with path.open('rb') as stream: return hashlib.file_digest(stream, 'sha256').hexdigest()
baseline = read(out / 'baseline.json')
for item in baseline['protected']:
    assert sha(root / item['path']) == item['sha256'], item['path']
assert not subprocess.check_output(['git', 'diff', '--cached', '--name-only'], cwd=root, text=True).strip()
paths = ['src/presentation/hex_court_presenter.gd', 'content/runtime/runtime_build_identity_v1.json',
         'tests/unit/test_hex_render_frame.gd', 'tests/run_all.gd', 'scripts/package-hex.ps1',
         'tests/support/hex_render_frame_candidate.gd', 'tests/performance/profile_hex_render_frame_candidate.gd',
         'tests/support/hex_render_frame_native_presenter.gd', 'tests/performance/profile_hex_render_frame_native_candidate.gd',
         'tests/support/hex_draw_component_harness.gd', 'tests/performance/profile_hex_draw_components.gd',
         'tests/performance/profile_unified_wellspring_rendered.gd']
assert not (out / 'freeze.json').exists()
report = {'utc': datetime.now(timezone.utc).isoformat(), 'root': str(root), 'head': baseline['head'],
          'branch': baseline['branch'], 'identity': read(root / paths[1]),
          'files': [{'path': name, 'sha256': sha(root / name)} for name in paths],
          'production_changes': paths[:2],
          'scope': 'D6 production frame-preparation integration frozen before Full, integrated native capture, evolving stress and exact Windows package validation. Prior prototype receipts are historical evidence only. No checkpoint promotion.'}
(out / 'freeze.json').write_text(json.dumps(report, indent=2) + '\n')
print('PASS: frozen', report['identity']['build_id'], len(paths), 'files;', len(baseline['protected']), 'protected hashes unchanged')
