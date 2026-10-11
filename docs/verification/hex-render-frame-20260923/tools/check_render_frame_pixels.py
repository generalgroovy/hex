from pathlib import Path
import hashlib, json
from PIL import Image

root = Path(r'C:\Users\sende\Projects\hex')
out = root / 'docs/verification/hex-render-frame-20260923'
assert Path.cwd().resolve() == root.resolve()
def read(path): return json.loads(path.read_text(encoding='utf-8-sig'))
def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()
old = read(root / '.godot/hex-draw-components-hash-v2.json')
new = read(root / '.godot/hex-draw-components-render-frame-v1.json')
assert old['failures'] == new['failures'] == 0
assert len(old['cases']) == len(new['cases']) == 4
rows = []
for a, b in zip(old['cases'], new['cases']):
    for field in ['case', 'mode', 'world_tick', 'world_hash', 'topology_cells', 'actors', 'occupancy', 'paid_metrics']:
        assert a[field] == b[field], (field, a['case'], a['mode'])
    stem = a['case'] + '-' + a['mode']
    for arm in ['original', 'disabled', 'enabled']:
        name = stem + '-' + arm + '.png'
        before = root / '.godot/hex-draw-components-hash-v2-frames' / name
        after = root / '.godot/hex-draw-components-render-frame-v1-frames' / name
        with Image.open(before) as source, Image.open(after) as current:
            assert source.size == current.size == (1280, 720)
            original = source.convert('RGBA').tobytes()
            actual = current.convert('RGBA').tobytes()
            assert original == actual, name
        rgba = hashlib.sha256(actual).hexdigest()
        assert rgba == a[arm + '_rgba_sha256'] == b[arm + '_rgba_sha256']
        rows.append({'name': name, 'before_png_sha256': sha(before), 'after_png_sha256': sha(after),
                     'rgba_sha256': rgba, 'decoded_pixels_equal': True})
for path, digest in new['source_sha256'].items():
    assert sha(root / path) == digest, path
report = {'status': 'passed', 'scope': 'Actual integrated production images versus preserved pre-integration D5 baseline, same frozen states. Pixel/authority equivalence only; sequential timing observations are not a new matched A/B speedup.',
          'old_receipt': '.godot/hex-draw-components-hash-v2.json', 'old_receipt_sha256': sha(root / '.godot/hex-draw-components-hash-v2.json'),
          'new_receipt': '.godot/hex-draw-components-render-frame-v1.json', 'new_receipt_sha256': sha(root / '.godot/hex-draw-components-render-frame-v1.json'),
          'source_identity': read(root / 'content/runtime/runtime_build_identity_v1.json'), 'images': rows}
(out / 'integrated-pixel-equivalence.json').write_text(json.dumps(report, indent=2) + '\n')
print('PASS: all12 actual integrated PNGs equal preserved D5 baseline RGBA8 bytes, all4 authority/accounting fixtures match; source hashes verified')
