from pathlib import Path
import hashlib, json, re
root = Path(__file__).resolve().parents[4]
archive = Path(__file__).resolve().parent / 'production-reset-a'
path = root / 'assets/environment/wellspring_ground_v1/manifest.tres'
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
before = path.read_bytes()
assert not (archive / 'manifest-before.tres').exists()
text = before.decode()
match = re.search(r'"source_sha256": \{\r?\n(.*?)\r?\n\}', text, re.S)
assert match
old = json.loads('{' + match[1] + '}')
sources = sorted(list(old) + ['res://src/presentation/wellspring_async_terrain_stream.gd', 'res://src/presentation/terrain_hash_job.gd'])
assert len(set(sources)) == len(sources) == 10
provenance = {p: sha(root / p.removeprefix('res://')) for p in sources}
images = {p.name: sha(p) for p in path.parent.glob('*.res')}
assert len(images) == 133
newline = '\r\n' if b'\r\n' in before else '\n'
body = (',' + newline).join(json.dumps(k) + ': ' + json.dumps(v) for k, v in provenance.items())
after = (text[:match.start(1)] + body + text[match.end(1):]).encode()
(archive / 'manifest-before.tres').write_bytes(before)
path.write_bytes(after)
assert images == {p.name: sha(p) for p in path.parent.glob('*.res')}
record = {'scope': 'Source provenance only. All 133 prepared image resource bytes unchanged; no rebake or pixel replacement.', 'manifest_before_sha256': hashlib.sha256(before).hexdigest(), 'manifest_after_sha256': sha(path), 'source_sha256': provenance, 'unchanged_images': images}
(archive / 'provenance-refresh.json').write_text(json.dumps(record,indent=2)+'\n')
print(json.dumps({'manifest_sha256':sha(path),'source_count':len(sources),'unchanged_images':len(images)}))
