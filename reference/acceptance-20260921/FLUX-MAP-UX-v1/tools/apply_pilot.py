"""Create a separate, hash-gated JSON candidate. Never edits or overwrites a checkout file."""
from __future__ import annotations
import argparse,hashlib,json,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
def main()->int:
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--source',type=Path,required=True);p.add_argument('--output',type=Path,required=True);p.add_argument('--rollback',action='store_true');a=p.parse_args()
 try:
  contract=json.loads((ROOT/'pilot/patch_contract.json').read_text())
  expected=contract['candidate_sha256' if a.rollback else 'expected_base_sha256']
  raw=a.source.read_bytes()
  if hashlib.sha256(raw).hexdigest()!=expected:raise ValueError('Source hash mismatch. Stop: this proposal must be rebased/reviewed against the actual source.')
  if a.output.resolve()==a.source.resolve() or a.output.exists():raise ValueError('Output must be a NEW, separate file. In-place or overwrite operations are refused.')
  if not a.output.parent.is_dir():raise ValueError('Output parent directory must already exist.')
  # The tested patch has an exact, supplied candidate; rollback restores exact baseline bytes.
  rel='evidence/source/repository/content/maps/sanctum_campus_g2_v1.json' if a.rollback else 'pilot/campus_candidate.json'
  result=(ROOT/rel).read_bytes();wanted=contract['expected_base_sha256' if a.rollback else 'candidate_sha256']
  if hashlib.sha256(result).hexdigest()!=wanted:raise ValueError('Packaged output integrity mismatch.')
  with a.output.open('xb') as f:f.write(result)
  print(json.dumps({'status':'CANDIDATE_CREATED_NOT_INTEGRATED','path':str(a.output),'sha256':wanted,'source_modified':False,'runtime_tests':'NOT_RUN'},indent=2));return 0
 except (OSError,ValueError,KeyError,json.JSONDecodeError) as e:
  print(f'Refused: {e}',file=sys.stderr);return 2
if __name__=='__main__':raise SystemExit(main())
