from pathlib import Path
import hashlib, json

root = Path(__file__).resolve().parents[4]
stage = Path(__file__).resolve().parent / 'profile-epoch'
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
manifest = json.loads((stage / 'manifest.json').read_text())
assert sha(stage / 'terrain-worker-promotion.patch') == 'd99b02a9e36cb9bd4b29d15ecba926e3a2d2564abcd511bdcfa22e230caaa551'
assert sha(root / manifest['unchanged_base']['path']) == manifest['unchanged_base']['sha256']
for row in manifest['files']:
    target = root / row['path']
    source = stage / 'proposed' / row['path']
    assert sha(source) == row['proposed_sha256'], source
    assert (sha(target) if target.exists() else None) == row['before_sha256'], target
test = stage.parent.parent / 'promoted-test/test_wellspring_async_terrain_stream.gd'
assert sha(test) == '2a44a520e99443853084ff3863fd86eb2ede8b23e46282f21593ce3e1607cc54'
test_target = root / 'tests/unit/test_wellspring_async_terrain_stream.gd'
assert not test_target.exists()
registry = root / 'tests/run_all.gd'
registry_before = registry.read_bytes()
anchor = b'\tpreload("res://tests/unit/test_wellspring_terrain_stream.gd"),'
assert registry_before.count(anchor) == 1
assert b'test_wellspring_async_terrain_stream.gd' not in registry_before
archive = stage / 'integration-before'
assert not archive.exists()
archive.mkdir()
(archive / 'run_all.gd').write_bytes(registry_before)
for row in manifest['files']:
    (root / row['path']).write_bytes((stage / 'proposed' / row['path']).read_bytes())
test_target.write_bytes(test.read_bytes())
newline = b'\r\n' if b'\r\n' in registry_before else b'\n'
registry.write_bytes(registry_before.replace(anchor, anchor + newline + b'\tpreload("res://tests/unit/test_wellspring_async_terrain_stream.gd"),'))
print(json.dumps({'applied': len(manifest['files']), 'test_sha256': sha(test_target), 'registry_sha256': sha(registry)}))
