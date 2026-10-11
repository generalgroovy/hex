from pathlib import Path
import hashlib, json, shutil
root = Path(r'C:\Users\sende\Projects\hex')
out = root / 'docs/verification/hex-render-frame-20260923'
assert Path.cwd().resolve() == root.resolve()
records = []
for name, declaration in [('hex_render_frame_candidate.gd', b'class_name HexRenderFrameCandidate'),
                          ('hex_wire_decode_candidate.gd', b'class_name HexWireDecodeCandidate')]:
    source = root / 'tests/support' / name
    before = source.read_bytes()
    line, after = before.split(b'\n', 1)
    assert line.rstrip(b'\r') == declaration
    target = out / 'baseline-source/tests/support' / name
    target.parent.mkdir(parents=True, exist_ok=True)
    assert not target.exists()
    shutil.copy2(source, target)
    source.write_bytes(after)
    assert source.read_bytes() == target.read_bytes().split(b'\n', 1)[1]
    records.append({'path': source.relative_to(root).as_posix(), 'before_sha256': hashlib.sha256(before).hexdigest(),
                    'after_sha256': hashlib.sha256(after).hexdigest(), 'body_bytes_identical': True,
                    'preserved': target.relative_to(out).as_posix()})
original = out / 'freeze.json'
shutil.copy2(original, out / 'freeze-before-registry-repair.json')
freeze = json.loads(original.read_text())
for row in records:
    existing = next((r for r in freeze['files'] if r['path'] == row['path']), None)
    if existing: existing['sha256'] = row['after_sha256']
    else: freeze['files'].append({'path':row['path'], 'sha256':row['after_sha256']})
freeze['test_only_amendment'] = 'Removed unused global class names from two explicitly preloaded test helpers after Fullv1 class-registry rejection. Executable body bytes and all production/runtime identity unchanged. Prior freeze preserved; final Fullv2 required.'
original.write_text(json.dumps(freeze, indent=2) + '\n')
(out / 'test-registry-repair.json').write_text(json.dumps({'status':'passed', 'runtime_changed':False,
    'reason':'Canonical class registry permits production globals and FluxTestSuite only; test helpers require no global symbol.',
    'files':records},indent=2)+'\n')
print('PASS: two unused test-only class declarations removed; original bytes and first freeze preserved; executable bodies unchanged')
