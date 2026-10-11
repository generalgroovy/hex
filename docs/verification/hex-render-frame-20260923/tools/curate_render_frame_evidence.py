"""Preserve D6 integrated receipts with their logs/images, verify frozen sources and fallbacks."""
from pathlib import Path
import hashlib, json, shutil, subprocess, zipfile

root = Path(r'C:\Users\sende\Projects\hex')
out = root / 'docs/verification/hex-render-frame-20260923'
assert Path.cwd().resolve() == root.resolve()
def read(path): return json.loads(path.read_text(encoding='utf-8-sig'))
def sha(path):
    with path.open('rb') as stream: return hashlib.file_digest(stream, 'sha256').hexdigest()
records = []
def preserve(source, target):
    if source.is_dir():
        for child in sorted(source.rglob('*')):
            if child.is_file() and 'isolated-roaming' not in child.parts:
                preserve(child, target / child.relative_to(source))
        return
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(source, target)
    assert sha(source) == sha(target)
    records.append({'source': source.relative_to(root).as_posix(),
                    'preserved': target.relative_to(out).as_posix(), 'sha256': sha(target)})

for path in sorted(out.glob('*.json')):
    data = read(path)
    if data.get('tier') and data.get('isolation', {}).get('appdata_path'):
        preserve((root / data['isolation']['appdata_path']).parent,
                 out / 'gates' / Path(data['isolation']['appdata_path']).parent.name)
for pattern in ['hex-probe-render-frame-*', 'hex-draw-components-render-frame-*',
                'hex-ordered-geometry-candidate-render-frame-*.json',
                'unified-wellspring-render-profile-render-frame-*.json',
                'movement-cast-render-frame-*', 'movement-advanced-render-frame-*',
                'water-render-frame-*', 'station-labels-render-frame-*', 'terrain-render-frame-*']:
    for source in sorted((root / '.godot').glob(pattern)):
        preserve(source, out / 'runs' / source.name)
for source in sorted((root / 'docs/verification/hex-acceptance-20260921').glob('render-frame-*')):
    preserve(source, out / 'loom' / source.name)
for source in sorted((root / '.godot').glob('*render_frame*.py')):
    if source.name != 'check_render_frame_native.py': preserve(source, out / 'tools' / source.name)
for source in sorted((root / '.godot').glob('*render_frame*.ps1')):
    preserve(source, out / 'tools' / source.name)
for name in ['src/presentation/hex_court_presenter.gd', 'tests/unit/test_hex_render_frame.gd',
             'tests/run_all.gd', 'scripts/package-hex.ps1',
             'tests/support/hex_render_frame_candidate.gd', 'tests/support/hex_wire_decode_candidate.gd',
             'tests/support/hex_ordered_geometry_candidate.gd', 'tests/performance/profile_hex_ordered_geometry_candidate.gd',
             'src/sim/hex/hex_chemistry_world.gd']:
    preserve(root / name, out / 'final-source' / name)

package = root / 'exports/hex-render-frame-20260923'
meta = read(package / 'receipt.json')
preserve(package / 'receipt.json', out / 'package/receipt.json')
preserve(package / 'logs', out / 'package/logs')
for name in ['BUILD-STATE.json', 'SOURCE-IDENTITY.json', 'SHA256SUMS.txt', 'README-FIRST.txt', 'PLAY-HEX.cmd']:
    preserve(package / 'windows' / name, out / 'package' / name)
assert sha(package / 'windows/hex.pck') == meta['pack_sha256']
assert sha(Path(meta['zip'])) == meta['zip_sha256']
zipped = []
with zipfile.ZipFile(meta['zip']) as archive:
    for info in archive.infolist():
        if info.is_dir(): continue
        name = Path(info.filename).name
        digest = hashlib.sha256(archive.read(info)).hexdigest()
        assert digest == sha(package / 'windows' / name)
        zipped.append({'name': name, 'sha256': digest})
assert len(zipped) == len([p for p in (package / 'windows').iterdir() if p.is_file()])
(out / 'package-audit.json').write_text(json.dumps({'status':'passed', 'build_id':meta['build_id'],
    'pck_sha256':meta['pack_sha256'], 'zip_sha256':meta['zip_sha256'], 'entries':zipped}, indent=2)+'\n')

protected = read(out / 'baseline.json')['protected'] + read(out / 'freeze.json')['files']
for item in protected:
    assert sha(root / item['path']) == item['sha256'], item['path']
assert not subprocess.check_output(['git', 'diff', '--cached', '--name-only'],cwd=root,text=True).strip()
(out / 'preservation-audit.json').write_text(json.dumps({'status':'passed', 'protected_files':protected,
    'staged_changes':False, 'checkpoint_promoted':False},indent=2)+'\n')
for item in records:
    assert sha(out / item['preserved']) == item['sha256']
(out / 'evidence-map.json').write_text(json.dumps({'scope':'D6 integrated source, gates, captures, evolving stress and exact Windows journeys with referenced logs/images. Personal profiles never copied; isolated profiles retained in original run locations.', 'files':records},indent=2)+'\n')
print(f'PASS: {len(records)} preserved files, {len(protected)} frozen/protected hashes; package ZIP/PCK verified; fallbacks and selected pointer unchanged')
