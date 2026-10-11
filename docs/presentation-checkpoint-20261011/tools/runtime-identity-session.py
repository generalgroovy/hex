import hashlib
import json
import pathlib
import re
import sys

root = pathlib.Path(sys.argv[1]).resolve()
mode = sys.argv[2]
manifest_path = root / 'content/runtime/runtime_build_identity_v1.json'
manifest = json.loads(manifest_path.read_text())
required = ['project.godot', 'art_batches/pixel_v1/magic/manifest.json', 'art_batches/pixel_v1/map/manifest.json', 'art_batches/wellspring_style_v2/ground_style.gd']
trees = ['src', 'content', 'scenes', 'addons', 'assets', 'art_batches/pixel_v1/magic/export', 'art_batches/pixel_v1/map/export', 'art_batches/wellspring_style_v2/runtime']
paths = set(required)
for tree in trees:
    for path in (root / tree).rglob('*'):
        assert not path.is_symlink(), path
        if path.is_file() and path != manifest_path:
            paths.add(path.relative_to(root).as_posix())
def constant(path, name):
    found = re.findall(r'^const\s+' + name + r':\s*int\s*=\s*([0-9_]+)\s*$', (root / path).read_text(), re.M)
    assert len(found) == 1
    return int(found[0].replace('_',''))
protocol = constant('src/sim/core/sim_config.gd', 'PROTOCOL_VERSION')
snapshot = constant('src/net/session_snapshot.gd', 'SCHEMA_VERSION')
engine = '4.7.1.stable.official.a13da4feb'
lines = ['FLUX_RUNTIME_BUILD_IDENTITY_V1', f'protocol:{protocol}', f'snapshot_schema:{snapshot}', f'engine_utf8:{len(engine.encode())}:{engine}', f'record_count:{len(paths)}']
for relative in sorted(paths):
    data = (root / relative).read_bytes()
    lines += [f'path_utf8:{len(relative.encode())}:{relative}', f'bytes:{len(data)}', f'sha256:{hashlib.sha256(data).hexdigest()}']
digest = hashlib.sha256(('\n'.join(lines)+'\n').encode()).hexdigest()
expected = dict(schema_version=1, status='candidate_generated_not_promoted', scope_id='production-runtime-source-v1', canonical_encoding='utf8-lf-tagged-length-v1', protocol_version=protocol, snapshot_schema=snapshot, engine_identity=engine, record_count=len(paths), runtime_source_sha256=digest, build_id=f'p{protocol}-{digest[:12]}', authority='Generated from canonical production runtime source records; delivery, publication and acceptance remain separate.')
if mode == 'check':
    assert manifest == expected, {'actual':manifest, 'expected':expected}
elif mode == 'generate':
    manifest_path.write_text(json.dumps(expected,indent=2)+'\n')
else:
    raise ValueError(mode)
print(f'PASS {mode}: {expected["build_id"]}, {len(paths)} exact runtime source records')
