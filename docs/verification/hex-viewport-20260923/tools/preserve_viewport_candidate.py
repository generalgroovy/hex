"""Freeze and preserve D8 test-only attempts without touching the playable source."""
from pathlib import Path
from datetime import datetime, timezone
import argparse
import hashlib
import json
import shutil
import subprocess

ROOT = Path(r'C:\Users\sende\Projects\hex')
OUT = ROOT / 'docs/verification/hex-viewport-20260923'
CANDIDATE = [
    'tests/support/hex_viewport_candidate.gd',
    'tests/support/hex_viewport_harness.gd',
    'tests/performance/profile_hex_viewport_candidate.gd',
]

def sha(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()

def read(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))

def git(*args):
    return subprocess.check_output(['git', *args], cwd=ROOT, text=True).strip()

def audit():
    assert Path.cwd().resolve() == ROOT.resolve(), 'HEX cwd required'
    baseline = read(OUT / 'baseline.json')
    assert git('remote', 'get-url', 'origin') == baseline['origin']
    assert git('rev-parse', 'HEAD') == baseline['head']
    assert git('branch', '--show-current') == baseline['branch']
    assert not git('diff', '--cached', '--name-only'), 'staged boundary changed'
    for item in baseline['protected'] + baseline['baseline_sources']:
        assert sha(ROOT / item['path']) == item['sha256'], item['path']
    for item in baseline['baseline_sources']:
        assert sha(OUT / item['preserved']) == item['sha256'], item['preserved']
    assert read(ROOT / 'content/runtime/runtime_build_identity_v1.json') == baseline['runtime_identity']
    return baseline

def copy_file(source, target, records):
    target.parent.mkdir(parents=True, exist_ok=True)
    if target.exists():
        assert sha(source) == sha(target), f'Preserved evidence may not be overwritten: {target}'
    else:
        shutil.copy2(source, target)
    records.append({'source': source.relative_to(ROOT).as_posix(),
                    'preserved': target.relative_to(OUT).as_posix(), 'sha256': sha(target)})

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('mode', choices=['audit', 'freeze', 'curate'])
    parser.add_argument('--attempt', default='v1')
    args = parser.parse_args()
    assert args.attempt.startswith('v') and args.attempt[1:].isdigit()
    baseline = audit()
    stamp = datetime.now(timezone.utc).isoformat()
    if args.mode == 'audit':
        print(f'PASS: {len(baseline["protected"])} protected hashes, seven source originals, runtime and Git boundary unchanged')
        return
    attempt = OUT / 'attempts' / args.attempt
    freeze_path = attempt / 'freeze.json'
    if args.mode == 'freeze':
        assert not freeze_path.exists(), 'Fresh attempt required'
        records = []
        for name in CANDIDATE:
            source = ROOT / name
            assert source.is_file(), name
            assert '\nclass_name ' not in '\n' + source.read_text(encoding='utf-8-sig'), name
            copy_file(source, attempt / 'source' / name, records)
        for name in ['preserve_viewport_candidate.py', 'run_viewport_candidate_v1.ps1']:
            copy_file(ROOT / '.godot' / name, attempt / 'tools' / name, records)
        freeze_path.write_text(json.dumps({'utc': stamp, 'attempt': args.attempt,
            'identity': baseline['runtime_identity'], 'files': records}, indent=2) + '\n', encoding='utf-8')
        print(f'PASS: {args.attempt} source freeze, {len(records)} files; production untouched')
        return
    freeze = read(freeze_path)
    for record in freeze['files']:
        assert sha(ROOT / record['source']) == record['sha256'], record['source']
    records = []
    for pattern in [f'hex-viewport-candidate-{args.attempt}*', f'hex-probe-viewport-{args.attempt}*']:
        for source in sorted((ROOT / '.godot').glob(pattern)):
            files = [source] if source.is_file() else sorted(source.rglob('*'))
            for file in files:
                if file.is_file() and 'isolated-roaming' not in file.parts:
                    copy_file(file, attempt / 'runs' / file.relative_to(ROOT / '.godot'), records)
    output = OUT / f'probe-{args.attempt}.out'
    if output.is_file():
        copy_file(output, attempt / output.name, records)
    assert records, 'No attempt output to preserve'
    (attempt / 'evidence-map.json').write_text(json.dumps({'utc': stamp, 'files': records,
        'profiles': 'Retained only in original isolated run locations; personal profiles untouched.'}, indent=2) + '\n', encoding='utf-8')
    (OUT / 'preservation-audit.json').write_text(json.dumps({'utc': stamp, 'status': 'passed',
        'protected': baseline['protected'], 'baseline_sources': baseline['baseline_sources'],
        'staged_changes': False, 'runtime_changed': False, 'checkpoint_promoted': False}, indent=2) + '\n', encoding='utf-8')
    print(f'PASS: {args.attempt} preserved {len(records)} files with logs, candidate sources and all protected hashes unchanged')

if __name__ == '__main__':
    main()
