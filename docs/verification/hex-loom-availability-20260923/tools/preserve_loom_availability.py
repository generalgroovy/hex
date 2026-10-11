from pathlib import Path
import hashlib, json, shutil, sys

root = Path(r'C:\Users\sende\Projects\hex')
evidence = root / 'docs/verification/hex-loom-availability-20260923'
assert Path.cwd().resolve() == root.resolve()
run = sys.argv[1]
assert run.replace('-', '').isalnum()
target = evidence / 'runs' / run
assert not target.exists(), 'Preserved run must not be overwritten'
target.mkdir(parents=True)
paths = [root / '.godot' / run, root / '.godot' / ('hex-probe-' + run)]
records = []
for base in paths:
    for path in sorted(base.rglob('*')):
        if not path.is_file() or 'isolated-roaming' in path.parts: continue
        relative = path.relative_to(root)
        dest = target / relative
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(path, dest)
        records.append({'source':relative.as_posix(), 'preserved':dest.relative_to(evidence).as_posix(), 'sha256':hashlib.sha256(dest.read_bytes()).hexdigest()})
source = root / 'tests/diagnostics/loom_availability_journey.gd'
shutil.copy2(source, target / source.name)
records.append({'source':source.relative_to(root).as_posix(), 'preserved':(target/source.name).relative_to(evidence).as_posix(), 'sha256':hashlib.sha256(source.read_bytes()).hexdigest()})
(target / 'evidence-map.json').write_text(json.dumps(records,indent=2)+'\n')
print('Preserved',run,len(records),'files')
