# Frozen 500be delivery receipt review

This Python helper reads already executed evidence and actual payload bytes. It launches no engines, regenerates no identity and changes no source. `pins.json` fixes the exact p61-500be306a26a identity, 265 ordered suite IDs and 291 source/dependency hashes. The checker independently recounts raw Full and lifecycle records, hashes package/ZIP members, compares pack provenance and checks shared preferences/backups without exporting their contents.

Run only after the successful five-case lifecycle has closed. The first `portable-lifecycle-500be-a` attempt failed and must not be substituted for a passing repeat. Point `--lifecycle` at the later completed receipt supplied by root.

```powershell
& 'C:/Users/sende/AppData/Local/Python/pythoncore-3.14-64/python.exe' '.godot/iteration-20261013/delivery-review/review_delivery.py' `
  --repo 'C:/Users/sende/Projects/hex' `
  --full '.godot/iteration-20261013/full-500be-a.json' `
  --build 'exports/hex-iteration-20261013-500be' `
  --fallback 'exports/hex-iteration-20261012' `
  --terrain-directory '.godot/iteration-20261013/terrain-pack-500be-a' `
  --lifecycle '<completed-successful-lifecycle-directory>/receipt.json' `
  --lifecycle-helper '.godot/wave-a-integration/verify-final-portable-lifecycle.ps1' `
  --output '.godot/iteration-20261013/delivery-review/runs/final-a'
```

`--output` must be a fresh directory inside this helper's `runs/`; an existing directory is refused before a write. The helper creates and reads back `review.json`, exits 0 only when every declared section passes, and exits 1 with the exact failing condition plus completed sections otherwise. Missing fields fail closed. A failed run is preserved; any repaired reviewer uses another fresh output.

Current checks require the exact 18 delivery check names (not an empty/subset dictionary), unique exact ZIP membership, actual payload/receipt linkage and malformed/out-of-order cast rejection. Per-case historical preference hashes are receipt observations compared for equality and against final bytes; they are not historical file snapshots. Safe-close text is not, by itself, proof of resource teardown. The checked runner and separate native ownership gates supply that narrower evidence. No focus/FPS/physical-input, earned-progress recovery or soak claim is made.

Pure controls in `pure-review-checks.json` cover the corrected fail-closed admission and output refusal. The Full archive retains the exact original reviewer that produced its independently verified review; later reviewer fixes do not rewrite that provenance.
